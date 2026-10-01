# Contributing

Thanks for considering a contribution.

## Development

- macOS 14 or newer and the Swift toolchain from Xcode or Command Line Tools are required.
- Run `swift test` before opening a pull request.
- Build the app with `scripts/build.sh build`.
- Keep app behavior in Swift and do not commit `.build/`, `dist/`, app bundles, disk images, or signing credentials.

## Pull requests

Describe the change and how it was verified. For parser changes, include representative `bluetoothd` log lines and tests. Please avoid including device identifiers or other personal data from logs. For menu or About-panel changes, verify the visible version/build against the app bundle metadata.

The listening-mode log format is undocumented and may change across macOS releases; contributions should not present it as a stable Apple API.

## Maintainer releases

Releases are built and published by `.github/workflows/build-and-release.yml`. The workflow runs when a version tag is pushed. It builds an Apple Silicon (arm64) app, signs it with Developer ID, submits the app and DMG to Apple notarization, staples the tickets, and creates a GitHub Release with the DMG and its SHA-256 checksum. This is notarized direct distribution, not Mac App Store distribution.

The workflow uses the latest major of `actions/setup-node` and Node.js 24 LTS, and pins `create-dmg` to v8.1.0. The tool creates its standard Finder installer window with the app and an Applications shortcut; its background and layout are fixed by upstream. It only packages the image: the build script separately signs the DMG, and the release flow notarizes and staples the app before packaging and the DMG afterward. The tool is also required for local `scripts/build.sh dmg`; see [README.md](README.md#build).

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

The version lives in the git tag, not in a file. Nothing needs editing first: bump the version by tagging the release commit.

```bash
git checkout main && git pull --ff-only
NEXT=$(git tag --list 'v*.*.*' --sort=-v:refname | head -1 | sed 's/^v//' | awk -F. '{printf "v%d.%d.%d\n", $1, $2, $3+1}')
git tag -a "$NEXT" -m "Release $NEXT" && git push origin "$NEXT"
```

That derives the next version from the highest existing tag (patch bump) and creates an annotated tag matching the `Release vX.Y.Z` message used by earlier tags. Tag by hand for a minor or major bump, for example `v0.1.0` or `v1.0.0`.

1. Merge and push the release-ready changes to `main`. CI runs tests and builds the unsigned app on pushes to `main` and pull requests.
2. Tag and push, as above. Pushing a `v*.*.*` tag is what triggers the release; no other file records the version, so there is nothing to keep in sync.
3. Watch the **Actions** tab for the **Build and Release** workflow, or poll it:

   ```bash
   gh run list --workflow build-and-release.yml --limit 3
   gh run watch
   ```

4. Confirm the release published both assets:

   ```bash
   gh release view "$NEXT" --json assets --jq '.assets[].name'
   # Listening.Mode.Menu-0.0.7.dmg
   # Listening.Mode.Menu-0.0.7.dmg.sha256
   ```

   GitHub normalizes spaces in uploaded asset names to periods. Download both files into the same directory and check the digest with `shasum -a 256 -c "Listening.Mode.Menu-<version>.dmg.sha256"`.

The tag determines `CFBundleShortVersionString` and the DMG filename: `v1.2.3` becomes `1.2.3`. The workflow run number becomes `CFBundleVersion`; it is not manually incremented in `Package.swift`. The local build script defaults (`VERSION=1.0.0`, `BUILD_NUMBER=1`) are only for local builds and are not used to choose the tagged release version. Do not put a version number in README.md; link `releases/latest` and let the Releases page act as the changelog.

The workflow creates the GitHub Release and uploads assets, but it does not generate release notes. The release workflow is attached to tags; the CI workflow currently runs on pull requests and pushes to `main`.

### Release workflow troubleshooting

- The certificate-import action creates and unlocks a temporary `signing_temp` keychain. It does not output a keychain path. Do not reference `steps.import-certs.outputs.keychain` or try to unlock it using an empty path.
- `notarytool store-credentials` uses the runner's keychain search list, which the import action updates to include its temporary keychain. Do not pass a guessed `--keychain signing_temp.keychain` path; the actual keychain file is stored under the runner's Library Keychains directory.
- If a release job fails, inspect the first failing Actions step and its log before changing secrets. A failed tag still points at its original commit; fix the workflow on `main` and use a new version tag for the retry. Do not force-move a tag that has already been pushed.
- Confirm a successful release contains both the DMG and its `.sha256` asset, and verify the checksum after downloading both. GitHub normalizes spaces in asset filenames to periods, so the checksum must reference the published dotted filename.

If private vulnerability reporting is available in repository settings, enable it before opening the repository to public reports.
