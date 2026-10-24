//
//  InstallerCleanupController.swift
//  Azimuth
//
//  설치 뒤 DMG 정리(#197). 앱이 Applications에서 실행될 때 아직 연결된 Azimuth 디스크 이미지가 있으면, 빌드마다 한 번
//  알림 창으로 묻는다. 정리를 고르면 이미지를 떼어 내고 이미지 파일을 휴지통으로 옮긴다(영구 삭제는 하지 않는다).
//  고를 대상은 `InstallerCleanupPolicy`가 정한다. 첫 실행 안내보다 먼저 묻고, 끝나면 `then`을 부른다.
//
//  이미지 파일이 다운로드 폴더에 있으면 휴지통으로 옮길 때 macOS가 그 폴더 접근을 묻는다(실기 확인). 거부하면 이미지만
//  떼어 낸 채 끝낸다(권한을 우회하지 않는다). 그 창이 떠 있는 동안 메인 스레드가 멈추지 않게, 파일 작업과 외부 명령은
//  모두 메인 스레드 밖에서 한다.
//

import AppKit
import os

@MainActor
final class InstallerCleanupController {
    private let preferences: PreferencesStore

    private static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    /// 외부 명령의 상한. `hdiutil`이 멈춰도 첫 실행 안내(`then`)는 뜬다.
    private static let commandTimeout: TimeInterval = 10
    /// 이미지가 떨어지기를 기다리는 횟수(1초 간격, #207).
    private static let detachAttempts = 5

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func runIfNeeded(then: @escaping @MainActor () -> Void) {
        Task {
            if let candidate = await findCandidate(), ask(about: candidate) {
                await clean(candidate)
            }
            then()
        }
    }

    private func findCandidate() async -> InstallerCleanupCandidate? {
        let environment = InstallerCleanupEnvironment(
            home: FileManager.default.homeDirectoryForCurrentUser.path,
            userID: Int(getuid()),
            currentVersion: Self.currentVersion,
            checkedVersion: preferences.installerCleanupCheckedVersion
        )
        let appPath = Bundle.main.bundleURL.path
        // 이 빌드에서 이미 찾아봤거나 설치된 자리가 아니면 `hdiutil`을 부르지 않는다. 찾든 못 찾든, 묻든 말든
        // 이 빌드에서는 다시 찾지 않는다(매 실행·로그인마다 `hdiutil`을 부르지 않게).
        guard InstallerCleanupPolicy.shouldLook(appPath: appPath, environment: environment) else { return nil }
        preferences.installerCleanupCheckedVersion = Self.currentVersion
        let bundleID = Bundle.main.bundleIdentifier
        return await Task.detached {
            InstallerCleanupPolicy.candidate(
                appPath: appPath, environment: environment, images: await Self.mountedImages(),
                containsApp: { Bundle(path: $0 + "/Azimuth.app")?.bundleIdentifier == bundleID }
            )
        }.value
    }

