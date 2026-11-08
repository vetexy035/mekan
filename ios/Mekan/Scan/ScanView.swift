import SwiftUI
import RoomPlan
import MekanCore

private struct RoomCaptureRepresentable: UIViewRepresentable {
    let scanner: RoomScanner
    func makeUIView(context: Context) -> RoomCaptureView { scanner.captureView }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

/// Full-screen LiDAR scan. On success saves the scan and hands back its id.
struct ScanView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = RoomScanner()
    @State private var name = ""
    @State private var askName = false
    @State private var saveError: String?

    var onSaved: (UUID) -> Void

    init(onSaved: @escaping (UUID) -> Void) { self.onSaved = onSaved }

    var body: some View {
        ZStack {
            RoomCaptureRepresentable(scanner: scanner).ignoresSafeArea()

            VStack {
                HStack {
                    Button("İptal") { scanner.cancel(); dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()

                if let text = scanner.instruction, scanner.state == .scanning {
                    Text(text)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()
                bottomBar.padding(.bottom, 32)
            }
        }
        .overlay {
            if scanner.state == .idle { tipsCard }
        }
        .onChange(of: scanner.state) { _, new in
            guard new == .finished else { return }
            // Suggest a name from the detected room type ("Salon", "Yatak odası"…).
            if name.isEmpty, let room = scanner.result?.room,
               let suggested = RoomTypeNames.turkish(RoomScanConverter.roomType(of: room)) {
                name = suggested
            }
            askName = true
        }
        .alert("Odaya bir ad ver", isPresented: $askName) {
            TextField("Ör. Salon", text: $name)
            Button("Kaydet") { save() }
        }
        .alert("Kaydedilemedi", isPresented: .constant(saveError != nil)) {
            Button("Tamam") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    /// Shown before the camera starts: the most common causes of bad scans.
    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("İyi bir tarama için").font(.title3.bold())
            tip("lightbulb.fill", "Işıkları aç, perdeleri arala.")
            tip("figure.stand", "Odanın ortasından başla, telefonu göğüs hizasında tut.")
            tip("tortoise.fill", "Yavaşça dön; hızlı hareket en sık hata nedeni.")
            tip("square.split.bottomrightquarter", "Köşeleri, tavan-duvar birleşimini ve kapıların tamamını göster.")
            tip("camera.viewfinder", "Bitirmeden önce AI'ya göndermek istediğin açıya dön.")
            Button { scanner.start() } label: {
                Text("Taramaya başla").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        Label { Text(text).font(.subheadline) } icon: { Image(systemName: icon).foregroundStyle(.tint) }
    }

    @ViewBuilder private var bottomBar: some View {
        switch scanner.state {
        case .scanning:
            Button { scanner.finish() } label: {
                Label("Taramayı bitir", systemImage: "checkmark.circle.fill")
                    .font(.headline).padding(.horizontal, 24).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        case .processing:
            ProgressView("Oda modeli hazırlanıyor…")
                .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).multilineTextAlignment(.center)
                Button("Tekrar dene") { scanner.start() }.buttonStyle(.borderedProminent)
            }
            .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .idle, .finished:
            EmptyView()
        }
    }

    private func save() {
        guard let result = scanner.result else { return }
        let title = name.trimmingCharacters(in: .whitespaces)
        do {
            let id = try store.save(room: result.room, photo: result.photo,
                                    name: title.isEmpty ? "Oda" : title)
            onSaved(id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
