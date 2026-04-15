import AppKit

@main
enum GridMoveApp {
    static func main() {
        do {
            if let action = try CommandLineAction.parse(arguments: Array(CommandLine.arguments.dropFirst())) {
                let application = NSApplication.shared
                application.setActivationPolicy(.prohibited)
                let runner = CommandLineRunner()
                exit(runner.run(action: action))
            }
        } catch let error as CommandLineActionError {
            FileHandle.standardError.write(Data((error.message + "\n" + CommandLineAction.usage + "\n").utf8))
            exit(EXIT_FAILURE)
        } catch {
            FileHandle.standardError.write(Data(("Unexpected CLI error: \(error.localizedDescription)\n").utf8))
            exit(EXIT_FAILURE)
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}
