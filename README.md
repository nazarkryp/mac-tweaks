# MacTweaks

MacTweaks adds useful items to the Finder right-click menu. It runs in the menu bar.

## Features

- **Copy Path** copies the full paths of the selected items. With no selection, it copies the path of the open folder.
- **Open in Terminal** opens the folder in your terminal app. For a file, it opens the folder that holds the file.
- **Open in Editor** opens the selected items in your code editor.
- **New File** creates a file from a template in the open folder. If the name is taken, MacTweaks adds a number.

In Settings, you can:

- turn each menu item on or off
- select the terminal app: Terminal, iTerm, Warp, or Ghostty
- select the editor: VS Code, Cursor, Zed, Sublime Text, or Xcode
- add, edit, sort, and remove file templates
- show or hide the menu bar icon
- start MacTweaks at login

## Requirements

- macOS 14 or later
- Xcode with an "Apple Development" signing certificate

## Build and run

```zsh
xcodebuild -project MacTweaks.xcodeproj -scheme MacTweaks -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/MacTweaks.app
```

On the first launch, MacTweaks turns on its Finder extension. If the menu items do not appear, restart Finder:

```zsh
killall Finder
```

If they still do not appear, open MacTweaks Settings > General > **Open Extension Settings…** and turn on MacTweaks.

### Release build

Build the `Release` configuration and install the app in Applications:

```zsh
xcodebuild -project MacTweaks.xcodeproj -scheme MacTweaks -configuration Release -derivedDataPath build build
pkill -x MacTweaks
ditto build/Build/Products/Release/MacTweaks.app /Applications/MacTweaks.app
open /Applications/MacTweaks.app && killall Finder
```

The Debug app and the Release app contain the same extension. If both are registered, Finder can load either one. Remove the Debug app:

```zsh
rm -rf build/Build/Products/Debug/MacTweaks.app
```

Then make sure that the extension path points to Applications:

```zsh
pluginkit -m -v -i com.nazarkryp.MacTweaks.FinderExtension
```

The Release build uses the same team and App Group as the Debug build, so it keeps your settings.

The "Apple Development" signature is enough to run the app on your Mac. To give the app to other people, sign it with a "Developer ID Application" certificate, notarize it with `xcrun notarytool`, and staple the ticket with `xcrun stapler`. Without these steps, Gatekeeper blocks the app.

### Use your own signing team

The project signs with team `YDQ9QBPM26`. To use your team, change `DEVELOPMENT_TEAM` in the project build settings. The App Group identifier uses the team ID, so it changes too.

## Use

- Right-click a file, a folder, or the empty space in a Finder window.
- Click the wrench icon in the menu bar to open Settings or to quit.
- If you hide the menu bar icon, open MacTweaks again from Applications or Spotlight to see Settings.

## How it works

The project has two targets:

- **FinderExtension** is a sandboxed FinderSync extension. It shows the menu items. On a click, it sends a `mactweaks://` URL to the host app.
- **MacTweaks** is the host app. It checks the request and does the action. It also shows Settings and the menu bar icon.

The two targets share the settings through an App Group.

## Credits

The project started from a study of [MacNewFile](https://github.com/GarfieldFluffJr/MacNewFile).
