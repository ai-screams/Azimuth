//
//  MainMenuBuilder.swift
//  Azimuth
//
//  앱 메인 메뉴(App·Edit·Window)를 코드로 구성한다. 스토리보드/MainMenu.xib가 없어
//  표준 메뉴가 빠지면 ⌘Q·⌘W·텍스트 편집(⌘C/⌘V/⌘X/⌘A) 같은 키 equivalent가 어디서도
//  처리되지 않아 경고음(NSBeep)만 난다. 릴리스(.accessory) 빌드는 메뉴 막대가 보이지
//  않아도 키 equivalent는 동작하므로 ⌘Q 등이 정상 작동한다.
//
//  표준 항목(Quit/Hide/Cut/Copy/Paste/Undo/Minimize/Close)은 target=nil로 두어 응답자
//  체인(NSApp·키 윈도우·퍼스트 리스폰더)이 처리한다. "Settings…"(⌘,)만 명시 타깃을 건다.
//

import AppKit

enum MainMenuBuilder {
    /// App 메뉴의 커스텀 항목(About·Settings) 액션 묶음. 둘 다 같은 타깃(보통 AppDelegate)을 쓴다.
    /// "Check for Updates…"만 별도 타깃(Sparkle 업데이터 컨트롤러)을 받는다 — MainMenuBuilder는
    /// AppKit만 알면 되도록 타깃/셀렉터를 제네릭으로 전달받는다.
    struct AppMenuActions {
        let target: AnyObject
        let about: Selector
        let settings: Selector
        let checkForUpdatesTarget: AnyObject
        let checkForUpdates: Selector
    }

    /// 표준 App·Edit·Window 메뉴를 가진 메인 메뉴를 만든다.
    /// - Parameters:
    ///   - appName: "About/Hide/Quit <앱>" 레이블에 쓰인다.
    ///   - actions: "About <앱>"(링크 포함 커스텀 패널)·"Settings…"(⌘,) 항목에 연결할 타깃/셀렉터.
    static func make(appName: String, actions: AppMenuActions) -> NSMenu {
        let mainMenu = NSMenu()
        attach(appMenu(appName: appName, actions: actions), to: mainMenu)
        attach(editMenu(), to: mainMenu)
        let window = windowMenu()
        attach(window, to: mainMenu)
        NSApp.windowsMenu = window // 시스템이 창 목록을 자동 관리하도록 지정.
        return mainMenu
    }

    /// 빈 상위 항목을 만들어 서브메뉴를 단다(메인 메뉴의 각 칸은 서브메뉴를 가진 항목이다).
    private static func attach(_ submenu: NSMenu, to mainMenu: NSMenu) {
        let item = NSMenuItem()
        item.submenu = submenu
        mainMenu.addItem(item)
    }

    private static func appMenu(appName: String, actions: AppMenuActions) -> NSMenu {
        let menu = NSMenu(title: appName)
        let about = menu.addItem(withTitle: "About \(appName)", action: actions.about, keyEquivalent: "")
        about.target = actions.target
        menu.addItem(.separator())
        // "Check for Updates…"는 Sparkle 업데이터 컨트롤러가 타깃이며, canCheckForUpdates에
        // 따라 자동 활성/비활성된다(target/action 연결만으로 동작).
        let checkUpdates = menu.addItem(
            withTitle: "Check for Updates…",
            action: actions.checkForUpdates,
            keyEquivalent: ""
        )
        checkUpdates.target = actions.checkForUpdatesTarget
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: actions.settings, keyEquivalent: ",")
        settings.target = actions.target
        // 시스템 항목(About/Hide/Quit)은 macOS가 SF Symbol 아이콘을 자동으로 붙이지만
        // 커스텀 "Settings…"는 없어 통일성이 깨진다 → gearshape 심볼을 직접 단다.
        settings.image = NSImage.symbol("gearshape", accessibilityDescription: nil)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "Hide Others",
                                      action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All",
                     action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }
}
