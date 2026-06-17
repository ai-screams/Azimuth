import ApplicationServices

enum WindowFrameWriter {
    static func apply(_ frame: CGRect, to element: AXUIElement) -> Result<CGRect, WindowCommandError> {
        guard isSettable(element, kAXPositionAttribute), isSettable(element, kAXSizeAttribute) else {
            return .failure(.notMovable)
        }

        setPoint(element, kAXPositionAttribute, frame.origin)
        setSize(element, kAXSizeAttribute, frame.size)
        // 최소 크기 제약으로 위치가 밀리는 창을 위해 위치를 한 번 더 적용한다.
        setPoint(element, kAXPositionAttribute, frame.origin)

        guard let origin = AXAttribute.point(element, kAXPositionAttribute as String),
              let size = AXAttribute.size(element, kAXSizeAttribute as String)
        else {
            return .failure(.notMovable)
        }
        return .success(CGRect(origin: origin, size: size))
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }

    private static func setPoint(_ element: AXUIElement, _ attribute: String, _ point: CGPoint) {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

    private static func setSize(_ element: AXUIElement, _ attribute: String, _ size: CGSize) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }
}