    /// 정리를 골랐으면 true.
    private func ask(about candidate: InstallerCleanupCandidate) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Clean up the Azimuth installer?"
        alert.informativeText = "Azimuth is installed. Eject the installer disk image and move "
            + "\"\((candidate.imagePath as NSString).abbreviatingWithTildeInPath)\" to the Trash?"
        alert.addButton(withTitle: "Eject and Move to Trash")
        alert.addButton(withTitle: "Keep")
        NSApp.bringToFront()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// `diskutil eject`로 이미지까지 떼어 낸다. `NSWorkspace.unmountAndEjectDevice`는 볼륨만 내리고 디스크 이미지는
    /// 연결된 채 남겼다(실기 확인, `hdiutil info`에 마운트 없이 남음). 떼어 낸 것을 확인한 뒤에만 휴지통으로 옮긴다.
    private func clean(_ candidate: InstallerCleanupCandidate) async {
        // 알림 창이 떠 있는 동안 사용자가 DMG를 바꿨을 수 있다. 같은 이미지가 그대로일 때만 꺼낸다.
        guard InstallerCleanupPolicy.isStillMounted(candidate, in: await Self.mountedImages()) else { return }
        var lastError = await Self.eject(candidate.mountPoint)
        guard await waitUntilDetached(candidate, lastError: &lastError) else {
            // 볼륨이 쓰이는 중이거나 이미지가 끝내 떨어지지 않았다. 연결된 이미지를 휴지통에 넣지 않고 끝낸다.
            let mount = candidate.mountPoint
            Log.app.error("Installer eject failed: \(mount, privacy: .public) \(lastError, privacy: .public)")
            return
        }
        let imageURL = URL(fileURLWithPath: candidate.imagePath)
        let failure = await Task.detached { () -> String? in
            do {
                try FileManager.default.trashItem(at: imageURL, resultingItemURL: nil)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        if let failure {
            Log.app.error("Installer trash failed: \(failure, privacy: .public)")
        }
    }

    /// 이미지가 떨어질 때까지 1초 간격으로 최대 `detachAttempts`번 본다(#207). 볼륨은 내려갔는데 이미지가 남아 있으면
    /// 디스크 전체 장치를 다시 꺼낸다. 2.0.0을 처음 실행한 실기에서 첫 꺼내기가 볼륨만 내리고 이미지를 남겼고, 나중에
    /// 셸의 `diskutil eject disk8`로는 떨어졌다(그 순간 다른 프로세스가 디스크를 잡고 있었던 것으로 본다, 확인 못 함).
    private func waitUntilDetached(_ candidate: InstallerCleanupCandidate, lastError: inout String) async -> Bool {
        for attempt in 0 ..< Self.detachAttempts {
            let images = await Self.mountedImages()
            if InstallerCleanupPolicy.isDetached(candidate, in: images) { return true }
            // 첫 꺼내기가 성공했다면 이미지가 떨어지는 중일 수 있어 한 번은 기다린다. 그 뒤에도 남으면 디스크 전체를 꺼낸다.
            let retry = attempt > 0 || !lastError.isEmpty
            if retry, let disk = InstallerCleanupPolicy.wholeDisk(of: candidate, in: images) {
                lastError = await Self.eject(disk)
            }
            try? await Task.sleep(for: .seconds(1))
        }
        return InstallerCleanupPolicy.isDetached(candidate, in: await Self.mountedImages())
    }

    /// `diskutil eject`. 성공하면 빈 문자열, 실패하면 `diskutil`의 오류 문구(로그용).
    private nonisolated static func eject(_ target: String) async -> String {
        let result = await execute("/usr/sbin/diskutil", ["eject", target])
        return result.succeeded ? "" : (result.errorText.isEmpty ? "exit status nonzero" : result.errorText)
    }

    /// `hdiutil info -plist`의 이미지 목록. 실패하면 빈 목록(묻지 않는다).
    private nonisolated static func mountedImages() async -> [MountedDiskImage] {
        guard let data = await run("/usr/bin/hdiutil", ["info", "-plist"]) else { return [] }
        return InstallerCleanupPolicy.parseImages(data)
    }

    /// 명령을 메인 스레드 밖에서 실행하고 표준 출력을 돌려준다. 실행하지 못했거나, 0이 아닌 코드로 끝났거나,
    /// `commandTimeout` 안에 끝나지 않아 멈췄으면 nil.
    private nonisolated static func run(_ tool: String, _ arguments: [String]) async -> Data? {
        let result = await execute(tool, arguments)
        return result.succeeded ? result.output : nil
    }

    private struct CommandResult: Sendable {
        let succeeded: Bool
        let output: Data
        let errorText: String
    }

    /// 명령을 메인 스레드 밖에서 실행한다. `commandTimeout` 안에 끝나지 않으면 멈추고 실패로 본다.
    private nonisolated static func execute(_ tool: String, _ arguments: [String]) async -> CommandResult {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            let output = Pipe(), errors = Pipe()
            process.standardOutput = output
            process.standardError = errors
            do {
                try process.run()
            } catch {
                return CommandResult(succeeded: false, output: Data(), errorText: error.localizedDescription)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + commandTimeout) {
                if process.isRunning { process.terminate() }
            }
            // 둘 다 짧은 출력이다(hdiutil info 수 KB, diskutil 오류 한두 줄).
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let errorText = (String(bytes: errorData, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let finished = process.terminationReason == .exit && process.terminationStatus == 0
            return CommandResult(succeeded: finished, output: data, errorText: errorText)
        }.value
    }
}
