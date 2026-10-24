//
//  InstallerCleanupPolicy.swift
//  Azimuth
//
//  설치 뒤 DMG 정리(#197)의 판단. DMG는 코드를 실행할 수 없어, Applications로 옮긴 앱이 실행될 때 아직 연결된
//  Azimuth 디스크 이미지를 찾아 한 번 묻는다. 값만 받고 값만 돌려준다(`hdiutil` 실행·파일 확인·알림 창은
//  `InstallerCleanupController`).
//

import Foundation

/// `hdiutil info -plist`의 디스크 이미지 하나.
nonisolated struct MountedDiskImage: Equatable {
    let imagePath: String
    let mountPoints: [String]
    /// 이미지가 만든 장치(`/dev/disk8`, `/dev/disk8s1` 등). 볼륨을 내린 뒤에도 남아 있으면 이미지가 아직 연결돼 있다.
    var devEntries: [String] = []
    /// 이미지를 연결한 사용자. 다른 사용자(시스템 포함)가 연결한 이미지는 건드리지 않는다.
    let ownerUID: Int?
}

/// 물어볼 대상: 꺼낼 볼륨과 휴지통으로 옮길 이미지 파일.
nonisolated struct InstallerCleanupCandidate: Equatable {
    let imagePath: String
    let mountPoint: String
}

nonisolated enum InstallerCleanupPolicy {
    /// `hdiutil info -plist` 출력에서 이미지 목록을 읽는다. 형식이 다르면 빈 목록(묻지 않는다).
    static func parseImages(_ data: Data) -> [MountedDiskImage] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let images = plist["images"] as? [[String: Any]] else { return [] }
        return images.compactMap { image in
            guard let path = image["image-path"] as? String else { return nil }
            let entities = image["system-entities"] as? [[String: Any]] ?? []
            return MountedDiskImage(
                imagePath: path,
                mountPoints: entities.compactMap { $0["mount-point"] as? String },
                devEntries: entities.compactMap { $0["dev-entry"] as? String },
                ownerUID: image["owner-uid"] as? Int
            )
        }
    }

    /// 앱이 설치된 자리(`/Applications` 또는 홈의 `Applications`)에서 실행됐는가. DMG 안에서 실행했거나
    /// App Translocation으로 옮겨진 자리라면 false다.
    static func isInstalledLocation(appPath: String, home: String) -> Bool {
        ["/Applications/", home + "/Applications/"].contains { appPath.hasPrefix($0) }
    }

    /// 디스크 이미지를 찾아볼 만한가: 이 빌드에서 아직 찾아보지 않았고, 설치된 자리에서 실행됐다.
    static func shouldLook(appPath: String, environment: InstallerCleanupEnvironment) -> Bool {
        environment.checkedVersion != environment.currentVersion
            && isInstalledLocation(appPath: appPath, home: environment.home)
    }

    /// 물어볼 이미지를 고른다. `shouldLook`이 false면 nil.
    /// 이미지는 지금 사용자가 연결한 `.dmg` 파일이고(폴더인 sparsebundle 등은 고르지 않는다), 볼륨 맨 위에 이 앱과
    /// 같은 번들 id의 `Azimuth.app`이 있어야 한다(`containsApp`이 확인). DMG 안에서 실행 중인 앱은
    /// 설치된 자리가 아니라서 여기까지 오지 않는다(실행 중인 앱의 원본을 지우지 않는다).
    static func candidate(
        appPath: String,
        environment: InstallerCleanupEnvironment,
        images: [MountedDiskImage],
        containsApp: (String) -> Bool
    ) -> InstallerCleanupCandidate? {
        guard shouldLook(appPath: appPath, environment: environment) else { return nil }
        let offerable = images.filter {
            $0.ownerUID == environment.userID && $0.imagePath.lowercased().hasSuffix(".dmg")
        }
        for image in offerable {
            for mount in image.mountPoints where containsApp(mount) {
                return InstallerCleanupCandidate(imagePath: image.imagePath, mountPoint: mount)
            }
        }
        return nil
    }

    /// 사용자가 정리를 고른 뒤에도 같은 이미지가 같은 자리에 연결돼 있는가. 알림 창이 떠 있는 동안 사용자가 DMG를
    /// 꺼내고 같은 이름의 다른 이미지를 연결했으면 false다.
    static func isStillMounted(_ candidate: InstallerCleanupCandidate, in images: [MountedDiskImage]) -> Bool {
        images.contains { $0.imagePath == candidate.imagePath && $0.mountPoints.contains(candidate.mountPoint) }
    }

    /// 꺼낸 뒤 이미지가 떨어졌는가. 아직 연결돼 있으면 휴지통으로 옮기지 않는다.
    static func isDetached(_ candidate: InstallerCleanupCandidate, in images: [MountedDiskImage]) -> Bool {
        !images.contains { $0.imagePath == candidate.imagePath }
    }

    /// 볼륨을 내렸는데 이미지가 남았을 때 다시 꺼낼 디스크 전체 장치(`/dev/diskN`, 파티션 `sN`이 붙지 않은 것)(#207).
    /// 실기에서 첫 `diskutil eject <마운트 위치>`가 볼륨만 내리고 이미지를 남긴 적이 있다. 없으면 nil.
    static func wholeDisk(of candidate: InstallerCleanupCandidate, in images: [MountedDiskImage]) -> String? {
        let image = images.first { $0.imagePath == candidate.imagePath }
        let prefix = "/dev/disk"
        return image?.devEntries.first { entry in
            let number = entry.dropFirst(prefix.count)
            return entry.hasPrefix(prefix) && !number.isEmpty && number.allSatisfy(\.isNumber)
        }
    }
}

/// 판단에 드는 실행 환경 값.
nonisolated struct InstallerCleanupEnvironment: Equatable {
    let home: String
    let userID: Int
    let currentVersion: String
    /// 마지막으로 이미지를 찾아본 빌드(찾았든 못 찾았든, 정리했든 그대로 뒀든). 없으면 nil.
    let checkedVersion: String?
}
