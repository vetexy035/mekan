import SwiftUI
import RoomPlan

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
        .onAppear { scanner.start() }
        .onChange(of: scanner.state) { _, new in
            if new == .finished { askName = true }
        }
        .alert("Odaya bir ad ver", isPresented: $askName) {
            TextField("Ör. Salon", text: $name)
            Button("Kaydet") { save() }
        }
        .alert("Kaydedilemedi", isPresented: .constant(saveError != nil)) {
            Button("Tamam") { saveError = nil }
        } message: { Text(saveError ?? "") }
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
