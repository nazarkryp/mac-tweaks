# MacTweaks

A menu bar app plus a FinderSync extension. The extension adds items to the Finder context menu. The host app does the work.

## Build and run

```zsh
xcodebuild -project MacTweaks.xcodeproj -scheme MacTweaks -configuration Debug -derivedDataPath build build
pkill -x MacTweaks; open build/Build/Products/Debug/MacTweaks.app && killall Finder
```

Finder loads the new extension only after `killall Finder`. The project has no tests.

## Project file

The `.xcodeproj` is hand-written. There is no XcodeGen. The folders are synchronized groups:

- `MacTweaks/` is in the host target.
- `FinderExtension/` is in the extension target.
- `Shared/` is in both targets.
- `Config/` is in no target. Build settings point to its plists and entitlements.

A new `.swift` file in a folder joins that folder's target. Do not add it to `project.pbxproj`.

## Action flow

1. The sandboxed extension builds the menu from the settings in the App Group defaults.
2. On a click, it opens `mactweaks://run?action=…&token=…&path=…`. `Shared/MenuAction.swift` holds this format.
3. The host receives the URL in an Apple Event handler in `AppDelegate`. Keep it there: SwiftUI `onOpenURL` opens a window.
4. `ActionRouter` checks the token and the paths, then runs the action.

These names are contracts between the two targets and with stored data. A change breaks an installed extension or loses user settings:

- the URL format in `Shared/MenuAction.swift`
- the defaults keys `settings.v1` and `actionToken`
- the Info.plist key `MTAppGroupIdentifier`

## Concurrency

The default actor isolation is `MainActor`. Finder calls the extension on a background XPC queue, not on the main thread.

- Mark each `FIFinderSync` override and menu action `nonisolated`. Wrap the body in `runOnMain` (`FinderSync.swift`).
- A direct `MainActor.assumeIsolated` in an override crashes with `EXC_BREAKPOINT`.
- Write `@objc nonisolated`. The other order does not compile.

## Finder menu items

Finder copies the menu before it shows it. The copy keeps `tag`, `title`, `image`, and `action`. It loses `representedObject`. Put the template index in `tag`.

## Names

The settings model is `AppSettings`. A type named `Settings` hides the SwiftUI `Settings` scene.

## Settings window

`SettingsWindowController` is an AppKit window, not a SwiftUI `Settings` scene. The app must open Settings from `AppDelegate` when the user opens the app again with the menu bar icon hidden. The SwiftUI scene cannot do that on macOS 14 and later. The Dock icon shows only while the window is open.

## Signing

- The App Group is `$(DEVELOPMENT_TEAM).com.nazarkryp.MacTweaks`. A group with the Team ID prefix needs no provisioning profile.
- The build setting `APP_GROUP_IDENTIFIER` feeds both entitlements files and `MTAppGroupIdentifier`.
- A new team makes a new group. The extension then reads the default settings.
- The host app is not sandboxed. The extension is sandboxed.

## App icon

`Design/render-app-icon.swift` draws the icon. Its header comment has the steps to regenerate the PNGs.

Finder and the Dock cache icons. To see a new icon:

```zsh
touch build/Build/Products/Debug/MacTweaks.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/Build/Products/Debug/MacTweaks.app
killall Finder Dock
```

## Debug the extension

- Extension state: `pluginkit -m -v -i com.nazarkryp.MacTweaks.FinderExtension` (`+` means on).
- Logs: `log stream --predicate 'subsystem BEGINSWITH "com.nazarkryp.MacTweaks"'`.
- Crashes: `~/Library/Logs/DiagnosticReports/MacTweaksFinderExtension-*.ips`.
- No menu items at all usually means the extension crashed. Read the crash report first.
