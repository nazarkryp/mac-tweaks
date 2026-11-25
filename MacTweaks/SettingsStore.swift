import Foundation
import Observation

/// The settings that the Settings window edits. Each change is saved to the App Group,
/// where the Finder extension reads it the next time it builds the menu.
@Observable
final class SettingsStore {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    /// Set when the saved settings cannot be read. Saving stays off until the user resets them,
    /// so the app does not replace the user's data without asking.
    private(set) var loadError: String?
    private(set) var saveError: String?

    init() {
        do {
            settings = try SharedStore.loadSettings()
        } catch {
            settings = AppSettings()
            loadError = error.localizedDescription
        }
    }

    func resetToDefaults() {
        loadError = nil
        settings = AppSettings()
        persist()
    }

    private func persist() {
        guard loadError == nil else { return }
        do {
            try SharedStore.save(settings)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}
