import ArgumentParser
import Foundation

@main
struct NotchHubCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "notchhub",
    abstract: "AI Notch Bar — CLI bildirim aracı",
    version: "0.1.0",
    subcommands: [Notify.self, WaitingInput.self]
  )
}

/// Genel bildirim gönder
struct Notify: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Özel bildirim gönder"
  )

  @Option(name: .long, help: "Bildirim başlığı")
  var title: String

  @Option(name: .long, help: "Bildirim mesajı")
  var message: String

  @Option(name: .long, help: "Ses efekti (default, success, error, none)")
  var sound: String = "default"

  @Option(name: .long, help: "Gösterim süresi (saniye)")
  var duration: Double = 3.0

  func run() throws {
    let payload: [String: Any] = [
      "type": "notification",
      "title": title,
      "message": message,
      "sound": sound,
      "duration": duration,
    ]

    try sendToApp(payload)
    print("Bildirim gönderildi: \(title)")
  }
}

/// Claude Code input bekleme bildirimi
struct WaitingInput: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "waiting-input",
    abstract: "AI aracı yanıt bekliyor bildirimi"
  )

  @Option(name: .long, help: "Oturum ID (port numarası)")
  var sessionId: String?

  @Option(name: .long, help: "AI aracı adı (claude, copilot, vb.)")
  var tool: String = "claude"

  func run() throws {
    let payload: [String: Any] = [
      "type": "waiting-input",
      "tool": tool,
      "sessionId": sessionId as Any,
    ]

    try sendToApp(payload)
    print("Yanıt bekleniyor bildirimi gönderildi (\(tool))")
  }
}

// MARK: - IPC

private func sendToApp(_ payload: [String: Any]) throws {
  let data = try JSONSerialization.data(withJSONObject: payload)
  guard let jsonString = String(data: data, encoding: .utf8) else {
    throw ValidationError("JSON oluşturulamadı")
  }

  DistributedNotificationCenter.default().post(
    name: Notification.Name("com.ai-notch-bar.notification"),
    object: jsonString
  )
}
