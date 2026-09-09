import Foundation
import InputReplayCore

@main
struct InputReplayProbe {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "help"
        let inputSources = InputSourceController()

        switch command {
        case "diagnose":
            let report = SystemDiagnostics.collect(inputSources: inputSources)
            print("macOS=\(report.macOSVersion)")
            print("accessibilityTrusted=\(report.accessibilityTrusted)")
            print("frontmostApp=\(report.frontmostAppBundleIdentifier ?? "unknown") [\(report.frontmostAppName ?? "")]")
            if let current = report.currentInputSource {
                print("currentInputSource=\(current.id) [\(current.localizedName ?? "")]")
            } else {
                print("currentInputSource=unknown")
            }
            print("availableInputSources=\(report.availableInputSources.count)")
            for source in report.availableInputSources {
                print("  - \(source.id) [\(source.localizedName ?? "")] bundle=\(source.bundleIdentifier ?? "")")
            }

        case "list-sources":
            let currentID = inputSources.current()?.id
            for source in inputSources.availableKeyboardInputSources() {
                let marker = source.id == currentID ? "*" : " "
                print("\(marker) \(source.id)\t\(source.localizedName ?? "")")
            }

        case "current-source":
            if let current = inputSources.current() {
                print("id=\(current.id)")
                print("name=\(current.localizedName ?? "")")
                print("bundle=\(current.bundleIdentifier ?? "")")
            } else {
                fputs("Unable to read current input source.\n", stderr)
                exit(2)
            }

        case "snapshot-before-caret":
            guard arguments.count >= 2, let count = Int(arguments[1]), count > 0 else {
                fputs("Usage: InputReplayProbe snapshot-before-caret <character-count>\n", stderr)
                exit(2)
            }

            do {
                let snapshot = try AXTextEditor().snapshotCharactersBeforeCaret(count: count)
                print("range=\(snapshot.rangeLocation):\(snapshot.rangeLength)")
                print("text=\(snapshot.text)")
            } catch {
                fputs("Unable to snapshot focused text: \(error)\n", stderr)
                exit(4)
            }

        case "watch-source":
            print("Watching actual input-source changes. Press Control-C to stop.")
            inputSources.startObserving { source in
                guard let source else {
                    print("input-source: unknown")
                    return
                }
                print("input-source: \(source.id) [\(source.localizedName ?? "")]")
            }
            RunLoop.main.run()

        case "capture":
            let buffer = KeystrokeRingBuffer()
            let monitor = InputEventMonitor(inputSources: inputSources) { event in
                guard !event.isSynthetic else { return }
                Task {
                    await buffer.append(event)
                    let count = await buffer.snapshot().count
                    let characters = event.characters?
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\t", with: "\\t") ?? "∅"
                    print(
                        "keyCode=\(event.keyCode) chars=\(characters) repeat=\(event.isRepeat) " +
                        "source=\(event.inputSourceID) buffer=\(count)"
                    )
                }
            }

            guard monitor.start() else {
                fputs("Unable to create CGEventTap. Grant Accessibility permission and retry.\n", stderr)
                exit(3)
            }

            print("Capturing key-down metadata in memory only. Press Control-C to stop.")
            RunLoop.main.run()

        default:
            print("""
            InputReplayProbe

              diagnose                      Print non-destructive environment diagnostics
              list-sources                  List input sources discovered by macOS
              current-source                Print the current input source
              snapshot-before-caret <N>     Read N characters before the focused caret via AX
              watch-source                  Observe real input-source changes
              capture                       Capture recent key-down metadata in memory only

            The probe intentionally does not perform destructive recovery yet.
            Replay/rollback will only be enabled after a reliable restore path is verified.
            """)
        }
    }
}
