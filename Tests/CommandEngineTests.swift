// Azimuth 명령 엔진(순수 로직) 회귀 테스트.
// Xcode 테스트 타깃 대신 swiftc로 컴파일/실행한다(scripts/test.sh, `make test`, CI).
// 대상: FrameCalculator(기하 계산) + WindowCommand(명령 모델). AppKit/AX 비의존 순수 로직만.

import CoreGraphics
import Foundation

@main
enum CommandEngineTests {
    static let workArea = CGRect(x: 0, y: 25, width: 1920, height: 1055)
    static var checks = 0
    static var failures = 0

    static func main() {
        testAbsolutePlacements()
        testAxisIndependentComposition()
        testMoves()
        testRelativeHalves()
        testRelativeTwoThirds()
        testRelativeShrinkFloor()
        testSnapHalves()
        testDisplayMove()
        testSnapDecision()
        testSnapThrowPlan()
        testMoveToDisplayPlan()
        testPlanDelegation()
        testAdjacentEdge()
        testCenterClamp()
        testAnchorOrigin()
        testAnchoredOrigin()
        testFallbackCommands()
        testGapMaximize()
        testGapMaximizeDegenerate()
        testBestMatch()
        testDisplayGeometry()
        testIsConstrained()
        testUsableFrame()
        testFrameApply()
        testOutcomePolicy()
        testCommandGroups()
        testPrimitiveStrings()
        testCommandModel()
        testCommandHelpText()
        testCommandIdentifiers()
        testMessagingTimeoutPolicy()
        testResolveBudget()
        testWriteRetryPolicy()
        testEdgeReanchor()
        testFixedSizePlacement()
        testUndoHistory()
        testBoundedIntSetting()
        testRecentKeys()
        testUndoPreferences()
        testUpdateVersionText()
        testAccessibilityRequestPolicy()
        testAccessibilityPromptMigration()
        testPreferencesStore()
        testWriteRetryBudget()
        testResolveTimeoutClamp()
        testResolveTimeoutChoices()
        testShortcutListPolicy()
        testShortcutRowPolicy()
        testCommandFeedbackPolicy()
        testUserFacingMessages()
        testResultCommandError()
        testWindowFrame()
        testPresetCoverage()
        testPresetKeyAssignments()
        testBindingOverrides()
        testEnabledFiltering()
        testConflictDetection()
        testShortcutDisplay()
        testShortcutCodableRoundTrip()
        testCarbonModifier()
        testCommandGlyphCatalog()
        testCommandGlyphRegions()
        testCommandGlyphArrows()
        testCommandGlyphDisplays()
        testMenuCommandsByGroup()
        testBindingShortcut()
        testKeycapLabels()
        testNotifyToggleDecision()
        testShortcutCapturePolicy()
        testShortcutRecordingPolicy()
        testPracticeSession()
        testPermissionWatchPolicy()
        testStatusClickPolicy()
        testPopoverActivationPolicy()
        testPopoverGridLayout()
        testCheatSheetLayer()
        testCheatSheetTrigger()
        testCheatSheetPreferences()
        testCommandPaletteSearch()
        testCommandPaletteSelectionAndRecents()
        testCommandPalettePreview()
        testCommandPaletteShortcut()
        testCommandPalettePreferences()

        if failures == 0 {
            print("PASS — all \(checks) checks")
        } else {
            print("FAIL — \(failures)/\(checks) checks failed")
            exit(1)
        }
    }

    // MARK: - helpers

    static func approx(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }

    static func expect(_ label: String, _ got: CGRect, _ want: CGRect) {
        checks += 1
        let same = approx(got.minX, want.minX) && approx(got.minY, want.minY)
            && approx(got.width, want.width) && approx(got.height, want.height)
        if !same {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }

    static func expectPoint(_ label: String, _ got: CGPoint, _ want: CGPoint) {
        checks += 1
        if !(approx(got.x, want.x) && approx(got.y, want.y)) {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }

    static func expectDecision(_ label: String, _ got: OutcomeDecision, _ want: OutcomeDecision) {
        checks += 1
        if got != want {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }

    /// CommandPlan 통째 비교(정확 동등성). target과 snappedEdge를 나눠 검사하면 한쪽을 빼먹어도 통과하므로
    /// 계획 테스트는 이것으로만 단정한다.
    static func expectPlan(_ label: String, _ got: CommandPlan, _ want: CommandPlan) {
        checks += 1
        if got != want {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }

    static func expectName(_ label: String, _ got: String, _ want: String) {
        checks += 1
        if got != want {
            failures += 1
            print("FAIL \(label): got \"\(got)\" want \"\(want)\"")
        }
    }

    static func target(_ command: WindowCommand, _ current: CGRect) -> CGRect {
        FrameCalculator.targetFrame(for: command, current: current, workArea: workArea)
    }

    static func absolute(_ axis: Axis, _ fraction: Fraction, _ slot: Slot) -> WindowCommand {
        .absolute(AbsolutePlacement(axis: axis, fraction: fraction, slot: slot))
    }

    // 개별 테스트는 도메인별 확장 파일에 있다:
    //   +Frames    기하 배치·이동·상대 축소
    //   +Displays  스냅·던지기·디스플레이 선택
    //   +Plan      목표 frame 계획(snapThrow 상태기계·moveToDisplay 목적지)
    //   +Apply     앵커·적용 판정·결과 커밋 정책
    //   +Model     명령 모델·그룹·식별자
    //   +Hotkeys   단축키 바인딩·표시·충돌
    //   +Undo      실행 취소 기록·설정
    //   +Updates   업데이트 창 버전 문구
    //   +Permissions 접근성 요청·설정 저장
    //   +Glyphs    명령 그림·키캡 라벨·그룹별 명령
    //   +Settings  설정 화면의 판단(알림 토글, 단축키 녹화의 키 처리와 녹화 상태)
    //   +Onboarding 첫 실행 연습 창(단계, Undo 기록, 도달 판정), 권한이 생기는 순간 감지

}
