import SwiftUI
import RoomPlan
import MekanCore

private struct HomeCaptureRepresentable: UIViewRepresentable {
    let scanner: RoomScanner
    func makeUIView(context: Context) -> RoomCaptureView { scanner.captureView }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

/// Scans several rooms in one AR session (so they line up), then merges them into a home plan.
struct HomeScanView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = RoomScanner(multiRoom: true)
    @State private var askName = false
    @State private var homeName = "Evim"
    @State private var merging = false
    @State private var errorText: String?

    var onSaved: (UUID) -> Void
    init(onSaved: @escaping (UUID) -> Void) { self.onSaved = onSaved }

    var body: some View {
        ZStack {
            HomeCaptureRepresentable(scanner: scanner).ignoresSafeArea()

            VStack {
                HStack {
                    Button("İptal") { scanner.cancel(); scanner.endSession(); dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    if !scanner.rooms.isEmpty {
                        Text("\(scanner.rooms.count) oda tarandı")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding()

                if let text = scanner.instruction, scanner.state == .scanning {
                    Text(text)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                bottom.padding(.bottom, 32)
            }
        }
        .alert("Ev planına bir ad ver", isPresented: $askName) {
            TextField("Ör. Evim", text: $homeName)
            Button("Birleştir ve kaydet") { Task { await finishHome() } }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("Kaydedilemedi", isPresented: .constant(errorText != nil)) {
            Button("Tamam") { errorText = nil }
        } message: { Text(errorText ?? "") }
    }

    @ViewBuilder private var bottom: some View {
        if merging {
            card { ProgressView("Odalar birleştiriliyor…") }
        } else {
            switch scanner.state {
            case .idle:
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ev planı taraması").font(.title3.bold())
                        Text("Odaları arka arkaya tara. Bir oda bitince kamerayı kapatmadan diğer odaya yürü; böylece odalar planda doğru yerine oturur.")
                            .font(.subheadline)
                        Text("Odalar arasında geçerken kapı aralığını ve koridoru da göster.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button { scanner.start() } label: {
                            Text("İlk odayı taramaya başla").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            case .scanning:
                Button { scanner.finish() } label: {
                    Label("Bu odayı bitir", systemImage: "checkmark.circle.fill")
                        .font(.headline).padding(.horizontal, 24).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            case .processing:
                card { ProgressView("Oda hazırlanıyor…") }
            case .finished:
                card {
                    VStack(spacing: 12) {
                        Text("\(scanner.rooms.count). oda tamam").font(.headline)
                        Button { scanner.start() } label: {
                            Label("Sonraki odaya geç", systemImage: "arrow.right.circle.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button { askName = true } label: {
                            Label("Ev planını bitir", systemImage: "house.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            case .failed(let message):
                card {
                    VStack(spacing: 12) {
                        Text(message).multilineTextAlignment(.center)
                        Button("Bu odayı tekrar tara") { scanner.start() }.buttonStyle(.borderedProminent)
                        if !scanner.rooms.isEmpty {
                            Button("Taranan odalarla bitir") { askName = true }.buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)
    }

    private func finishHome() async {
        merging = true
        scanner.endSession()
        defer { merging = false }
        do {
            let name = homeName.trimmingCharacters(in: .whitespaces)
            let id = try await store.saveHome(name: name.isEmpty ? "Evim" : name, rooms: scanner.rooms)
            onSaved(id)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
