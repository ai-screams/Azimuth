//
//  UpdateVersionDisplayer.swift
//  Azimuth
//
//  Sparkle 표준 업데이트 창의 버전 표기를 "v1.7.2"로 바꾸는 어댑터. 규칙은 `UpdateVersionText`(순수)가 정하고
//  여기서는 Sparkle 공식 확장 지점(`SPUStandardUserDriverDelegate` → `SUVersionDisplay`)에 연결만 한다.
//
//  `nonisolated`인 이유: 기본 격리가 MainActor인 프로젝트에서, 격리 표기가 없는 Sparkle ObjC 프로토콜을
//  `@MainActor` 타입(AppDelegate)이 직접 채택하면 격리 계약이 맞지 않는다. 상태가 없는 작은 객체로 분리했다.
//  Sparkle은 delegate를 약하게 잡으므로 AppDelegate가 이 객체를 보유한다.
//
//  범위: 업데이트 발견·"최신 버전" 창. 재실행 없이 설치를 마친 뒤의 "Update Installed" 알림은 Sparkle이 이
//  포맷터를 거치지 않고 표시하지만, Azimuth는 설치 뒤 재실행하므로 그 알림을 쓰지 않는다.
//
//  본판과 `legacy/10.13` 브랜치가 같은 파일을 쓴다.
//

import Foundation
import Sparkle

final nonisolated class UpdateVersionDisplayer: NSObject, SPUStandardUserDriverDelegate, SUVersionDisplay {
    func standardUserDriverRequestsVersionDisplayer() -> (any SUVersionDisplay)? {
        self
    }

    /// 업데이트 발견 창: 새 버전과 현재 버전을 함께 바꾼다.
    func formatUpdateVersion(
        fromUpdate update: SUAppcastItem,
        andBundleDisplayVersion inOutBundleDisplayVersion: AutoreleasingUnsafeMutablePointer<NSString>,
        withBundleVersion bundleVersion: String
    ) -> String {
        let texts = UpdateVersionText.pair(
            updateShort: update.displayVersionString, updateBuild: update.versionString,
            bundleShort: inOutBundleDisplayVersion.pointee as String, bundleBuild: bundleVersion
        )
        inOutBundleDisplayVersion.pointee = texts.bundle as NSString
        return texts.update
    }

    /// "최신 버전입니다" 창: 설치된 버전만 바꾼다.
    func formatBundleDisplayVersion(
        _ bundleDisplayVersion: String, withBundleVersion bundleVersion: String, matchingUpdate _: SUAppcastItem?
    ) -> String {
        UpdateVersionText.label(short: bundleDisplayVersion, build: bundleVersion)
    }
}
