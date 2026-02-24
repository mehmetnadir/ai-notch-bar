import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  var manager: NotchHubManager?
  private var notchWindow: NotchWindow?
  private let conflictResolver = ConflictResolver.shared

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Dock ikonu gösterme
    NSApp.setActivationPolicy(.accessory)

    // Çakışma taraması başlat
    conflictResolver.start()

    // Provider'ları oluştur
    let claude = ClaudeProvider()
    let manager = NotchHubManager()
    manager.register(AnyNotchProvider(claude))
    self.manager = manager

    // Notch penceresi oluştur
    let window = NotchWindow()
    window.windowLevel = conflictResolver.recommendedWindowLevel
    let contentView = NotchView(manager: manager)
    window.setup(with: contentView)
    self.notchWindow = window

    // Manager'ı başlat
    manager.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    manager?.stop()
    conflictResolver.stop()
  }
}
