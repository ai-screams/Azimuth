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
    /// 표준 App·Edit·Window 메뉴를 가진 메인 메뉴를 만든다.
    /// - Parameters:
    ///   - appName: "About/Hide/Quit <앱>" 레이블에 쓰인다.
    ///   - settingsTarget/settingsAction: "Settings…"(⌘,) 항목에 연결한다.
    static func make(appName: String, settingsTarget: AnyObject, settingsAction: Selector) -> NSMenu {
        let mainMenu = NSMenu()
        attach(appMenu(appName: appName, settingsTarget: settingsTarget, settingsAction: settingsAction), to: mainMenu)
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

    private static func appMenu(appName: String, settingsTarget: AnyObject, settingsAction: Selector) -> NSMenu {
        let menu = NSMenu(title: appName)
        menu.addItem(withTitle: "About \(appName)",
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: settingsAction, keyEquivalent: ",")
        settings.target = settingsTarget
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
