import AppKit
import SwiftUI

/// Notch alanı penceresi — DynamicNotchKit kanıtlanmış yaklaşımı
///
/// Kök neden: NSHostingView, pencere ekranın tam üst kenarına konumlandırıldığında
/// ve styleMask'ta .fullSizeContentView varken safeAreaInsets.top offset'i uygular.
///
/// Çözüm: Pencereyi ekranın yarısı kadar büyük yap, .fullSizeContentView kaldır.
/// Büyük pencere sayesinde NSHostingView safe area offset uygulamaz;
/// SwiftUI .alignment(.top) ile içerik pencerenin üstüne yapışır ve notch arkasına oturur.
final class NotchWindow {
  private var panel: NSPanel?
  private let screenDetector = ScreenDetector.shared

  /// Açık durumda notch içerik boyutu (görsel animasyon için referans)
  static let openSize = CGSize(width: 640, height: 210)
  /// Gölge için ekstra padding
  static let shadowPadding: CGFloat = 20

  /// Mevcut window level (çakışma yönetimi için ayarlanabilir)
  var windowLevel: NSWindow.Level = NSWindow.Level(
    rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2
  ) {
    didSet { panel?.level = windowLevel }
  }

  /// Pencereyi oluştur ve göster
  func setup<Content: View>(with content: Content) {
    guard let screen = screenDetector.builtinScreen else { return }

    // Pencere boyutu: ekranın yarısı kadar büyük
    // Bu sayede NSHostingView safe area offset UYGULAMAZ
    let panelWidth = screen.frame.width / 2
    let panelHeight = screen.frame.height / 2

    let newPanel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
      // .fullSizeContentView KASITLI OLARAK YOK — safe area tetikleyicisi
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )

    newPanel.isOpaque = false
    newPanel.backgroundColor = .clear
    newPanel.isMovable = false
    newPanel.level = windowLevel
    newPanel.hasShadow = false
    newPanel.isFloatingPanel = true
    newPanel.collectionBehavior = [
      .fullScreenAuxiliary,
      .stationary,
      .canJoinAllSpaces,
      .ignoresCycle,
    ]
    newPanel.titleVisibility = .hidden
    newPanel.titlebarAppearsTransparent = true

    // İçerik: pencerenin en üstüne yapıştır
    // Büyük pencere + .alignment(.top) kombinasyonu notch'u doğru konuma oturtur
    let wrappedContent = content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    newPanel.contentView = NSHostingView(rootView: wrappedContent)

    // Pencereyi ekranın üst kısmına konumlandır
    // Üst kenar = screen.frame.maxY (ekranın en üstü, notch seviyesi)
    let panelX = screen.frame.midX - panelWidth / 2
    let panelY = screen.frame.maxY - panelHeight
    newPanel.setFrame(
      NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
      display: false
    )

    newPanel.orderFrontRegardless()
    self.panel = newPanel
  }

  /// Pencereyi gizle
  func hide() {
    panel?.orderOut(nil)
  }

  /// Pencereyi göster
  func show() {
    panel?.orderFrontRegardless()
  }

  /// Window level'ı geçici olarak yükselt (bildirim modu)
  func temporarilyElevate(duration: TimeInterval = 5.0) {
    let originalLevel = windowLevel
    windowLevel = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 8
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
      self?.windowLevel = originalLevel
    }
  }
}
