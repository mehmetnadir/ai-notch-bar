import AppKit
import Combine

/// Bilinen notch alan uygulamaları
struct KnownNotchApp {
  let name: String
  let bundleId: String
  let windowLevel: Int  // Bilinen window level

  static let all: [KnownNotchApp] = [
    KnownNotchApp(
      name: "boring.notch",
      bundleId: "com.theboredteam.boring.notch",
      windowLevel: 27  // .mainMenu + 3
    ),
    KnownNotchApp(
      name: "NotchDrop",
      bundleId: "net.loserly.notchdrop",
      windowLevel: 33  // .statusBar + 8
    ),
    KnownNotchApp(
      name: "NotchNook",
      bundleId: "com.notchnook.app",
      windowLevel: 25
    ),
    KnownNotchApp(
      name: "Notchmeister",
      bundleId: "com.manytricks.Notchmeister",
      windowLevel: 25
    ),
  ]
}

/// Çakışma çözüm modu
enum ConflictMode: String, CaseIterable {
  case compatible   // Diğer uygulamaların altında kal
  case coexist      // Yan yana (bildirimler geçici üste çıkar)
  case override     // Her zaman üstte

  var displayName: String {
    switch self {
    case .compatible: return "Uyumlu"
    case .coexist: return "Birlikte"
    case .override: return "Üstte"
    }
  }
}

/// Diğer notch uygulamalarını tespit edip çakışma yönetimi sağlar
final class ConflictResolver: ObservableObject {
  static let shared = ConflictResolver()

  /// Mevcut çakışma modu
  @Published var mode: ConflictMode = .coexist

  /// Şu an çalışan notch uygulamaları
  @Published var activeConflicts: [KnownNotchApp] = []

  private var workspaceObserver: Any?
  private var pollTimer: Timer?

  /// Çakışma taramasını başlat
  func start() {
    scan()

    // Uygulama açılma/kapanma olaylarını dinle
    let center = NSWorkspace.shared.notificationCenter
    workspaceObserver = center.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.scan()
    }

    center.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.scan()
    }

    // Her 10 saniyede yeniden tara
    pollTimer = Timer.scheduledTimer(
      withTimeInterval: 10.0,
      repeats: true
    ) { [weak self] _ in
      self?.scan()
    }
  }

  /// Taramayı durdur
  func stop() {
    if let observer = workspaceObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    pollTimer?.invalidate()
    pollTimer = nil
  }

  /// Çalışan notch uygulamalarını tara
  func scan() {
    let runningApps = NSWorkspace.shared.runningApplications
    let runningBundleIds = Set(
      runningApps.compactMap(\.bundleIdentifier)
    )

    activeConflicts = KnownNotchApp.all.filter {
      runningBundleIds.contains($0.bundleId)
    }
  }

  /// Mevcut duruma göre önerilen window level
  var recommendedWindowLevel: NSWindow.Level {
    guard !activeConflicts.isEmpty else {
      // Çakışma yok — rahat seviye
      return NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3
      )
    }

    switch mode {
    case .compatible:
      // En düşük çakışan uygulamanın altında
      let minLevel = activeConflicts.map(\.windowLevel).min() ?? 25
      return NSWindow.Level(rawValue: minLevel - 1)

    case .coexist:
      // Normal seviye, bildirimler geçici yükselir
      return NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2
      )

    case .override:
      // Tüm notch uygulamalarının üstünde
      let maxLevel = activeConflicts.map(\.windowLevel).max() ?? 33
      return NSWindow.Level(rawValue: maxLevel + 1)
    }
  }

  /// Çakışan uygulama var mı?
  var hasConflicts: Bool {
    !activeConflicts.isEmpty
  }
}
