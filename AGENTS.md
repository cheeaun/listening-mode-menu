# Agent Notes

## Project

`Listening Mode Menu` is a small macOS menu bar app. Source lives in `Sources/ListeningModeMenu/main.swift`; generated app bundles and DMGs live in `dist/`.

## Commands

- Build: `scripts/build.sh build`
- Run: `scripts/build.sh run`
- Debug under lldb: `scripts/build.sh debug`
- Stream app logs: `scripts/build.sh logs`
- Stream subsystem logs: `scripts/build.sh telemetry`
- Verify process: `scripts/build.sh verify`
- Package DMG: `scripts/build.sh dmg`
- Sign: `SIGN_IDENTITY="Developer ID Application: ..." scripts/build.sh sign`
- Notarize: `SIGN_IDENTITY="Developer ID Application: ..." NOTARY_PROFILE="..." scripts/build.sh notarize`

## Conventions

- Keep app logic in Swift, not shell pipelines.
- Keep generated artifacts out of git: `.build/`, `dist/`, `*.app`, `*.dmg`, and `*.zip`.
- The app name is `Listening Mode Menu`; the SwiftPM executable target is `ListeningModeMenu`.
- The app currently relies on `bluetoothd` log lines containing `LsnM`, so parser changes should be validated against real log output.

## Verification

- After editing Swift sources, re-read the changed lines before rebuilding — the editor tool can report success without the change persisting. Confirm via `grep`/`sed -n` that the new pattern is actually in the file, especially for regex literals and escape sequences (`\b`, `\s`, `\n` vs `\\b`, `\\s`, `\\n`).
- A successful `swift build` only proves the code compiles; it does not prove the binary is correct. Always smoke-test the rebuilt `.app` (launch, watch the menu bar item, or query via AppleScript) before shipping or notarizing.
- There are currently no automated tests. `Package.swift` defines only the executable target. Consider adding a test target covering `ListeningModeParser` against real `log show` output so regex regressions surface at `swift test` time.
