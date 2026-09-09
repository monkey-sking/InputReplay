import AppKit

let application = NSApplication.shared
let delegate = InputReplayAppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
