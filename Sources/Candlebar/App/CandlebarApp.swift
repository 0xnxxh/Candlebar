import AppKit

@main
enum CandlebarApp {
    @MainActor
    static func main() {
        runner.run()
    }

    @MainActor
    private static let runner = MainRunner()
}

@MainActor
private final class MainRunner {
    private let appDelegate = AppDelegate()

    func run() {
        NSApplication.shared.delegate = appDelegate
        NSApplication.shared.run()
    }
}
