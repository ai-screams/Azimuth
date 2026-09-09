import ApplicationServices

nonisolated enum AXAttribute {
    static func copyValue(_ element: AXUIElement, _ attribute: String) -> (value: CFTypeRef?, error: AXError) {
        var ref: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        return (ref, error)
    }

    // MARK: - 읽기 (오류 동반)

    // AX 타임아웃은 `.cannotComplete`로 표면화되므로(AXError.h: "messaging has failed in some way or the
    // application has not yet responded"), "값이 없다"와 "앱이 답하지 않았다"를 구분해야 하는 호출부는
    // 아래 오류 동반 변형을 쓴다. 그 구분이 필요 없는 곳은 그대로 얇은 래퍼를 쓴다.

    static func stringValue(_ element: AXUIElement, _ attribute: String) -> (value: String?, error: AXError) {
        let (value, error) = copyValue(element, attribute)
        guard error == .success else { return (nil, error) }
        return (value as? String, error)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        stringValue(element, attribute).value
    }

    static func boolValue(_ element: AXUIElement, _ attribute: String) -> (value: Bool?, error: AXError) {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return (nil, error) }
        // swiftlint:disable:next force_cast
        return (CFBooleanGetValue((value as! CFBoolean)), error)
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        boolValue(element, attribute).value
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> (element: AXUIElement?, error: AXError) {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return (nil, error)
        }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement, error)
    }

    static func pointValue(_ element: AXUIElement, _ attribute: String) -> (value: CGPoint?, error: AXError) {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return (nil, error) }
        // swiftlint:disable:next force_cast
        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return (nil, error) }
        return (point, error)
    }

    static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        pointValue(element, attribute).value
    }

    static func sizeValue(_ element: AXUIElement, _ attribute: String) -> (value: CGSize?, error: AXError) {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return (nil, error) }
        // swiftlint:disable:next force_cast
        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return (nil, error) }
        return (size, error)
    }

    static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        sizeValue(element, attribute).value
    }

    // MARK: - 쓰기 (읽기 래퍼와 대칭. AXValueCreate/CFTypeRef 보일러플레이트를 한곳에 모은다.)

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, point: CGPoint) -> AXError {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, size: CGSize) -> AXError {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }
}
