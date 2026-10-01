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
- Release: the version lives in the git tag, never in a file. Bump it by tagging the release commit; there is nothing to edit and no version to keep in sync in README.md, which links `releases/latest`. Tagging `v*.*.*` publishes a signed, notarized GitHub Release. See [Maintainer releases](CONTRIBUTING.md#maintainer-releases) for the copy-paste command and verification steps.

## Conventions

- Keep app logic in Swift, not shell pipelines.
- Keep generated artifacts out of git: `.build/`, `dist/`, `*.app`, `*.dmg`, and `*.zip`.
- The app name is `Listening Mode Menu`; the SwiftPM executable target is `ListeningModeMenu`.
- The app currently relies on `bluetoothd` log lines containing `LsnM`, so parser changes should be validated against real log output.

## Verification

- After editing Swift sources, re-read the changed lines before rebuilding — the editor tool can report success without the change persisting. Confirm via `grep`/`sed -n` that the new pattern is actually in the file, especially for regex literals and escape sequences (`\b`, `\s`, `\n` vs `\\b`, `\\s`, `\\n`).
- A successful `swift build` only proves the code compiles; it does not prove the binary is correct. Always smoke-test the rebuilt `.app` (launch, watch the menu bar item, or query via AppleScript) before shipping or notarizing.
- Login items are environment-dependent. `LaunchAtLogin` uses `SMAppService.mainApp`, and an unsigned bundle in `dist/` reports status `not found`, so only a signed copy in `/Applications` can confirm the toggle actually registers. Read the decision from the logs rather than assuming, and see [docs/launch-at-login.md](docs/launch-at-login.md).
- `swift test` runs `Tests/ListeningModeMenuTests`, which covers parsing only. The menu and login-item code has no automated coverage because it needs a real app bundle and user-level login-item state.
- Tagging is irreversible once pushed. Before creating a release tag, confirm the tree is clean and the release-worthy commits are on `main`. Derive the next version from the highest existing tag rather than typing it, and never bump a tag that has already been pushed. Pushing a `v*.*.*` tag publishes a real signed release, so treat the request as public and hard to reverse: ask before tagging if the user only said "bump version" without confirming they want a release.
