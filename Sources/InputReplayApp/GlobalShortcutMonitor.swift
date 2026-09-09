import AppKit

final class GlobalShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let replayHandler: () -> Void

    init(replayHandler: @escaping () -> Void) {
        self.replayHandler = replayHandler
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handle(event) == true {
                return nil
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == [.control, .option] else { return false }
        guard event.charactersIgnoringModifiers?.lowercased() == "r" else { return false }

        DispatchQueue.main.async { [replayHandler] in
            replayHandler()
        }
        return true
    }
}
