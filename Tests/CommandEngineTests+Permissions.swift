// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 손쉬운 사용 권한 요청 경로(알림 vs 설정 열기).
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// 본판과 legacy/10.13 브랜치가 같은 파일을 쓴다.

import Foundation

extension CommandEngineTests {
    /// 테스트 전용 UserDefaults 하나를 비운 뒤 넘긴다. 이름은 고정이다 — 설정 파일을 지워도 cfprefsd가 빈 파일을
    /// 늦게 다시 쓰므로, 실행마다 새 이름을 쓰면 파일이 쌓인다. 하네스는 한 프로세스에서 차례로 돌므로 한 이름을
    /// 비워 가며 쓰면 충분하다(남는 것은 많아야 빈 파일 하나). 만들 수 없으면 실패로 센다 — 실제 저장소(.standard)로
    /// 물러나면 사용자 설정을 건드린다.
    static func withTestDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "azimuth.tests.harness"
        guard let defaults = UserDefaults(suiteName: suite) else {
            checks += 1
            failures += 1
            print("FAIL could not create UserDefaults suite \(suite)")
            return
        }
        defaults.removePersistentDomain(forName: suite)
        body(defaults)
        defaults.removePersistentDomain(forName: suite)
    }

    static func testAccessibilityRequestPolicy() {
        func expectAction(_ label: String, _ trusted: Bool, _ attempted: Bool, _ want: AccessibilityRequestAction) {
            checks += 1
            let got = AccessibilityRequestPolicy.decide(isTrusted: trusted, didAttemptPrompt: attempted)
            if got != want {
                failures += 1
                print("FAIL \(label): got \(got) want \(want)")
            }
        }
        // 첫 요청만 알림 — 알림과 설정을 동시에 열지 않는다.
        expectAction("untrusted, never attempted -> prompt only", false, false, .systemPrompt)
        expectAction("untrusted, attempted -> open settings", false, true, .openSettings)
        expectAction("trusted -> open settings", true, false, .openSettings)
        expectAction("trusted, attempted -> open settings", true, true, .openSettings)

        func initial(_ recorded: Bool?, _ firstRunDone: Bool) -> String {
            "\(AccessibilityRequestPolicy.initialAttemptFlag(recorded: recorded, didCompleteFirstRun: firstRunDone))"
        }
        expectName("new install", initial(nil, false), "false")
        expectName("upgrade from a version that prompted on every click", initial(nil, true), "true")
        expectName("recorded false wins", initial(false, true), "false")
        expectName("recorded true wins", initial(true, false), "true")
    }

    /// 기록은 `PreferencesStore.init`에서 **첫 실행 안내가 `didCompleteFirstRun`을 켜기 전에** 한 번 정해진다.
    /// 나중에 읽을 때 추론하면 새 설치본이 "이미 시도함"으로 잘못 정해져 알림을 건너뛴다(검토 HIGH).
    @MainActor
    static func testAccessibilityPromptMigration() {
        withTestDefaults { defaults in
            let store = PreferencesStore(defaults: defaults)
            store.didCompleteFirstRun = true // 첫 실행 안내가 곧바로 켠다
            expectName("new install still prompts after first run completes",
                       "\(PreferencesStore(defaults: defaults).didAttemptAccessibilityPrompt)", "false")
        }
        withTestDefaults { defaults in
            defaults.set(true, forKey: "didCompleteFirstRun")
            expectName("upgrade is treated as already prompted",
                       "\(PreferencesStore(defaults: defaults).didAttemptAccessibilityPrompt)", "true")
        }
        withTestDefaults { defaults in
            let attempted = PreferencesStore(defaults: defaults)
            attempted.didAttemptAccessibilityPrompt = true
            expectName("attempt is remembered",
                       "\(PreferencesStore(defaults: defaults).didAttemptAccessibilityPrompt)", "true")
        }
    }

    /// `PreferencesStore`가 하네스에 들어오며 커버리지 분모가 늘었다 — 기본값·저장·되읽기를 고정한다.
    @MainActor
    static func testPreferencesStore() {
        withTestDefaults { defaults in checkPreferencesStore(defaults) }
    }

    @MainActor
    private static func checkPreferencesStore(_ defaults: UserDefaults) {
        let store = PreferencesStore(defaults: defaults)
        expectName("default preset", "\(store.activePreset)", "standard")
        expectName("sound on by default", "\(store.soundFeedbackEnabled)", "true")
        expectName("notify off by default", "\(store.notifyOnCommandFailure)", "false")
        expectName("menu bar icon shown by default", "\(store.menuBarIconHidden)", "false")
        store.activePreset = .vim
        store.soundFeedbackEnabled = false
        store.notifyOnCommandFailure = true
        store.menuBarIconHidden = true
        let reread = PreferencesStore(defaults: defaults)
        expectName("preset persists", "\(reread.activePreset)", "vim")
        expectName("sound persists", "\(reread.soundFeedbackEnabled)", "false")
        expectName("notify persists", "\(reread.notifyOnCommandFailure)", "true")
        expectName("icon persists", "\(reread.menuBarIconHidden)", "true")
        defaults.set("bogus", forKey: "activeHotkeyPreset")
        expectName("unknown preset falls back", "\(reread.activePreset)", "standard")

        let shortcut = HotkeyShortcut(keyCode: 0x7B, modifiers: 0x1800)
        store.setShortcut(shortcut, forCommand: "a")
        store.setShortcut(shortcut, forCommand: "b")
        expectName("two custom shortcuts", "\(store.customShortcuts.count)", "2")
        store.clearShortcut(forCommand: "a")
        expectName("clear one", "\(store.customShortcuts.keys.sorted())", "[\"b\"]")
        store.clearAllShortcuts()
        expectName("clear all", "\(store.customShortcuts.isEmpty)", "true")
        defaults.set(Data("not json".utf8), forKey: "customShortcuts")
        expectName("corrupt shortcuts read as empty", "\(store.customShortcuts.isEmpty)", "true")

        store.setCommandDisabled("cmd", disabled: true)
        expectName("command disabled", "\(store.isCommandEnabled("cmd", groupToken: "g"))", "false")
        store.setCommandDisabled("cmd", disabled: false)
        store.setGroupDisabled("g", disabled: true)
        expectName("group disabled", "\(store.isGroupEnabled("g"))", "false")
        expectName("command in disabled group", "\(store.isCommandEnabled("cmd", groupToken: "g"))", "false")
        store.setGroupDisabled("g", disabled: false)
        expectName("re-enabled", "\(store.isCommandEnabled("cmd", groupToken: "g"))", "true")

        store.resolveTimeout = 999
        expectName("resolve timeout is clamped", "\(store.resolveTimeout == AXMessagingTimeout.clampedResolve(999))", "true")
    }
}
