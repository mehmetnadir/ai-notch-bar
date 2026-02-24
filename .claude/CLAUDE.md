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

## Changelog

- 2026-02-24: Proje başlatıldı. Faz 1 temel altyapı oluşturuldu.
