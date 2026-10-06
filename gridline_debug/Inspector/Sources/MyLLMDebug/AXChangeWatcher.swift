import ApplicationServices
import Foundation

final class AXChangeWatcher {
    private let pid: pid_t
    private let onChange: (String) -> Void
    private var observer: AXObserver?
    private var source: CFRunLoopSource?
    private var notifications: [String] = []

    init?(pid: pid_t, onChange: @escaping (String) -> Void) {
        self.pid = pid
        self.onChange = onChange
        var created: AXObserver?
        let result = AXObserverCreate(pid, { _, _, notification, context in
            guard let context else { return }
            let watcher = Unmanaged<AXChangeWatcher>.fromOpaque(context).takeUnretainedValue()
            let name = notification as String
            DispatchQueue.main.async { watcher.onChange(name) }
        }, &created)
        guard result == .success, let created else { return nil }
        observer = created
        let runLoopSource = AXObserverGetRunLoopSource(created)
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        let app = AXUIElementCreateApplication(pid)
        let names = [
            kAXFocusedUIElementChangedNotification,
            kAXValueChangedNotification,
            kAXTitleChangedNotification,
            kAXLayoutChangedNotification,
            kAXSelectedTextChangedNotification,
            kAXMenuItemSelectedNotification
        ]
        for name in names where AXObserverAddNotification(created, app, name as CFString, Unmanaged.passUnretained(self).toOpaque()) == .success {
            notifications.append(name)
        }
    }

    func stop() {
        guard let observer else { return }
        let app = AXUIElementCreateApplication(pid)
        for name in notifications { AXObserverRemoveNotification(observer, app, name as CFString) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        notifications.removeAll()
        self.source = nil
        self.observer = nil
    }

    deinit { stop() }
}
