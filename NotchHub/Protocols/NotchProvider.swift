import SwiftUI

/// Provider öncelik seviyeleri
enum ProviderPriority: Int, Comparable {
  case critical = 100   // Claude input bekliyor
  case high = 75        // Bildirim
  case normal = 50      // Müzik çalıyor
  case low = 25         // Pasif bilgi

  static func < (lhs: ProviderPriority, rhs: ProviderPriority) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// Provider durumu
enum ProviderState: Equatable {
  case inactive           // Provider pasif
  case active             // Provider aktif (normal)
  case attention          // Dikkat gerekiyor (ör: Claude input bekliyor)
}

/// Her entegrasyon (Claude, Müzik, vb.) bu protokolü uygular
protocol NotchProvider: ObservableObject {
  /// Benzersiz tanımlayıcı
  var id: String { get }
  /// Gösterim adı
  var name: String { get }
  /// Mevcut öncelik
  var priority: ProviderPriority { get }
  /// Provider aktif mi?
  var state: ProviderState { get }

  /// Küçük görünüm (notch içinde kompakt)
  @ViewBuilder func compactView() -> AnyView
  /// Genişletilmiş görünüm (hover/tıklama ile)
  @ViewBuilder func expandedView() -> AnyView

  /// Notch solunda görünen küçük ikon (kapalı durumda)
  @ViewBuilder func compactLeadingView() -> AnyView
  /// Notch sağında görünen küçük ikon (kapalı durumda)
  @ViewBuilder func compactTrailingView() -> AnyView

  /// Tıklama aksiyonu
  func onActivate()
  /// Provider'ı başlat
  func start()
  /// Provider'ı durdur
  func stop()
}
