import AppKit
import FinderSync
import SwiftUI

// Each tab is the root view of one toolbar tab in `SettingsWindowController`.
// All tabs have the same size, so the window keeps its size when the user changes the tab.

private enum SettingsLayout {
    static let width: CGFloat = 600
    static let height: CGFloat = 400
}

/// Shows a settings load or save error. Shows nothing when the settings load and save.
private struct SettingsNotice: View {
    enum Style { case formSection, box }

    @Environment(SettingsStore.self) private var store
    var style = Style.formSection

    var body: some View {
        if let loadError = store.loadError {
            styled(NoticeContent(title: "Settings could not be read.",
                                 message: "\(loadError) Changes are not saved until you reset the settings.") {
                Button("Reset to Defaults") { store.resetToDefaults() }
            })
        } else if let saveError = store.saveError {
            styled(NoticeContent(title: "Settings are not saved.", message: saveError) { EmptyView() })
        }
    }

    @ViewBuilder
    private func styled(_ content: some View) -> some View {
        switch style {
        case .formSection:
            Section { content }
        case .box:
            content
                .padding(10)
                .background(.yellow.opacity(0.12), in: .rect(cornerRadius: 10))
        }
    }
}

private struct NoticeContent<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            actions
        }
    }
}

// MARK: - Menu

struct MenuItemsTab: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            SettingsNotice()
            Section {
                Toggle("Copy Path", isOn: $store.settings.showCopyPath)
                Toggle("Open in terminal", isOn: $store.settings.showOpenTerminal)
                AppPicker(choices: KnownApps.terminals, selection: $store.settings.terminal)
                    .disabled(!store.settings.showOpenTerminal)
                Toggle("Open in editor", isOn: $store.settings.showOpenEditor)
                AppPicker(choices: KnownApps.editors, selection: $store.settings.editor)
                    .disabled(!store.settings.showOpenEditor)
                Toggle("New File submenu", isOn: $store.settings.showNewFile)
            } header: {
                Text("Finder context menu")
            } footer: {
                Text("With selected items, Copy Path and Open use them. With no selection, they use the open folder.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
    }
}

/// The app for an Open item. It sits indented under the item's switch.
private struct AppPicker: View {
    let choices: [AppChoice]
    @Binding var selection: AppChoice

    var body: some View {
        Picker(selection: $selection) {
            ForEach(availableChoices) { app in
                Text(AppLauncher.isInstalled(app) ? app.name : "\(app.name) (not installed)").tag(app)
            }
        } label: {
            Text("App")
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
        }
    }

    /// The installed apps, plus the current selection so the picker always has a matching tag.
    private var availableChoices: [AppChoice] {
        let installed = choices.filter(AppLauncher.isInstalled)
        return installed.contains(selection) ? installed : [selection] + installed
    }
}

// MARK: - Templates

struct TemplatesTab: View {
    @Environment(SettingsStore.self) private var store
    @State private var selection: FileTemplate.ID?

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            SettingsNotice(style: .box)
            Text("Templates appear in the New File submenu in this order. Drag to reorder. Uncheck a template to hide it.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 20) {
                templateList
                    .frame(width: 200)
                    .frame(maxHeight: .infinity)
                if let index = store.settings.templates.firstIndex(where: { $0.id == selection }) {
                    TemplateEditor(template: $store.settings.templates[index])
                } else {
                    Text("Select a template to edit it,\nor add one with +.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(20)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height, alignment: .top)
    }

    private var templateList: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach($store.settings.templates) { $template in
                    Toggle(isOn: $template.isEnabled) {
                        Text(template.title.isEmpty ? "Untitled" : template.title)
                            .lineLimit(1)
                    }
                    .tag(template.id)
                    .listRowSeparator(.hidden)
                }
                .onMove { store.settings.templates.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            Divider()
            HStack(spacing: 0) {
                Button(action: addTemplate) { Image(systemName: "plus").frame(width: 28, height: 24) }
                    .help("Add a template")
                Divider()
                Button(action: removeSelected) { Image(systemName: "minus").frame(width: 28, height: 24) }
                    .help("Remove the selected template")
                    .disabled(selection == nil)
                Divider()
                Spacer()
            }
            .frame(height: 24)
            .buttonStyle(.borderless)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
    }

    private func addTemplate() {
        let template = FileTemplate(title: "New Template", fileName: "Untitled.txt")
        store.settings.templates.append(template)
        selection = template.id
    }

    private func removeSelected() {
        store.settings.templates.removeAll { $0.id == selection }
        selection = nil
    }
}

private struct TemplateEditor: View {
    @Binding var template: FileTemplate

    var body: some View {
        Form {
            TextField("Menu title:", text: $template.title)
            TextField("File name:", text: $template.fileName)
            LabeledContent("Content:") {
                TextEditor(text: $template.content)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    // The field gives up height when the settings notice takes space at the top.
                    .frame(minHeight: 100, maxHeight: 172)
                    .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            }
            if let message = template.validationError {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.columns)
    }
}

// MARK: - General

struct GeneralTab: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var loginError: String?
    @AppStorage(HostPreferences.showMenuBarIconKey) private var showMenuBarIcon = true

    var body: some View {
        Form {
            SettingsNotice()
            Section {
                Toggle("Show in menu bar", isOn: $showMenuBarIcon)
            } footer: {
                Text("When the icon is hidden, open MacTweaks again from Applications or Spotlight to see Settings.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Launch MacTweaks at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard enabled != LoginItem.isEnabled else { return }
                        do {
                            try LoginItem.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).foregroundStyle(.red)
                }
            }
            Section {
                LabeledContent {
                    Button("Open Extension Settings…") {
                        FIFinderSyncController.showExtensionManagementInterface()
                    }
                } label: {
                    Text("Finder extension")
                    HStack(spacing: 6) {
                        Circle()
                            .fill(extensionEnabled ? .green : .red)
                            .frame(width: 7, height: 7)
                        Text(extensionEnabled ? "On" : "Off. The menu items do not appear in Finder.")
                    }
                }
            } footer: {
                Text("The Finder extension adds the MacTweaks items to the right-click menu.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
            launchAtLogin = LoginItem.isEnabled
        }
    }
}
