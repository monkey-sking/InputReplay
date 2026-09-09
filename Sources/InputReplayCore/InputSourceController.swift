import Foundation
import Carbon

public struct InputSourceDescriptor: Sendable, Equatable {
    public let id: String
    public let localizedName: String?
    public let bundleIdentifier: String?

    public init(id: String, localizedName: String?, bundleIdentifier: String?) {
        self.id = id
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
    }
}

public final class InputSourceController: @unchecked Sendable {
    public typealias ChangeHandler = @Sendable (InputSourceDescriptor?) -> Void

    private var handler: ChangeHandler?
    private var observing = false

    public init() {}

    deinit {
        stopObserving()
    }

    public func current() -> InputSourceDescriptor? {
        guard let unmanaged = TISCopyCurrentKeyboardInputSource() else { return nil }
        return descriptor(for: unmanaged.takeRetainedValue())
    }

    @discardableResult
    public func select(id: String) -> Bool {
        let filter = [kTISPropertyInputSourceID: id] as CFDictionary
        guard let unmanaged = TISCreateInputSourceList(filter, false) else { return false }
        let sources = unmanaged.takeRetainedValue() as NSArray
        guard let source = sources.firstObject as? TISInputSource else { return false }
        return TISSelectInputSource(source) == noErr
    }

    public func availableKeyboardInputSources() -> [InputSourceDescriptor] {
        guard let unmanaged = TISCreateInputSourceList(nil, false) else { return [] }
        let sources = unmanaged.takeRetainedValue() as NSArray
        return sources.compactMap { item in
            guard let source = item as? TISInputSource else { return nil }
            return descriptor(for: source)
        }
    }

    public func startObserving(_ handler: @escaping ChangeHandler) {
        self.handler = handler
        guard !observing else { return }
        observing = true

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: Notification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    public func stopObserving() {
        guard observing else { return }
        observing = false
        DistributedNotificationCenter.default.removeObserver(self)
        handler = nil
    }

    @objc private func inputSourceDidChange() {
        handler?(current())
    }

    private func descriptor(for source: TISInputSource) -> InputSourceDescriptor? {
        guard let id = stringProperty(source, key: kTISPropertyInputSourceID) else { return nil }
        return InputSourceDescriptor(
            id: id,
            localizedName: stringProperty(source, key: kTISPropertyLocalizedName),
            bundleIdentifier: stringProperty(source, key: kTISPropertyBundleID)
        )
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
