# Mekan

iPhone LiDAR ile oda tarama → ölçüler, 2D plan, 3D model → AI ile yeniden tasarım.

- **Mimari:** [docs/architecture.md](docs/architecture.md)
- **Windows'tan iPhone'a kurulum:** [docs/kurulum.md](docs/kurulum.md)

| Klasör | İçerik |
|---|---|
| `ios/MekanCore` | Platformdan bağımsız Swift paketi: tarama şeması, ölçü hesapları, AI prompt'u (+ testler) |
| `ios/Mekan` | SwiftUI uygulaması: RoomPlan tarama, kayıt, plan/3D, AI tasarım |
| `ios/project.yml` | XcodeGen tanımı; `.xcodeproj` CI'da üretilir |
| `.github/workflows/ios.yml` | Testler + imzasız `.ipa` |
| `web/` | Beklemede: ileride AI proxy / paylaşım sitesi |
