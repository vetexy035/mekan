import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = KeychainStore.get(AISettings.openAIKeyAccount) ?? ""
    @AppStorage(AISettings.modelDefaultsKey) private var model = AISettings.defaultModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("OpenAI")
                } footer: {
                    Text("Anahtar yalnızca bu cihazın Keychain'inde saklanır. Görsel başına OpenAI hesabından ücret alınır.")
                }
            }
            .navigationTitle("Ayarlar")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        KeychainStore.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                          for: AISettings.openAIKeyAccount)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
            }
        }
    }
}
