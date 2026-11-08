import SwiftUI
import MekanCore

/// Fix the scan by hand: type in measured wall lengths and ceiling height, drag,
/// rotate or delete furniture, delete wrongly detected doors/windows.
struct PlanEditorView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var scan: RoomScan
    @State private var selectedObject: String?
    @State private var selectedWall: String?
    @State private var wallInput = ""
    @State private var ceilingInput = ""
    @State private var dragStart: Point2?
    @State private var saveError: String?

    init(scan: RoomScan) {
        _scan = State(initialValue: scan)
        _ceilingInput = State(initialValue: String(Int((RoomMeasurements(scan: scan).ceilingHeight * 100).rounded())))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let transform = PlanTransform(scan: scan, size: geo.size, pad: PlanTransform.pad(showLabels: true))
                    FloorPlanView(scan: scan, selectedObjectId: selectedObject, selectedWallId: selectedWall)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { g in drag(g, transform) }
                            .onEnded { g in endDrag(g, transform) })
                }
                .frame(maxHeight: .infinity)
                .padding(8)

                controls
                    .padding()
                    .background(.regularMaterial)
            }
            .navigationTitle("Planı düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.bold() }
                if store.hasOriginal(scan.id) {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Taramanın aslına dön", role: .destructive) {
                            if let original = store.original(scan.id) { scan = original; clearSelection() }
                        }
                    }
                }
            }
            .alert("Kaydedilemedi", isPresented: .constant(saveError != nil)) {
                Button("Tamam") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        if let id = selectedObject, let obj = scan.objects.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 10) {
                Text(obj.turkishName).font(.headline)
                Text("Taşımak için planda sürükle.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { scan = RoomEditing.rotate(objectId: id, byDegrees: 90, in: scan) } label: {
                        Label("90° döndür", systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        scan = RoomEditing.deleteObject(id, in: scan); clearSelection()
                    } label: { Label("Sil", systemImage: "trash") }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Bitti") { clearSelection() }
                }
            }
        } else if let id = selectedWall, let wall = scan.walls.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Duvar: şu an \(cm(wall.length))").font(.headline)
                HStack {
                    TextField("Ölçtüğün uzunluk", text: $wallInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Text("cm")
                    Button("Uygula") {
                        if let v = Double(wallInput.replacingOccurrences(of: ",", with: ".")), v > 1 {
                            scan = RoomEditing.setLength(of: id, to: v / 100, in: scan)
                            clearSelection()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                let openings = scan.openings.filter { $0.wallId == id }
                if !openings.isEmpty {
                    ForEach(openings) { op in
                        HStack {
                            Text("\(op.kind == .window ? "Pencere" : "Kapı") \(cm(op.width))").font(.subheadline)
                            Spacer()
                            Button("Sil", role: .destructive) { scan = RoomEditing.deleteOpening(op.id, in: scan) }
                                .font(.subheadline)
                        }
                    }
                }
                Text("Oda bu duvar yönünde orantılı uzar veya kısalır.").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bir duvara ya da eşyaya dokun.").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Text("Tavan yüksekliği")
                    Spacer()
                    TextField("cm", text: $ceilingInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("cm")
                    Button("Uygula") {
                        if let v = Double(ceilingInput), v > 100 { scan = RoomEditing.setCeilingHeight(v / 100, in: scan) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: Gestures

    /// Dragging that starts on a piece of furniture moves it (and selects it).
    private func drag(_ g: DragGesture.Value, _ t: PlanTransform?) {
        guard let t else { return }
        let start = t.world(g.startLocation)
        if dragStart == nil {
            dragStart = start
            if let obj = RoomEditing.object(at: start, in: scan) {
                dragTarget = obj.id
                dragOrigin = Point2(x: obj.center.x, z: obj.center.z)
            }
        }
        guard let id = dragTarget, let origin = dragOrigin,
              hypot(g.translation.width, g.translation.height) > 6 else { return }
        selectedObject = id; selectedWall = nil
        let now = t.world(g.location)
        scan = RoomEditing.move(objectId: id, to: Point2(x: origin.x + now.x - start.x, z: origin.z + now.z - start.z), in: scan)
    }

    @State private var dragTarget: String?
    @State private var dragOrigin: Point2?

    private func endDrag(_ g: DragGesture.Value, _ t: PlanTransform?) {
        defer { dragStart = nil; dragTarget = nil; dragOrigin = nil }
        guard let t else { return }
        let moved = hypot(g.translation.width, g.translation.height) > 6
        guard !moved else { return }
        // A tap: select furniture first (it sits inside the room), then walls.
        let p = t.world(g.location)
        if let obj = RoomEditing.object(at: p, in: scan) {
            selectedObject = obj.id; selectedWall = nil
        } else if let wall = RoomEditing.wall(near: p, in: scan, tolerance: 24 / t.scale) {
            selectedWall = wall.id; selectedObject = nil
            wallInput = String(Int((wall.length * 100).rounded()))
        } else {
            clearSelection()
        }
    }

    private func clearSelection() { selectedObject = nil; selectedWall = nil }

    private func save() {
        do {
            try store.update(scan)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func cm(_ m: Double) -> String { "\(Int((m * 100).rounded())) cm" }
}
