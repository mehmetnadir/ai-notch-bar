import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  var manager: NotchHubManager?
  private var notchWindow: NotchWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Dock ikonu gösterme
    NSApp.setActivationPolicy(.accessory)

    let manager = NotchHubManager()
    self.manager = manager

    // Notch penceresi oluştur
    let window = NotchWindow()
    let contentView = NotchView(manager: manager)
    window.setup(with: contentView)
    self.notchWindow = window

    // Manager'ı başlat
    manager.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    manager?.stop()
  }
}
