import ApplicationServices

nonisolated enum AXAttribute {
    static func copyValue(_ element: AXUIElement, _ attribute: String) -> (value: CFTypeRef?, error: AXError) {
        var ref: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        return (ref, error)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        let (value, error) = copyValue(element, attribute)
        guard error == .success else { return nil }
        return value as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        return CFBooleanGetValue((value as! CFBoolean))
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> (element: AXUIElement?, error: AXError) {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return (nil, error)
        }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement, error)
    }

    static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        let (value, error) = copyValue(element, attribute)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
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
