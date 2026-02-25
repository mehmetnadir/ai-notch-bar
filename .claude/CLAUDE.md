# AI Notch Bar (ai-notch-bar)

## Proje Bilgileri
- **Repo:** github.com/nairadithya/ai-notch-bar (public)
- **Teknoloji:** Swift 5.9+, SwiftUI, macOS 13+
- **Lisans:** MIT
- **Build:** `swift build` / `swift run NotchHub`

## Dizin Yapısı

| Dizin | Açıklama |
|-------|----------|
| `NotchHub/App/` | @main entry, AppDelegate |
| `NotchHub/Core/` | NotchWindow, ScreenDetector, NotchHubManager, ConflictResolver |
| `NotchHub/Protocols/` | NotchProvider protokolü |
| `NotchHub/Providers/` | AI araç entegrasyonları (Claude, Copilot vb.) |
| `NotchHub/Views/` | SwiftUI view'ları (Dynamic Island tarzı) |
| `NotchHub/Audio/` | SoundManager |
| `NotchHubCLI/` | CLI aracı (ArgumentParser) |

## Kritik Dosyalar

- `NotchHub/Core/NotchHubManager.swift` — Provider orkestrasyon
- `NotchHub/Protocols/NotchProvider.swift` — Plugin protokolü
- `NotchHub/Core/NotchWindow.swift` — NSPanel pencere yönetimi
- `NotchHub/Core/LockFileWatcher.swift` — Dosya izleme (FSEvents)

## Provider Ekleme

1. `NotchHub/Providers/` altına yeni dosya
2. `NotchProvider` protokolünü uygula
3. `AppDelegate.swift`'te `manager.register()` ile kaydet

## Güvenlik Notları (Public Repo)

- `.env`, API key, credential ASLA commit'lenmez
- Lock dosya yolları kullanıcıya özel — hardcode etme
- Bundle ID'leri public bilgi, sorun yok

## Kazanılmış Savaşlar (DOKUNMA)

Aşağıdaki çözümler uzun debug süreçleriyle kanıtlanmıştır. Revert etme, "basitleştirme"
veya alternatif deneme. Bozarsan tekrar haftalar sürer.

### 1. NotchPanel — constrainFrameRect Override
**Dosya:** `NotchHub/Core/NotchWindow.swift`
**Sorun:** macOS `NSWindow.setFrame`/`setFrameOrigin` çağrılarını dahili olarak
`constrainFrameRect`'ten geçirir ve pencereyi ekranın üst ~33px'ine (notch safe area)
yerleştirmeyi engeller. Panel istenen konuma değil, 33px aşağıya oturur.
**Çözüm:** `NotchPanel: NSPanel` subclass'ı, `constrainFrameRect` override ederek
frame'i olduğu gibi döndürür. `NSPanel` yerine `NotchPanel` kullanılır.
**Kanıt:** Debug logları `panel.frame.maxY = 1084` vs `screen.frame.maxY = 1117` gösterdi.

### 2. SafeAreaFreeHostingView — NSHostingView Safe Area Sıfırlama
**Dosya:** `NotchHub/Core/NotchWindow.swift`
**Sorun:** NSHostingView, pencere ekranın üst kenarında yer aldığında macOS notch
safe area insets'ini (~32px) otomatik olarak SwiftUI view hierarchy'ye aktarır.
**Çözüm:** NSHostingView subclass'ı: `safeAreaRect`, `safeAreaInsets`,
`safeAreaLayoutGuide`, `additionalSafeAreaInsets` hepsi override edilir.
**Neden diğerleri başarısız:** `.ignoresSafeArea()`, `.fullSizeContentView`,
wrapper NSView, pencereyi büyütme — hiçbiri çalışmaz. Detaylar dosya başındaki
yorumda açıklanmıştır.

### 3. Mouse Tracking — acceptsMouseMovedEvents
**Dosya:** `NotchHub/Core/NotchWindow.swift`
**Sorun:** `nonactivatingPanel` stiliyle oluşturulan NSPanel varsayılan olarak
mouse event'lerini takip etmez. SwiftUI `.onHover` çalışmaz.
**Çözüm:** `acceptsMouseMovedEvents = true` + `ignoresMouseEvents = false`

### Özet: NotchWindow.swift'teki 3 Katman
```
NotchPanel (constrainFrameRect)     → Pencere konumu doğru
SafeAreaFreeHostingView (safe area) → İçerik konumu doğru
acceptsMouseMovedEvents             → Mouse etkileşimi çalışır
```
Bu üçünden biri eksik olursa notch ÇALIŞMAZ. Üçü birlikte tek çözümdür.

## Geliştirme Yol Haritası

### Görsel & Animasyon
- [ ] Notch şekilli mask (boring.notch tarzı gerçek notch silüeti)
- [ ] Spring animasyonları (açılma/kapanma geçişleri)
- [ ] Durum geçiş animasyonları (working → waitingInput renk geçişi)
- [ ] Glassmorphism/blur efektleri (vibrancy material)
- [ ] Progress bar (token kullanımı veya görev ilerlemesi)

### Yeni Provider'lar
- [ ] GitHub Copilot entegrasyonu
- [ ] Cursor AI entegrasyonu
- [ ] Windsurf/Codeium entegrasyonu
- [ ] Genel MCP sunucu izleme

### UX İyileştirmeleri
- [ ] Sürükle-bırak ile notch konumlandırma
- [ ] Klavye kısayolları (⌘+Shift+N ile toggle)
- [ ] Çoklu ekran desteği (her ekranda ayrı notch)
- [ ] Sağ tık bağlam menüsü (oturumu kapat, yeniden başlat)
- [ ] Oturum geçmişi (son 10 oturum log'u)

### Bildirim Sistemi
- [ ] macOS native bildirim entegrasyonu (UNUserNotificationCenter)
- [ ] Bildirim gruplama (aynı proje bildirimleri birleştir)
- [ ] Rahatsız etme modu (DND saatlerinde sessiz)
- [ ] Özelleştirilebilir ses temaları

### Sistem Entegrasyonları
- [ ] Menü bar ikonu (notch olmayan Mac'ler için fallback)
- [ ] Login item (açılışta otomatik başlat)
- [ ] Spotlight entegrasyonu (oturum arama)
- [ ] AppleScript/Shortcuts desteği

### Performans
- [ ] Metal hızlandırmalı render (karmaşık animasyonlar için)
- [ ] Batarya dostu mod (animasyonları azalt)
- [ ] Bellek optimizasyonu (uzun süreli çalışma)

## Changelog

- 2026-02-25: Ayarlar ekranı, click-through fix, .completed durum bildirimi, peek tetikleme.
- 2026-02-24: Proje başlatıldı. Faz 1 temel altyapı oluşturuldu.
- 2026-02-24: constrainFrameRect + SafeAreaFreeHostingView + mouse tracking fix.
