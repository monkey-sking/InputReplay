import Foundation
import InputReplayCore

@main
struct InputReplayProbe {
    static func main() async {
        let command = CommandLine.arguments.dropFirst().first ?? "help"
        let inputSources = InputSourceController()

        switch command {
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
                    print("keyCode=\(event.keyCode) source=\(event.inputSourceID) buffer=\(count)")
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

              list-sources    List input sources discovered by macOS
              current-source  Print the current input source
              watch-source    Observe real input-source changes
              capture         Capture recent key-down metadata in memory only

            The probe intentionally does not perform destructive recovery yet.
            Replay/rollback will only be enabled after a reliable restore path is verified.
            """)
        }
    }
}
