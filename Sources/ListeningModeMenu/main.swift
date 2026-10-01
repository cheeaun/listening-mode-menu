import AppKit
import Foundation
import os

enum ListeningMode: String, CaseIterable {
    case off = "Off"
    case noiseCancellation = "Noise Cancellation"
    case transparency = "Transparency"
    case adaptive = "Adaptive"

    var symbolName: String {
        switch self {
        case .off: "circle.slash"
        case .noiseCancellation: "circle.circle.fill"
        case .transparency: "circle.dotted"
        case .adaptive: "circle.dotted.circle"
        }
    }

    static func parse(_ rawValue: String) -> ListeningMode? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[\s_-]+"#, with: "", options: .regularExpression)

        switch normalized {
        case "normal", "off", "disabled":
            return .off
        case "anc", "noise", "noisecancellation", "noise-cancellation":
            return .noiseCancellation
        case "transparency", "trans":
            return .transparency
        case "autoanc", "adaptive", "adaptiveaudio", "auto":
            return .adaptive
        default:
            return nil
        }
    }
}

struct ListeningModeParser {
    // The pattern is a hardcoded, validated regex for bluetoothd LsnM log lines.
    private static let regex: NSRegularExpression = {
        guard let compiled = try? NSRegularExpression(pattern: #"\bLsnM\s+([^,>]+)"#) else {
            fatalError("Invalid regex pattern: Could not compile LsnM log pattern")
        }
        return compiled
    }()

    static func mode(from line: String) -> ListeningMode? {
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              let modeRange = Range(match.range(at: 1), in: line)
        else {
            return nil
        }

        return ListeningMode.parse(String(line[modeRange]))
    }
}

private final class BluetoothLogMonitor {
    private let logger = Logger(subsystem: AppMetadata.bundleIdentifier, category: "BluetoothLogMonitor")
    private let queue = DispatchQueue(label: "\(AppMetadata.bundleIdentifier).log-monitor")
    private var streamTask: Process?
    private var buffer = ""
    private var isStopping = false

    var onModeChange: ((ListeningMode) -> Void)?

    func start() {
        queue.async { [weak self] in
            self?.isStopping = false
            self?.fetchRecentMode { [weak self] in
                self?.startStream()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            isStopping = true
            streamTask?.terminationHandler = nil
            streamTask?.terminate()
            streamTask = nil
            buffer = ""
        }
    }

    private func fetchRecentMode(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                completion()
                return
            }

            let output = self.runLogCommand(arguments: [
                "show",
                "--last", "60s",
                "--style", "compact",
                "--predicate", AppMetadata.bluetoothLogPredicate,
            ])

            self.queue.async {
                if let output = output {
                    output
                        .split(separator: "\n")
                        .reversed()
                        .lazy
                        .compactMap { ListeningModeParser.mode(from: String($0)) }
                        .first
                        .map { self.deliver($0) }
                }
                completion()
            }
        }
    }

    private func startStream() {
        streamTask?.terminationHandler = nil
        streamTask?.terminate()
        streamTask = nil

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = [
            "stream",
            "--style", "compact",
            "--predicate", AppMetadata.bluetoothLogPredicate,
        ]
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            self?.queue.async {
                self?.consume(chunk)
            }
        }

        task.terminationHandler = { [weak self] _ in
            guard let self else { return }
            queue.asyncAfter(deadline: .now() + .seconds(1)) {
                guard !self.isStopping else { return }
                self.logger.warning("bluetoothd log stream ended; restarting")
                self.startStream()
            }
        }

        do {
            try task.run()
            streamTask = task
        } catch {
            logger.error("Could not start bluetoothd log stream: \(error.localizedDescription)")
        }
    }

    private func consume(_ chunk: String) {
        buffer += chunk

        if buffer.count > 1_000_000 {
            buffer = String(buffer.suffix(100_000))
        }

        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer.removeSubrange(...newlineIndex)

            guard let mode = ListeningModeParser.mode(from: line) else { continue }
            deliver(mode)
        }
    }

    private func deliver(_ mode: ListeningMode) {
        DispatchQueue.main.async { [onModeChange] in
            onModeChange?(mode)
        }
    }

    private func runLogCommand(arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = arguments
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            logger.error("Could not run log command: \(error.localizedDescription)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            logger.error("log command exited with status \(task.terminationStatus)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

enum AppMetadata {
    static let appName = "Listening Mode Menu"
    static let executableName = "ListeningModeMenu"
    static let bundleIdentifier = "cheeaun.ListeningModeMenu"
    static let repositoryURL = URL(string: "https://github.com/cheeaun/listening-mode-menu")!
    static let bluetoothLogPredicate = #"process == "bluetoothd" AND eventMessage CONTAINS "LsnM""#

    static func versionInfo(from infoDictionary: [String: Any]) -> (version: String, build: String) {
        (
            version: infoDictionary["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: infoDictionary["CFBundleVersion"] as? String ?? "Unknown"
        )
    }

    static var aboutCredits: NSAttributedString {
        let credits = NSMutableAttributedString(string: "Shows your AirPods listening mode in the menu bar.\n")
        credits.append(NSAttributedString(
            string: "GitHub Repository",
            attributes: [.link: repositoryURL]
        ))
        return credits
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = BluetoothLogMonitor()
    private var currentMode: ListeningMode?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()

        monitor.onModeChange = { [weak self] mode in
            self?.apply(mode)
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func configureStatusItem() {
        statusItem.button?.image = image(systemSymbolName: "ear", accessibilityDescription: AppMetadata.appName)
        statusItem.button?.toolTip = AppMetadata.appName

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Listening Mode: Unknown", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Monitoring bluetoothd logs", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About Listening Mode Menu", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showAbout() {
        let versionInfo = AppMetadata.versionInfo(from: Bundle.main.infoDictionary ?? [:])
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppMetadata.appName,
            .version: versionInfo.build,
            .applicationVersion: versionInfo.version,
            .credits: AppMetadata.aboutCredits,
        ])
    }

    private func apply(_ mode: ListeningMode) {
        guard mode != currentMode else { return }

        currentMode = mode
        statusItem.button?.image = image(systemSymbolName: mode.symbolName, accessibilityDescription: mode.rawValue)
        statusItem.button?.toolTip = "\(AppMetadata.appName): \(mode.rawValue)"
        statusItem.menu?.items.first?.title = "Listening Mode: \(mode.rawValue)"
    }

    private func image(systemSymbolName: String, accessibilityDescription: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
