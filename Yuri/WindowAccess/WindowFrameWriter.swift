import ApplicationServices

nonisolated enum WindowFrameWriter {
    static func apply(_ frame: CGRect, to element: AXUIElement) -> Result<CGRect, WindowCommandError> {
        // 권한 가드를 쓰기 경계에도 둔다(방어적 — 호출 순서에 의존하지 않게).
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return .failure(.resolution(.permissionDenied))
        }
        guard isSettable(element, kAXPositionAttribute), isSettable(element, kAXSizeAttribute) else {
            return .failure(.notMovable)
        }

        let positionError = setPoint(element, kAXPositionAttribute, frame.origin)
        let sizeError = setSize(element, kAXSizeAttribute, frame.size)
        // 최소 크기 제약으로 위치가 밀리는 창을 위해 위치를 한 번 더 적용한다.
        setPoint(element, kAXPositionAttribute, frame.origin)

        guard positionError == .success, sizeError == .success else {
            return .failure(.applyFailed)
        }

        guard let origin = AXAttribute.point(element, kAXPositionAttribute as String),
              let size = AXAttribute.size(element, kAXSizeAttribute as String)
        else {
            return .failure(.applyFailed)
        }
        return .success(CGRect(origin: origin, size: size))
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }

    @discardableResult
    private static func setPoint(_ element: AXUIElement, _ attribute: String, _ point: CGPoint) -> AXError {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

    @discardableResult
    private static func setSize(_ element: AXUIElement, _ attribute: String, _ size: CGSize) -> AXError {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }
}
