import SwiftUI

/// Uygulama ayarları — UserDefaults ile kalıcı
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  /// Çerçeve rengi (hex string olarak kaydedilir)
  @AppStorage("borderColorHex") private var borderColorHex: String = "#FFFFFF"

  /// Çerçeve opaklığı (0.0–1.0)
  @AppStorage("borderOpacity") var borderOpacity: Double = 0.15

  /// Çerçeve kalınlığı
  @AppStorage("borderWidth") var borderWidth: Double = 0.8

  /// Genişletilmiş mod genişliği (ekran yüzdesi olarak, 0.3–0.8)
  @AppStorage("expandedWidthRatio") var expandedWidthRatio: Double = 0.55

  /// Ses bildirimleri aktif mi
  @AppStorage("soundEnabled") var soundEnabled: Bool = true

  /// Çerçeve rengi (SwiftUI Color)
  var borderColor: Color {
    get { Color(hex: borderColorHex) ?? .white }
    set {
      if let hex = newValue.toHex() {
        borderColorHex = hex
      }
    }
  }

  /// Önceden tanımlı çerçeve renkleri
  static let presetColors: [(String, Color)] = [
    ("Beyaz", .white),
    ("Mavi", .cyan),
    ("Mor", .purple),
    ("Yeşil", .green),
    ("Turuncu", .orange),
    ("Kırmızı", .red),
    ("Pembe", .pink),
  ]
}

// MARK: - Color ↔ Hex

extension Color {
  init?(hex: String) {
    var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    h = h.replacingOccurrences(of: "#", with: "")
    guard h.count == 6,
          let rgb = UInt64(h, radix: 16)
    else { return nil }
    self.init(
      red: Double((rgb >> 16) & 0xFF) / 255,
      green: Double((rgb >> 8) & 0xFF) / 255,
      blue: Double(rgb & 0xFF) / 255
    )
  }

  func toHex() -> String? {
    guard let c = NSColor(self).usingColorSpace(.deviceRGB) else {
      return nil
    }
    let r = Int(c.redComponent * 255)
    let g = Int(c.greenComponent * 255)
    let b = Int(c.blueComponent * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}
