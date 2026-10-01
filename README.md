# Listening Mode Menu

Menu bar app that shows the current AirPods listening mode on macOS.

The app watches `bluetoothd` unified log events containing `LsnM`, then updates the menu bar icon and menu title when the mode changes. It recognizes Off, Noise Cancellation, Transparency, and Adaptive. Prebuilt releases target Apple Silicon (arm64) Macs running macOS 14 or newer.

**[Download Listening Mode Menu v0.0.3 for Apple Silicon](https://github.com/cheeaun/listening-mode-menu/releases/download/v0.0.3/Listening.Mode.Menu-0.0.3.dmg)** · [All releases](https://github.com/cheeaun/listening-mode-menu/releases)

The menu bar icon reflects the current mode. Opening it shows the mode, then **About Listening Mode Menu**, which reports the version and build and links to this repository, and **Quit**.

## Install a Release

1. Download the latest `Listening.Mode.Menu-<version>.dmg` from [GitHub Releases](https://github.com/cheeaun/listening-mode-menu/releases/latest).
2. Optionally verify its SHA-256 digest from the folder containing both downloaded files with `shasum -a 256 -c "Listening.Mode.Menu-<version>.dmg.sha256"`.
3. Open the DMG and drag `Listening Mode Menu.app` to `/Applications`.
4. Open the app. macOS may ask you to confirm opening a downloaded app; releases are Developer ID signed and notarized.

To uninstall, quit the app from its menu bar menu and move `Listening Mode Menu.app` from `/Applications` to the Trash. The app does not install a background service or login item.

GitHub Releases are the supported distribution channel. The current log-based implementation has no demonstrated sandbox-compatible data source, so this project does not provide a Mac App Store build.

## Menu Bar Icons

| Unknown | Off | Noise Cancellation | Transparency | Adaptive |
| :---: | :---: | :---: | :---: | :---: |
| ![Unknown](docs/assets/menu-icon-unknown.png) | ![Off](docs/assets/menu-icon-off.png) | ![Noise Cancellation](docs/assets/menu-icon-noise-cancellation.png) | ![Transparency](docs/assets/menu-icon-transparency.png) | ![Adaptive](docs/assets/menu-icon-adaptive.png) |

## How It Works

`Listening Mode Menu` is an accessory app, so it has no Dock icon or main window. It creates one menu bar status item, starts by reading the last few seconds of `bluetoothd` logs, then keeps a live `log stream` open for future listening-mode changes.

The app filters for log messages that contain `LsnM`, extracts the mode value, normalizes common variants like `ANC` and `AdaptiveAudio`, and updates the menu bar icon only when the mode actually changes.

```text
bluetoothd log line -> LsnM parser -> normalized listening mode -> menu bar icon
```

The menu contains the current mode, the log source, an About panel with the installed app version and build number, a link to this GitHub repository, and a Quit item. Before a mode has been detected, the app shows an AirPods Pro symbol.

## Requirements

- macOS 14 or newer
- Swift toolchain from Xcode or Command Line Tools
- AirPods that emit listening-mode changes through `bluetoothd`
- `rsvg-convert` (from `brew install librsvg`) to generate the app icon from `assets/app-icon.svg`; builds skip the icon if it is unavailable
- Node.js 24 LTS and npm only when creating a DMG with `scripts/build.sh dmg`

## Build

```bash
scripts/build.sh build
```

For GitHub Actions setup, version tagging, and publishing notarized releases, see [Maintainer releases](CONTRIBUTING.md#maintainer-releases).

The app bundle is written to:

```text
dist/Listening Mode Menu.app
```

Run locally:

```bash
scripts/build.sh run
```

Build a Finder-styled DMG (uses `create-dmg` v8.1.0's default app-to-Applications window):

```bash
npm install --global create-dmg@8.1.0
scripts/build.sh dmg
```

The DMG uses the upstream tool's default layout and artwork. `scripts/build.sh dmg` does not require signing or notarization; when `SIGN_IDENTITY` is set, it signs the app first. The release workflow separately signs, notarizes, and staples both the app and DMG.

Sign for distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build.sh sign
```

Notarize and staple:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notarytool-profile" \
scripts/build.sh notarize
```

You can also put these values in a local `.env` file. It is ignored by git:

```bash
cp .env.example .env
```

Then edit `.env`:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
NOTARY_PROFILE="notarytool-profile"
VERSION="1.0.0"
BUILD_NUMBER="1"
```

After that, this is enough:

```bash
scripts/build.sh notarize
```

## Testing

Run tests with:

```bash
swift test
```

`ListeningModeMenuTests` covers:
- `ListeningMode.parse` for common, whitespace, case, and unknown values
- `ListeningModeParser.mode(from:)` for verbose and truncated `LsnM` log lines, unrelated lines, and capture-boundary cases (`,` `>`)

## Notes

This app depends on Apple log output from `bluetoothd`, which is not a public AirPods API. If Apple changes the log format, mode detection may need an update. `log stream` can require permissions or behave differently across macOS releases; detection may not work on every Mac, AirPods model, or OS version.

This app is not sandboxed and is distributed outside the Mac App Store using Developer ID signing and Apple notarization. It does not use a public AirPods listening-mode API.

`log stream` can require permissions or behave differently across macOS releases. For debugging, run:

```bash
/usr/bin/log stream --style compact --predicate 'process == "bluetoothd" AND eventMessage CONTAINS "LsnM"'
```

## License

MIT — see [LICENSE](LICENSE).
