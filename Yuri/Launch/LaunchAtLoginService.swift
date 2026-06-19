//
//  LaunchAtLoginService.swift
//  Yuri
//
//  정공법 로그인 자동 실행: ServiceManagement의 SMAppService.mainApp을 사용한다.
//  권한 우회 없이, 등록 실패/승인 필요 시 사용자를 System Settings로 안내한다.
//

import os
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    private let service = SMAppService.mainApp

    /// 현재 로그인 아이템으로 활성 등록되어 실행 자격이 있는지.
    var isEnabled: Bool {
        service.status == .enabled
    }

    /// 등록은 됐지만 System Settings에서 사용자 승인이 필요한 상태.
    var requiresApproval: Bool {
        service.status == .requiresApproval
    }

    /// 로그인 자동 실행 등록. 실패 시 `SMAppService.register()`가 던지는 오류를 그대로 전파한다
    /// (호출부에서 안내·로깅). 우회 없이, 승인 필요 상태는 `requiresApproval`로 노출된다.
    func enable() throws {
        try service.register()
    }

    /// 로그인 자동 실행 해제. unregister는 비동기이므로 완료 후 메인액터에서 콜백한다.
    func disable(completion: @escaping () -> Void = {}) {
        service.unregister { error in
            if let error {
                Log.app.error("Failed to unregister login item: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in completion() }
        }
    }

    /// System Settings의 로그인 항목 패널을 연다(승인 안내용).
    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
