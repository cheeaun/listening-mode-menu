# Contributing

Thanks for considering a contribution.

## Development

- macOS 14 or newer and the Swift toolchain from Xcode or Command Line Tools are required.
- Run `swift test` before opening a pull request.
- Build the app with `scripts/build.sh build`.
- Keep app behavior in Swift and do not commit `.build/`, `dist/`, app bundles, disk images, or signing credentials.

## Pull requests

Describe the change and how it was verified. For parser changes, include representative `bluetoothd` log lines and tests. Please avoid including device identifiers or other personal data from logs.

The listening-mode log format is undocumented and may change across macOS releases; contributions should not present it as a stable Apple API.

## Maintainer releases

Releases are built and published by `.github/workflows/build-and-release.yml`. The workflow runs when a version tag is pushed. It builds an Apple Silicon (arm64) app, signs it with Developer ID, submits the app and DMG to Apple notarization, staples the tickets, and creates a GitHub Release with the DMG and its SHA-256 checksum. This is notarized direct distribution, not Mac App Store distribution.

### One-time setup

1. Enroll in the Apple Developer Program and create a **Developer ID Application** certificate for the team that owns the app.
2. Export the certificate and private key from Keychain Access as a password-protected `.p12` file. Base64-encode the file without line wrapping, for example with `base64 -i certificate.p12 | tr -d '\n'` on macOS.
3. Create an app-specific password for the Apple ID used for notarization.
4. In the GitHub repository, open **Settings → Secrets and variables → Actions → New repository secret** and add:

   | Secret | Value |
   | --- | --- |
   | `CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` certificate export |
   | `CERTIFICATE_P12_PASSWORD` | Password used to export the `.p12` |
   | `SIGN_IDENTITY` | Full identity, e.g. `Developer ID Application: Name (TEAMID)` |
   | `APPLE_ID` | Apple ID email used for notarization |
   | `APPLE_TEAM_ID` | Apple Developer team ID |
   | `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for that Apple ID |

5. In GitHub repository settings, protect the `v*` release tag pattern and restrict who can create or update matching tags. Consider requiring CI to pass before release commits are merged.

The release workflow uses the Actions run number as the app bundle build number. Never put certificate files, passwords, or the local `.env` in the repository. For local notarization setup, see the build instructions in [README.md](README.md).

### Publish a version

1. Merge and push the release-ready changes to `main`. CI runs tests and builds the unsigned app on pushes to `main` and pull requests.
2. Create and push a new semantic-version tag from the commit to release. Include the `v` prefix:

   ```bash
   git checkout main
   git pull --ff-only
   git tag v1.2.3
   git push origin v1.2.3
   ```

3. Watch the **Actions** tab for the `Build and Release` workflow. A failed job does not publish a release; fix the failure and use a new version tag if the release commit or version changes.
4. When the workflow succeeds, confirm that GitHub created the release and attached `Listening Mode Menu-1.2.3.dmg` and `Listening Mode Menu-1.2.3.dmg.sha256`. Download both files into the same directory and check the digest with:

   ```bash
   shasum -a 256 -c "Listening Mode Menu-1.2.3.dmg.sha256"
   ```

The tag determines `CFBundleShortVersionString` and the DMG filename: `v1.2.3` becomes `1.2.3`. The workflow run number becomes `CFBundleVersion`; it is not manually incremented in `Package.swift`. The local build script defaults (`VERSION=1.0.0`, `BUILD_NUMBER=1`) are only for local builds and are not used to choose the tagged release version.

The workflow creates the GitHub Release and uploads assets, but it does not generate release notes. Before announcing a release, edit the release on GitHub to add a concise summary of user-visible changes and any known issues. The release workflow is attached to tags; the CI workflow currently runs on pull requests and pushes to `main`.

If private vulnerability reporting is available in repository settings, enable it before opening the repository to public reports.
