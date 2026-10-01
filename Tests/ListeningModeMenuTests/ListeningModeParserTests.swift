import XCTest
@testable import ListeningModeMenu

final class ListeningModeParserTests: XCTestCase {
    func testParsesCommonRawValues() {
        XCTAssertEqual(ListeningMode.parse("Off"), .off)
        XCTAssertEqual(ListeningMode.parse("Normal"), .off)
        XCTAssertEqual(ListeningMode.parse("Disabled"), .off)
        XCTAssertEqual(ListeningMode.parse("ANC"), .noiseCancellation)
        XCTAssertEqual(ListeningMode.parse("Noise"), .noiseCancellation)
        XCTAssertEqual(ListeningMode.parse("Noise Cancellation"), .noiseCancellation)
        XCTAssertEqual(ListeningMode.parse("noise-cancellation"), .noiseCancellation)
        XCTAssertEqual(ListeningMode.parse("Transparency"), .transparency)
        XCTAssertEqual(ListeningMode.parse("Trans"), .transparency)
        XCTAssertEqual(ListeningMode.parse("Adaptive"), .adaptive)
        XCTAssertEqual(ListeningMode.parse("AdaptiveAudio"), .adaptive)
        XCTAssertEqual(ListeningMode.parse("AutoANC"), .adaptive)
        XCTAssertEqual(ListeningMode.parse("Auto"), .adaptive)
    }

    func testParsesWhitespaceAndCaseVariants() {
        XCTAssertEqual(ListeningMode.parse("  ANC  "), .noiseCancellation)
        XCTAssertEqual(ListeningMode.parse("\nTransparency\t"), .transparency)
        XCTAssertEqual(ListeningMode.parse("NOISE_CANCELLATION"), .noiseCancellation)
        XCTAssertEqual(ListeningMode.parse("adaptive-audio"), .adaptive)
    }

    func testRejectsUnknownValues() {
        XCTAssertNil(ListeningMode.parse(""))
        XCTAssertNil(ListeningMode.parse("   "))
        XCTAssertNil(ListeningMode.parse("Unknown"))
        XCTAssertNil(ListeningMode.parse("123"))
        XCTAssertNil(ListeningMode.parse("LsnM"))
    }

    func testAllCasesHaveSymbols() {
        for mode in ListeningMode.allCases {
            XCTAssertFalse(mode.symbolName.isEmpty, "Missing symbol for \(mode)")
        }
    }

    func testModeFromLogLineContainingLsnM() {
        XCTAssertEqual(
            ListeningModeParser.mode(from: "2026-06-18 20:00:00.000 bluetoothd[123]: LsnM ANC>"),
            .noiseCancellation
        )
        XCTAssertEqual(
            ListeningModeParser.mode(from: "bluetoothd LsnM Transparency, device=AirPods"),
            .transparency
        )
        XCTAssertEqual(
            ListeningModeParser.mode(from: "LsnM Adaptive"),
            .adaptive
        )
        XCTAssertEqual(
            ListeningModeParser.mode(from: "LsnM Off"),
            .off
        )
    }

    func testModeFromLogLineIgnoresUnrelatedLines() {
        XCTAssertNil(ListeningModeParser.mode(from: "unrelated bluetoothd noise"))
        XCTAssertNil(ListeningModeParser.mode(from: ""))
        XCTAssertNil(ListeningModeParser.mode(from: "LsnM NotARealMode"))
        XCTAssertNil(ListeningModeParser.mode(from: "prefix LsnM "))
    }

    func testModeStopsAtCommaOrAngleBracket() {
        // Trailing punctuation after the mode must not leak into the capture group.
        XCTAssertEqual(
            ListeningModeParser.mode(from: "LsnM ANC,extra=1"),
            .noiseCancellation
        )
        XCTAssertEqual(
            ListeningModeParser.mode(from: "LsnM Transparency>trailing"),
            .transparency
        )
    }

    func testRejectsMalformedAndTruncatedLogLines() {
        XCTAssertNil(ListeningModeParser.mode(from: "LsnM"))
        XCTAssertNil(ListeningModeParser.mode(from: "LsnM "))
        XCTAssertNil(ListeningModeParser.mode(from: "LsnM ,"))
        XCTAssertNil(ListeningModeParser.mode(from: "prefix LsnM NotARealMode"))
        XCTAssertEqual(ListeningModeParser.mode(from: "LsnM ANC,"), .noiseCancellation)
    }

    func testParsesModeFromVerboseBluetoothLogLine() {
        XCTAssertEqual(
            ListeningModeParser.mode(from: "2026-06-18 20:00:00.000 Df bluetoothd[123:456] [com.apple.bluetooth:AirPods] LsnM AdaptiveAudio, device=AirPods Pro"),
            .adaptive
        )
    }

    func testAppMetadataReadsVersionAndBuildFromBundleInfo() {
        let versionInfo = AppMetadata.versionInfo(from: [
            "CFBundleShortVersionString": "0.0.5",
            "CFBundleVersion": "42",
        ])

        XCTAssertEqual(versionInfo.version, "0.0.5")
        XCTAssertEqual(versionInfo.build, "42")
    }

    func testAppMetadataFallsBackWhenBundleInfoIsMissing() {
        let versionInfo = AppMetadata.versionInfo(from: [:])

        XCTAssertEqual(versionInfo.version, "Unknown")
        XCTAssertEqual(versionInfo.build, "Unknown")
    }

    func testAboutCreditsIncludeClickableRepositoryLink() {
        let credits = AppMetadata.aboutCredits
        let repositoryRange = (credits.string as NSString).range(of: "GitHub Repository")

        XCTAssertTrue(credits.string.contains("Shows your AirPods listening mode in the menu bar."))
        XCTAssertEqual(credits.attribute(.link, at: repositoryRange.location, effectiveRange: nil) as? URL, AppMetadata.repositoryURL)
    }
}
