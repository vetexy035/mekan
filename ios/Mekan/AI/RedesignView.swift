import SwiftUI
import MekanCore

struct RedesignView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss
    let scan: RoomScan

    init(scan: RoomScan) { self.scan = scan }

    @State private var style: DesignStyle = .japandi
    @State private var note = ""
    @State private var usePhoto = true
    @State private var working = false
    @State private var result: UIImage?
    @State private var errorText: String?
    @State private var showPrompt = false

    private var photo: UIImage? { store.photo(scan.id) }
    private var prompt: String { PromptBuilder.prompt(for: scan, style: style, note: note) }

    var body: some View {
        NavigationStack {
            Form {
                if let result {
                    Section("Sonuç") {
                        Image(uiImage: result).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Section("Stil") {
                    Picker("Stil", selection: $style) {
                        ForEach(DesignStyle.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Ek istek (ör. daha çok bitki, açık renk zemin)", text: $note, axis: .vertical)
                }

                Section {
                    if let photo {
                        Toggle("Oda fotoğrafını temel al", isOn: $usePhoto)
                        if usePhoto {
                            Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 180)
                        }
                    } else {
                        Text("Bu taramada fotoğraf yok; görsel yalnızca ölçülerden üretilecek.")
                            .foregroundStyle(.secondary)
                    }
                    DisclosureGroup("Gönderilecek açıklama", isExpanded: $showPrompt) {
                        Text(prompt).font(.footnote).textSelection(.enabled)
                    }
                }

                Section {
                    Button { Task { await generate() } } label: {
                        HStack {
                            Spacer()
                            if working { ProgressView().padding(.trailing, 6) }
                            Text(working ? "Üretiliyor… (1 dk sürebilir)" : "Tasarımı üret")
                            Spacer()
                        }
                    }
                    .disabled(working)
                } footer: {
                    Text("Sağlayıcı: \(AISettings.selected.displayName) · \(AISettings.model(AISettings.selected))")
                }
            }
            .navigationTitle("AI tasarım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }
            .alert("Üretilemedi", isPresented: .constant(errorText != nil)) {
                Button("Tamam") { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }

    private func generate() async {
        working = true
        defer { working = false }
        let jpeg = usePhoto ? photo.flatMap { downscaled($0).jpegData(compressionQuality: 0.85) } : nil
        do {
            let png = try await AISettings.provider().redesign(RedesignRequest(prompt: prompt, photoJPEG: jpeg))
            _ = try store.addRender(png, to: scan.id, style: style)
            result = UIImage(data: png)
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Keeps uploads small (long edge ≤ 1536 px).
    private func downscaled(_ image: UIImage) -> UIImage {
        let maxEdge: CGFloat = 1536
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image }
        let s = maxEdge / longest
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
