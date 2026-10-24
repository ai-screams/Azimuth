//
//  UpdateFeed.swift
//  Azimuth
//
//  레거시판이 읽을 자동 업데이트 목록(appcast)을 OS 버전으로 고른다. 10.13~12는 레거시 목록,
//  macOS 13 이상이면 본판 목록 — OS를 올린 사용자는 다음 확인 때 본판으로 옮겨 간다. 본판 목록에는 최소 OS마다
//  최신 1건이 있어(본판 2.0부터 14 이상), 13은 마지막 13 호환판 1.7.7을, 14 이상은 최신 2.x를 받는다(LEGACY.md).
//  판단만 하는 순수 함수라 테스트 하네스에서 검증한다(Sparkle 연결은 AppDelegate).
//

import Foundation

nonisolated enum UpdateFeed {
    /// 본판 목록. 항상 최신 본판 릴리스의 appcast로 이어지는 고정 주소.
    static let mainURL = "https://github.com/ai-screams/Azimuth/releases/latest/download/appcast.xml"
    /// 레거시 목록. `legacy-feed` 고정 릴리스의 자산을 레거시 릴리스마다 덮어쓴다(그 릴리스는 latest가 아니다).
    static let legacyURL = "https://github.com/ai-screams/Azimuth/releases/download/legacy-feed/appcast.xml"
    /// 레거시 목록의 끝: 이 주 버전부터 본판 목록을 읽는다. 본판의 지원 하한이 아니다(본판은 2.0부터 14.0). 13은 본판
    /// 목록에 남은 1.7.7을 받으므로 13으로 둔다. 본판 하한을 따라 올리면 13 사용자가 레거시 목록에 묶인다.
    static let mainMinimumMajorVersion = 13

    /// 주 버전만 본다: 본판 최소 버전이 13.0이라 13.x 전체가 본판 대상이다. 10.13~10.15는 주 버전이 10.
    static func url(forMajorVersion major: Int) -> String {
        major >= mainMinimumMajorVersion ? mainURL : legacyURL
    }
}
