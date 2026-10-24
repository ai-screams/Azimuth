// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 설치 뒤 DMG 정리(#197)의 판단.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import Foundation

extension CommandEngineTests {

    // 실제 `hdiutil info -plist`처럼 마운트 없는 엔티티(파티션 표)와 있는 엔티티가 섞인 출력.
    // 이것을 실패시키는 것: mount-point 없는 엔티티를 빈 문자열로 넣는 것, image-path 없는 항목을 넣는 것,
    // 형식이 다른 입력에서 죽거나 무언가를 돌려주는 것.
    static func testInstallerCleanupParse() {
        let plist: [String: Any] = ["images": [
            [
                "image-path": "/Users/me/Downloads/Azimuth-2.0.0.dmg",
                "owner-uid": 501,
                "system-entities": [["dev-entry": "/dev/disk9"], ["mount-point": "/Volumes/Azimuth"]]
            ],
            ["owner-uid": 0, "system-entities": [["mount-point": "/Volumes/NoPath"]]]
        ]]
        let data = (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) ?? Data()
        let images = InstallerCleanupPolicy.parseImages(data)
        expectName("one image with a path", "\(images.count)", "1")
        expectName("only real mount points", "\(images.first?.mountPoints ?? [])", "[\"/Volumes/Azimuth\"]")
        expectName("owner", "\(images.first?.ownerUID ?? -1)", "501")
        expectName("garbage", "\(InstallerCleanupPolicy.parseImages(Data("x".utf8)).count)", "0")
    }

    // 이것을 실패시키는 것: 이 빌드에서 이미 찾아봤는데 또 묻는 것, DMG 안·App Translocation·이름만 비슷한 폴더에서
    // 실행했는데 묻는 것, 다른 사용자가 연결했거나 연결한 사용자를 모르는 이미지를 고르는 것, .dmg가 아닌 이미지
    // (폴더인 sparsebundle)를 고르는 것, Azimuth.app이 없는 볼륨을 고르는 것, 앞의 다른 볼륨·마운트에서 멈추는 것.
    static func testInstallerCleanupCandidate() {
        let installed = "/Applications/Azimuth.app"
        let dmg = MountedDiskImage(
            imagePath: "/Users/me/Downloads/Azimuth.dmg", mountPoints: ["/Volumes/Azimuth"], ownerUID: 501
        )
        let other = MountedDiskImage(imagePath: "/x/Other.dmg", mountPoints: ["/Volumes/Other"], ownerUID: 501)
        func pick(
            app: String = installed, asked: String? = nil, images: [MountedDiskImage] = [dmg]
        ) -> String {
            let environment = InstallerCleanupEnvironment(
                home: "/Users/me", userID: 501, currentVersion: "210", checkedVersion: asked
            )
            let found = InstallerCleanupPolicy.candidate(
                appPath: app, environment: environment, images: images, containsApp: { $0 == "/Volumes/Azimuth" }
            )
            return found.map { "\($0.mountPoint) \($0.imagePath)" } ?? "nil"
        }
        expectName("installed app, Azimuth DMG", pick(), "/Volumes/Azimuth /Users/me/Downloads/Azimuth.dmg")
        expectName("home Applications", pick(app: "/Users/me/Applications/Azimuth.app"), pick())
        expectName("asked an older version", pick(asked: "209"), pick())
        expectName("already asked this version", pick(asked: "210"), "nil")
        expectName("run from the DMG", pick(app: "/Volumes/Azimuth/Azimuth.app"), "nil")
        expectName("translocated", pick(app: "/private/var/folders/x/AppTranslocation/y/d/Azimuth.app"), "nil")
        let rootOwned = MountedDiskImage(imagePath: dmg.imagePath, mountPoints: dmg.mountPoints, ownerUID: 0)
        expectName("someone else's image", pick(images: [rootOwned]), "nil")
        expectName("volume without the app", pick(images: [other]), "nil")
        expectName("skips other volumes", pick(images: [other, dmg]), pick())
        expectName("look-alike folder", pick(app: "/ApplicationsOld/Azimuth.app"), "nil")
        let unknownOwner = MountedDiskImage(imagePath: dmg.imagePath, mountPoints: dmg.mountPoints, ownerUID: nil)
        expectName("unknown owner", pick(images: [unknownOwner]), "nil")
        let bundle = MountedDiskImage(
            imagePath: "/Users/me/Backup.sparsebundle", mountPoints: ["/Volumes/Azimuth"], ownerUID: 501
        )
        expectName("not a .dmg", pick(images: [bundle]), "nil")
        let upper = MountedDiskImage(imagePath: "/Users/me/AZIMUTH.DMG", mountPoints: dmg.mountPoints, ownerUID: 501)
        expectName("upper-case extension", pick(images: [upper]), "/Volumes/Azimuth /Users/me/AZIMUTH.DMG")
        let twoMounts = MountedDiskImage(
            imagePath: dmg.imagePath, mountPoints: ["/Volumes/Other", "/Volumes/Azimuth"], ownerUID: 501
        )
        expectName("second mount of one image", pick(images: [twoMounts]), pick())
    }

    // 정리를 고른 뒤 다시 읽은 목록으로 판단한다.
    // 이것을 실패시키는 것: 알림 창 동안 같은 자리에 다른 이미지가 연결됐는데 꺼내는 것, 이미지가 이미 빠졌거나
    // 볼륨만 내려간 채인데 꺼내는 것, 꺼낸 뒤에도 연결된 이미지를 휴지통에 넣는 것.
    static func testInstallerCleanupRecheck() {
        let candidate = InstallerCleanupCandidate(imagePath: "/Users/me/A.dmg", mountPoint: "/Volumes/Azimuth")
        let same = MountedDiskImage(imagePath: "/Users/me/A.dmg", mountPoints: ["/Volumes/Azimuth"], ownerUID: 501)
        let swapped = MountedDiskImage(imagePath: "/Users/me/B.dmg", mountPoints: ["/Volumes/Azimuth"], ownerUID: 501)
        let unmounted = MountedDiskImage(imagePath: "/Users/me/A.dmg", mountPoints: [], ownerUID: 501)
        expectName("still there", "\(InstallerCleanupPolicy.isStillMounted(candidate, in: [same]))", "true")
        expectName("swapped", "\(InstallerCleanupPolicy.isStillMounted(candidate, in: [swapped]))", "false")
        expectName("already ejected", "\(InstallerCleanupPolicy.isStillMounted(candidate, in: []))", "false")
        let stillMounted = InstallerCleanupPolicy.isStillMounted(candidate, in: [unmounted])
        expectName("unmounted, still attached", "\(stillMounted)", "false")
        expectName("detached", "\(InstallerCleanupPolicy.isDetached(candidate, in: [swapped]))", "true")
        let detached = InstallerCleanupPolicy.isDetached(candidate, in: [unmounted])
        expectName("unmounted but attached", "\(detached)", "false")
    }
}
