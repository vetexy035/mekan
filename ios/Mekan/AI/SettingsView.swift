import SwiftUI
import UIKit
import MekanCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var provider = AISettings.selected
    @State private var keys: [AIProviderKind: String] =
        Dictionary(uniqueKeysWithValues: AIProviderKind.allCases.map { ($0, AISettings.apiKey($0)) })
    @State private var models: [AIProviderKind: String] =
        Dictionary(uniqueKeysWithValues: AIProviderKind.allCases.map { ($0, AISettings.model($0)) })
    @State private var notice: String?
    /// Set when the user went to a key page, so we only peek at the clipboard on return.
    @State private var waitingForKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sağlayıcı", selection: $provider) {
                        ForEach(AIProviderKind.allCases) { Text($0.displayName).tag($0) }
                    }
                } footer: {
                    Text(provider == .pollinations
                         ? "Ücretsiz hesapla gelen bakiyeyle test için. Kota dolarsa uygulama uyarır."
                         : "Görsel başına OpenAI hesabından ücret alınır.")
                }

                Section {
                    Button {
                        waitingForKey = true
                        openURL(provider.keyPageURL)
                    } label: {
                        Label("\(provider == .pollinations ? "Ücretsiz anahtar al" : "Anahtar al")", systemImage: "key")
                    }
                    SecureField(provider == .pollinations ? "sk_…" : "sk-…", text: keyBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PasteButton(payloadType: String.self) { strings in
                        if let s = strings.first { accept(s, explicit: true) }
                    }
                    TextField("Model", text: modelBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if models[provider] != provider.defaultModel {
                        Button("Önerilen modele dön (\(provider.defaultModel))") { models[provider] = provider.defaultModel }
                            .font(.footnote)
                    }
                } header: {
                    Text(provider.displayName)
                } footer: {
                    Text("Anahtarı kopyalayıp buraya döndüğünde Mekan onu kendisi tanır. Anahtar yalnızca bu cihazın Keychain'inde saklanır.")
                }

                if let notice {
                    Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(.green) }
                }
            }
            .navigationTitle("Ayarlar")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save(); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
            }
            .onChange(of: scenePhase) { _, phase in
                // Back from the browser: pick up a freshly copied key automatically.
                guard phase == .active, waitingForKey, UIPasteboard.general.hasStrings else { return }
                waitingForKey = false
                if let s = UIPasteboard.general.string { accept(s, explicit: false) }
            }
        }
    }

    /// Key / model field of the currently selected provider.
    private var keyBinding: Binding<String> {
        Binding(get: { keys[provider] ?? "" }, set: { keys[provider] = $0 })
    }
    private var modelBinding: Binding<String> {
        Binding(get: { models[provider] ?? "" }, set: { models[provider] = $0 })
    }

    /// Stores a copied key under the service it belongs to and switches to it.
    private func accept(_ text: String, explicit: Bool) {
        guard let kind = AIProviderKind.detect(key: text) else {
            if explicit { notice = nil; keys[provider] = text.trimmingCharacters(in: .whitespacesAndNewlines) }
            return
        }
        keys[kind] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        provider = kind
        AISettings.setAPIKey(keys[kind]!, for: kind)
        AISettings.selected = kind
        notice = "\(kind.displayName) anahtarı tanındı ve kaydedildi."
    }

    private func save() {
        AISettings.selected = provider
        for p in AIProviderKind.allCases {
            AISettings.setAPIKey(keys[p] ?? "", for: p)
            AISettings.setModel(models[p] ?? p.defaultModel, for: p)
        }
    }
}
