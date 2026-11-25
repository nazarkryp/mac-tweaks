import SwiftUI

@main
struct MacTweaksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(HostPreferences.showMenuBarIconKey) private var showMenuBarIcon = true

    var body: some Scene {
        // `isInserted` also turns false when the user Cmd-drags the icon out of the menu bar.
        MenuBarExtra("MacTweaks", systemImage: "wrench.and.screwdriver", isInserted: $showMenuBarIcon) {
            TrayMenu(showSettings: appDelegate.showSettings)
        }
    }
}

private struct TrayMenu: View {
    let showSettings: () -> Void

    var body: some View {
        Button("Settings…", action: showSettings)
            .keyboardShortcut(",")

        Divider()

        Button("Quit MacTweaks") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
