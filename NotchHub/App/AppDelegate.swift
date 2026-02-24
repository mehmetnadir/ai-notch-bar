import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  var manager: NotchHubManager?
  private var claudeProvider: ClaudeProvider?
  private var notchWindow: NotchWindow?
  private let conflictResolver = ConflictResolver.shared

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Dock ikonu gösterme
    NSApp.setActivationPolicy(.accessory)

    // Çakışma taraması başlat
    conflictResolver.start()

    // Provider'ları oluştur
    let claude = ClaudeProvider()
    self.claudeProvider = claude
    let manager = NotchHubManager()
    manager.claudeProvider = claude
    manager.register(AnyNotchProvider(claude))
    self.manager = manager

    // Notch penceresi oluştur
    let window = NotchWindow()
    window.windowLevel = conflictResolver.recommendedWindowLevel
    let contentView = NotchView(manager: manager)
    window.setup(with: contentView)
    self.notchWindow = window

    // CLI bildirimlerini dinle
    listenForCLINotifications()

    // Manager'ı başlat
    manager.start()
  }

  /// DistributedNotificationCenter üzerinden CLI bildirimlerini dinle
  private func listenForCLINotifications() {
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(handleCLINotification(_:)),
      name: Notification.Name("com.ai-notch-bar.notification"),
      object: nil
    )
  }

  @objc private func handleCLINotification(_ notification: Notification) {
    guard let jsonString = notification.object as? String,
          let data = jsonString.data(using: .utf8),
          let payload = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any],
          let type = payload["type"] as? String
    else { return }

    switch type {
    case "waiting-input":
      let sessionId = payload["sessionId"] as? String
      claudeProvider?.notifyWaitingInput(sessionId: sessionId)
    default:
      break
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    manager?.stop()
    conflictResolver.stop()
  }
}
