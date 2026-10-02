# Listening Mode Menu

Menu bar app that shows the current AirPods listening mode on macOS.

**[Download the latest release](https://github.com/cheeaun/listening-mode-menu/releases/latest)** · Apple Silicon (arm64) · macOS 14+

<img src="docs/assets/menu-screenshot.jpg" alt="Listening Mode Menu in the macOS menu bar, showing the current AirPods listening mode" width="760">

The app reads `bluetoothd` log events, then updates a menu bar icon when the mode changes: Off, Noise Cancellation, Transparency, or Adaptive. The menu holds the current mode, **About**, **Launch at Login**, and **Quit**.

## Install

1. Download `Listening.Mode.Menu-<version>.dmg` from [GitHub Releases](https://github.com/cheeaun/listening-mode-menu/releases/latest).
2. Verify the digest with `shasum -a 256 -c "Listening.Mode.Menu-<version>.dmg.sha256"`.
3. Open the DMG and drag the app to `/Applications`.

Releases are Developer ID signed and notarized, so macOS may ask you to confirm the first open.

To uninstall, turn off **Launch at Login** if it is on, quit from the menu, and move the app to the Trash.

## Menu Bar Icons

| Unknown | Off | Noise Cancellation | Transparency | Adaptive |
| :---: | :---: | :---: | :---: | :---: |
| ![Unknown](docs/assets/menu-icon-unknown.png) | ![Off](docs/assets/menu-icon-off.png) | ![Noise Cancellation](docs/assets/menu-icon-noise-cancellation.png) | ![Transparency](docs/assets/menu-icon-transparency.png) | ![Adaptive](docs/assets/menu-icon-adaptive.png) |

## How It Works

The app is an accessory with no Dock icon or window. It reads recent `bluetoothd` logs for `LsnM`, normalizes variants like `ANC` and `AdaptiveAudio`, keeps a live `log stream` open for changes, and redraws the icon only when the mode actually changes.

```text
bluetoothd log line -> LsnM parser -> normalized listening mode -> menu bar icon
```

Launch at Login uses macOS's `SMAppService` API rather than a helper app or launchd agent. See [Launch at Login](docs/launch-at-login.md) for how it behaves in a dev build versus an installed one.

## Requirements

- macOS 14 or newer
- AirPods that report listening-mode changes through `bluetoothd`
- To build: Swift toolchain, plus `rsvg-convert` (`brew install librsvg`) for the icon and `create-dmg@8.1.0` for DMGs

## Build

```bash
scripts/build.sh build   # -> dist/Listening Mode Menu.app
scripts/build.sh run     # build and launch
swift test
```

Signing and notarization read `SIGN_IDENTITY` and `NOTARY_PROFILE`, either from the environment or a gitignored `.env` (`cp .env.example .env`):

```bash
scripts/build.sh sign       # sign with SIGN_IDENTITY
scripts/build.sh dmg        # build a DMG, signing first if SIGN_IDENTITY is set
scripts/build.sh notarize   # sign, notarize, staple, then package and notarize the DMG
```

`VERSION` and `BUILD_NUMBER` in `.env` only affect local builds; releases take their version from the git tag. To publish a new version, tag and push, and the release workflow does the rest — see [Maintainer releases](CONTRIBUTING.md#maintainer-releases).

## Notes

Mode detection depends on `bluetoothd` log output, which is not a public AirPods API. If Apple changes the format, or if permissions block `log stream`, detection may stop working on some Macs or OS versions. To debug:

```bash
/usr/bin/log stream --style compact --predicate 'process == "bluetoothd" AND eventMessage CONTAINS "LsnM"'
```

The app is not sandboxed and is distributed outside the Mac App Store. GitHub Releases is the supported distribution channel and the changelog.

## License

MIT — see [LICENSE](LICENSE).
