import SwiftUI
import Combine

/// Claude Code durum bilgisi
enum ClaudeStatus: Equatable {
  case idle                    // Aktif oturum yok
  case working(AISession)      // Çalışıyor
  case waitingInput(AISession) // Kullanıcı girdisi bekliyor
}

/// Claude Code entegrasyonu — lock dosyalarını izleyerek durum takibi
final class ClaudeProvider: ObservableObject, NotchProvider {
  let id = "claude-code"
  let name = "Claude Code"

  @Published var status: ClaudeStatus = .idle
  @Published private(set) var sessions: [AISession] = []

  private let watcher = LockFileWatcher()
  private let soundManager = SoundManager.shared
  private var cancellables = Set<AnyCancellable>()

  /// Mevcut duruma göre provider önceliği
  var priority: ProviderPriority {
    switch status {
    case .idle: return .low
    case .working: return .normal
    case .waitingInput: return .critical
    }
  }

  /// Provider durumu
  var state: ProviderState {
    switch status {
    case .idle: return .inactive
    case .working: return .active
    case .waitingInput: return .attention
    }
  }

  /// Küçük görünüm
  func compactView() -> AnyView {
    AnyView(ClaudeCompactView(provider: self))
  }

  /// Genişletilmiş görünüm
  func expandedView() -> AnyView {
    AnyView(ClaudeExpandedView(provider: self))
  }

  /// Tıklama — aktif IDE penceresine geç
  func onActivate() {
    guard let session = activeSession else { return }
    // IDE'yi aktifle (bundleId bilgisi lock dosyasında yok, ideName'den tahmin)
    let bundleId = bundleIdForIDE(session.ideName)
    if let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleId
    ).first {
      app.activate()
    }
  }

  /// İzlemeyi başlat
  func start() {
    watcher.start()

    // Oturum listesini takip et
    watcher.$sessions
      .receive(on: DispatchQueue.main)
      .sink { [weak self] sessions in
        self?.sessions = sessions
        self?.updateStatus(sessions: sessions)
      }
      .store(in: &cancellables)

    // Olayları dinle
    watcher.events
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        self?.handleEvent(event)
      }
      .store(in: &cancellables)
  }

  /// İzlemeyi durdur
  func stop() {
    watcher.stop()
    cancellables.removeAll()
  }

  /// Aktif oturum (en son başlayan)
  var activeSession: AISession? {
    sessions.first
  }

  // MARK: - Private

  private func updateStatus(sessions: [AISession]) {
    if sessions.isEmpty {
      status = .idle
    } else if let session = sessions.first {
      // Lock dosyası var = çalışıyor (input bekleme CLI hook ile tetiklenir)
      if case .waitingInput = status { return }
      status = .working(session)
    }
  }

  private func handleEvent(_ event: LockFileEvent) {
    switch event {
    case .sessionStarted(let session):
      status = .working(session)
      soundManager.playSubtle()
    case .sessionEnded:
      if sessions.isEmpty {
        status = .idle
      }
    case .sessionCrashed:
      if sessions.isEmpty {
        status = .idle
      }
    }
  }

  /// Kullanıcı girdisi bekleniyor (CLI hook'tan çağrılır)
  func notifyWaitingInput(sessionId: String? = nil) {
    if let session = sessionId.flatMap({ id in sessions.first { $0.id == id } })
      ?? sessions.first {
      status = .waitingInput(session)
      soundManager.playNotification()
    }
  }

  /// IDE adından bundle ID tahmin et
  private func bundleIdForIDE(_ ideName: String) -> String {
    switch ideName.lowercased() {
    case "antigravity", "vscode", "vs code", "visual studio code":
      return "com.microsoft.VSCode"
    case "cursor":
      return "com.todesktop.230313mzl4w4u92"
    case "windsurf":
      return "com.codeium.windsurf"
    default:
      return "com.microsoft.VSCode"
    }
  }
}
