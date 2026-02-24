import AppKit

/// Ses efektleri yöneticisi
final class SoundManager {
  static let shared = SoundManager()

  /// Sistem sesi çal
  func playSystemSound(_ name: String) {
    NSSound(named: NSSound.Name(name))?.play()
  }

  /// Bildirim sesi (Claude input bekliyor)
  func playNotification() {
    playSystemSound("Glass")
  }

  /// Başarı sesi
  func playSuccess() {
    playSystemSound("Hero")
  }

  /// Hata sesi
  func playError() {
    playSystemSound("Basso")
  }

  /// Hafif dikkat çekme sesi
  func playSubtle() {
    playSystemSound("Tink")
  }
}
