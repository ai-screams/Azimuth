//
//  InstallerCleanupController.swift
//  Azimuth
//
//  설치 뒤 DMG 정리(#197). 앱이 Applications에서 실행될 때 아직 연결된 Azimuth 디스크 이미지가 있으면, 버전마다 한 번
//  알림 창으로 묻는다. 정리를 고르면 볼륨을 꺼내고 이미지 파일을 휴지통으로 옮긴다(영구 삭제는 하지 않는다).
//  고를 대상은 `InstallerCleanupPolicy`가 정한다. 첫 실행 안내보다 먼저 묻고, 끝나면 `then`을 부른다.
//
//  이미지 파일이 다운로드 폴더에 있으면 휴지통으로 옮길 때 macOS가 그 폴더 접근을 물을 수 있다. 거부하면 볼륨만
//  꺼낸 채 끝낸다(권한을 우회하지 않는다).
//

import AppKit
import os

@MainActor
final class InstallerCleanupController {
    private let preferences: PreferencesStore

    private static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

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
            askedVersion: preferences.installerCleanupAskedVersion
        )
        let appPath = Bundle.main.bundleURL.path
        // 이 버전에서 이미 물었거나 설치된 자리가 아니면 `hdiutil`을 부르지 않는다.
        guard InstallerCleanupPolicy.shouldLook(appPath: appPath, environment: environment) else { return nil }
        let images = await Self.mountedImages()
        return InstallerCleanupPolicy.candidate(
            appPath: appPath, environment: environment, images: images,
            containsApp: { FileManager.default.fileExists(atPath: $0 + "/Azimuth.app") }
        )
    }

    /// `hdiutil info -plist`의 이미지 목록. 실패하면 빈 목록(묻지 않는다).
    private nonisolated static func mountedImages() async -> [MountedDiskImage] {
        guard let data = await run("/usr/bin/hdiutil", ["info", "-plist"]) else { return [] }
        return InstallerCleanupPolicy.parseImages(data)
    }

    /// 명령을 메인 스레드 밖에서 실행하고 표준 출력을 돌려준다. 실행하지 못했거나 0이 아닌 코드로 끝나면 nil.
    private nonisolated static func run(_ tool: String, _ arguments: [String]) async -> Data? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? data : nil
        }.value
    }

    /// 정리를 골랐으면 true.
    private func ask(about candidate: InstallerCleanupCandidate) -> Bool {
        // 정리하든 그대로 두든 이 버전에서는 다시 묻지 않는다.
        preferences.installerCleanupAskedVersion = Self.currentVersion
        let alert = NSAlert()
        alert.messageText = "Clean up the Azimuth installer?"
        alert.informativeText = "Azimuth is installed. Eject the installer disk image and move "
            + "\"\((candidate.imagePath as NSString).lastPathComponent)\" to the Trash?"
        alert.addButton(withTitle: "Eject and Move to Trash")
        alert.addButton(withTitle: "Keep")
        NSApp.bringToFront()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// `diskutil eject`로 이미지까지 떼어 낸다. `NSWorkspace.unmountAndEjectDevice`는 볼륨만 내리고 디스크 이미지는
    /// 연결된 채 남겼다(실기 확인, `hdiutil info`에 마운트 없이 남음).
    private func clean(_ candidate: InstallerCleanupCandidate) async {
        guard await Self.run("/usr/sbin/diskutil", ["eject", candidate.mountPoint]) != nil else {
            // 볼륨이 쓰이는 중이면 꺼내지 못한다. 연결된 이미지를 휴지통에 넣지 않고 끝낸다.
            Log.app.error("Installer eject failed: \(candidate.mountPoint, privacy: .public)")
            return
        }
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: candidate.imagePath), resultingItemURL: nil)
        } catch {
            Log.app.error("Installer trash failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
