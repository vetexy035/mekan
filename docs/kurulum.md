# Windows'tan iPhone'a ücretsiz kurulum

Mac gerekmez. Uygulama GitHub'ın macOS sunucusunda derlenir, Windows'ta
Sideloadly ile senin Apple ID'nle imzalanıp telefona yüklenir.

## Bir kerelik hazırlık

1. **GitHub reposu:** github.com → New repository → ad: `mekan` → **Public**
   (public repoda macOS derleme dakikaları ücretsiz). README ekleme.
2. **Kodu gönder** (bu klasörde):
   ```bash
   git init -b main
   git add .
   git commit -m "Mekan: ilk iskelet"
   git remote add origin https://github.com/<kullanıcı-adın>/mekan.git
   git push -u origin main
   ```
3. **iTunes + iCloud (Microsoft Store değil, Apple sitesindeki sürüm)** kur.
   Sideloadly telefonla bunlar üzerinden konuşur.
4. **Sideloadly** kur: sideloadly.io
5. iPhone'da **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu → Aç**
   (iOS 16+; telefon yeniden başlar).

## Her derlemede

1. GitHub'da repo → **Actions** → en son "iOS" çalışması yeşil olunca aç →
   altta **Mekan-ipa** dosyasını indir, zip'ten `Mekan.ipa`'yı çıkar.
   (Elle tetiklemek için: Actions → iOS → *Run workflow*.)
2. iPhone'u USB ile bağla, "Bu bilgisayara güven" de.
3. Sideloadly → IPA olarak `Mekan.ipa` → Apple ID'ni yaz → **Start**.
   İlk seferde Apple ID şifresini Sideloadly ister; mümkünse bu iş için ayrı
   bir Apple ID kullan.
4. iPhone: **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Apple ID'ne güven.
5. Mekan'ı aç → kamera iznini ver → **Yeni tarama**.

## Bilmen gerekenler

- Ücretsiz imza **7 gün** geçerli. Süre dolunca uygulama açılmaz; Sideloadly ile
  aynı IPA'yı tekrar yükle (veriler kalır). Sideloadly'nin otomatik yenileme
  seçeneği bilgisayar açıkken bunu kendisi yapabilir.
- Aynı anda en fazla 3 sideload uygulaması.
- AI tasarım için Ayarlar (dişli) → OpenAI API anahtarı. Görsel başına OpenAI
  hesabından ücret kesilir; bu kısım ücretsiz değildir.
- Tarama için LiDAR'lı cihaz gerekir (iPhone 12 Pro / Pro Max ve sonraki Pro
  modeller). Diğer iPhone'larda uygulama açılır ama tarama düğmesi yerine uyarı
  görünür.

## İyi tarama için

- Işıklar açık olsun, odanın ortasından başla.
- Telefonu göğüs hizasında tut, yavaşça dön; köşeleri ve tavan-duvar birleşimini
  göster.
- Kapı ve pencerelerin tamamı kadraja girsin.
- Bitirmeden önce son bakış açısını AI'ya göndermek istediğin açıya getir: oda
  fotoğrafı taramanın son karesinden alınır.
