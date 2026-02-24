import ArgumentParser
import Foundation

@main
struct NotchHubCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "notchhub",
    abstract: "AI Notch Bar — CLI bildirim aracı",
    version: "0.1.0"
  )

  @Option(name: .long, help: "Bildirim başlığı")
  var title: String

  @Option(name: .long, help: "Bildirim mesajı")
  var message: String

  @Option(name: .long, help: "Ses efekti (default, success, error, none)")
  var sound: String = "default"

  @Option(name: .long, help: "Kaynak uygulama bundle ID")
  var bundleId: String?

  @Option(name: .long, help: "Gösterim süresi (saniye)")
  var duration: Double = 3.0

  func run() throws {
    let payload: [String: Any] = [
      "title": title,
      "message": message,
      "sound": sound,
      "bundleId": bundleId as Any,
      "duration": duration,
    ]

    // DistributedNotificationCenter ile uygulamaya gönder
    let data = try JSONSerialization.data(withJSONObject: payload)
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw ValidationError("JSON oluşturulamadı")
    }

    DistributedNotificationCenter.default().post(
      name: Notification.Name("com.ai-notch-bar.notification"),
      object: jsonString
    )

    print("Bildirim gönderildi: \(title)")
  }
}
