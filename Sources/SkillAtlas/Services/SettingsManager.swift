import Foundation

actor SettingsManager {
    private let settingsURL: URL

    init(settingsURL: URL) {
        self.settingsURL = settingsURL
    }

    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(settings)
        try AtomicFileWriter.write(data: data, to: settingsURL)
    }

    func reset() throws {
        try save(.default)
    }
}
