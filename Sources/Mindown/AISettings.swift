import Foundation
import SwiftUI

/// Persisted configuration for the OpenAI-compatible AI sidebar.
final class AISettings: ObservableObject {
    static let shared = AISettings()

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }
    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Keys.baseURL) }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }
    @Published var sidebarVisible: Bool {
        didSet { UserDefaults.standard.set(sidebarVisible, forKey: Keys.sidebar) }
    }

    private enum Keys {
        static let apiKey = "ai.apiKey"
        static let baseURL = "ai.baseURL"
        static let model = "ai.model"
        static let sidebar = "ai.sidebarVisible"
    }

    private init() {
        let d = UserDefaults.standard
        self.apiKey  = d.string(forKey: Keys.apiKey)  ?? ""
        self.baseURL = d.string(forKey: Keys.baseURL) ?? "https://api.openai.com/v1"
        self.model   = d.string(forKey: Keys.model)   ?? "gpt-4o-mini"
        self.sidebarVisible = d.object(forKey: Keys.sidebar) as? Bool ?? true
    }

    var isConfigured: Bool { !apiKey.isEmpty && !baseURL.isEmpty && !model.isEmpty }
}
