import AppKit
import SwiftUI

/// Notch alanı üzerinde şeffaf pencere yöneten sınıf
final class NotchWindow {
  private var panel: NSPanel?
  private let screenDetector = ScreenDetector.shared

  /// Mevcut window level (çakışma yönetimi için ayarlanabilir)
  var windowLevel: NSWindow.Level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2) {
    didSet { panel?.level = windowLevel }
  }

  /// Pencereyi oluştur ve göster
  func setup<Content: View>(with content: Content) {
    guard let screen = screenDetector.builtinScreen else { return }

    let notchHeight = screen.safeAreaInsets.top
    let expandedWidth: CGFloat = 400
    let expandedHeight: CGFloat = max(notchHeight + 20, 50)

    let contentRect = NSRect(
      x: screen.frame.midX - (expandedWidth / 2),
      y: screen.frame.maxY - expandedHeight,
      width: expandedWidth,
      height: expandedHeight
    )

    let newPanel = NSPanel(
      contentRect: contentRect,
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
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
      .ignoresCycle
    ]
    newPanel.titleVisibility = .hidden
    newPanel.titlebarAppearsTransparent = true

    let hostingView = NSHostingView(rootView: content)
    hostingView.frame = newPanel.contentView?.bounds ?? .zero
    hostingView.autoresizingMask = [.width, .height]
    newPanel.contentView?.addSubview(hostingView)

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

  /// Pencere boyutunu güncelle (genişleme/küçülme animasyonu için)
  func updateSize(width: CGFloat, height: CGFloat, animated: Bool = true) {
    guard let panel = panel,
          let screen = screenDetector.builtinScreen
    else { return }

    let newFrame = NSRect(
      x: screen.frame.midX - (width / 2),
      y: screen.frame.maxY - height,
      width: width,
      height: height
    )

    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panel.animator().setFrame(newFrame, display: true)
      }
    } else {
      panel.setFrame(newFrame, display: true)
    }
  }

  /// Window level'ı geçici olarak yükselt (bildirim modu)
  func temporarilyElevate(duration: TimeInterval = 5.0) {
    let originalLevel = windowLevel
    windowLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 8)
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
      self?.windowLevel = originalLevel
    }
  }
}
