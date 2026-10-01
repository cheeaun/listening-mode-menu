# Launch at Login

The menu has a **Launch at Login** item under About. It is a checkable item: on means the app is registered to start when you log in.

## How it works

The app uses `SMAppService.mainApp` from `ServiceManagement` — Apple's current login-item API (macOS 13+, and this app targets 14). `register()` adds this app to the login items, `unregister()` removes it, and `status` reports what macOS currently has. There is no helper app, no launchd plist, and no legacy login-item list to write, which is why `scripts/build.sh` needs no extra signing or bundling steps for this feature.

All of it lives in the `LaunchAtLogin` type in `Sources/ListeningModeMenu/main.swift`:

| Member | Purpose |
| :--- | :--- |
| `isEnabled` | `SMAppService.mainApp.status == .enabled`, the system's answer, not a stored flag |
| `setEnabled(_:)` | Registers or unregisters, and only remembers the choice if the call succeeded |
| `syncWithBundleLocation()` | Runs at launch; re-registers a bundle that moved, otherwise defers to the system |
| `logStatus()` | Logs the status and bundle path at launch |

The menu item reflects live status rather than a cached value: `menuNeedsUpdate(_:)` refreshes the checkmark each time the menu opens, so turning the item off in System Settings is reflected on the next open. `toggleLaunchAtLogin(_:)` re-reads status after the call, so a failed registration leaves the checkmark where it was instead of lying.

Two keys are kept in `UserDefaults` under the app's bundle identifier:

- `LaunchAtLoginRequested` — the last choice that actually succeeded
- `LaunchAtLoginRegisteredPath` — which bundle path made that registration

`LaunchAtLoginRegisteredPath` is what makes relaunch safe. A registration belongs to the bundle that created it, so if the app now runs from a different path, the entry is stale and the app re-registers itself. If it runs from the *same* path and the system still says it is off, the user turned it off in System Settings, so the app clears its stored preference rather than re-enabling itself on every launch.

## Dev build vs installed app

The two environments do not behave the same, because login items are resolved through LaunchServices against a real app bundle.

Running from `dist/` inside a checkout, the status is `not found`:

```text
Login item status: not found for /Users/cheeaun/hub/listening-mode-menu/dist/Listening Mode Menu.app
```

That is expected and is not a bug in the app. The bundle is unsigned and living in a build directory, so macOS has no installed-application record to attach a login item to. An installed copy is a Developer ID-signed, notarized bundle in `/Applications`, which resolves normally and reports `not registered` until you turn it on, then `enabled`.

What this means in practice:

- **From `scripts/build.sh run`:** treat the menu item as unreliable. If `register()` fails, the error is logged, nothing is stored, and the checkmark stays off. Verify the feature with a signed bundle in `/Applications`.
- **From `scripts/build.sh debug`:** the bare `SwiftPM` executable is launched directly, not from inside the bundle, so `Bundle.main` is not the app bundle at all and login-item calls cannot work. This is the least representative way to run the app.
- **Installed:** the intended path. Turning it on survives logout, restart, and app updates, because the registration follows the app's bundle identity rather than a copy of the binary.

Because the registration is path-specific, manually copying an already-enabled `dist/` build into `/Applications` does not carry the setting over. The next launch detects the move and re-registers, which is the behaviour `syncWithBundleLocation()` exists for.

## Inspecting it

The login item list is in **System Settings > General > Login Items**. To watch what the app decides:

```bash
scripts/build.sh logs
```

Or for an app already running:

```bash
/usr/bin/log show --info --style compact --last 5m \
  --predicate 'subsystem == "cheeaun.ListeningModeMenu" AND category == "LaunchAtLogin"'
```

The diagnostic fields are logged with `privacy: .public` so the status and bundle path are readable without enabling private logging for the subsystem.

## Uninstalling

Turn off **Launch at Login** before deleting the app, then quit from the menu and move the bundle to the Trash. Deleting an app that is still registered leaves a dead entry in the Login Items list until macOS cleans it up.

## Limitations

- A status of `requires approval` means macOS wants the user's consent in System Settings. The app reports it rather than trying to force the item on.
- `SMAppService` is the only login-item API used here, so there is no macOS 12 or earlier support; the app already requires macOS 14.
