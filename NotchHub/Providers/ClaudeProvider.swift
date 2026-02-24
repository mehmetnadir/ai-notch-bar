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

  /// Tıklama döngüsü için son aktive edilen session index'i
  private var lastActivatedIndex: Int = -1

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

  /// Notch solunda durum ikonu
  func compactLeadingView() -> AnyView {
    AnyView(ClaudeLeadingIcon(provider: self))
  }

  /// Notch sağında oturum sayısı
  func compactTrailingView() -> AnyView {
    AnyView(ClaudeTrailingIcon(provider: self))
  }

  /// Tıklama — tek oturum varsa onu aç, birden fazlaysa round-robin
  func onActivate() {
    guard !sessions.isEmpty else { return }
    lastActivatedIndex = (lastActivatedIndex + 1) % sessions.count
    activateSession(sessions[lastActivatedIndex])
  }

  /// Belirli bir oturumun IDE penceresini öne getir (PID tabanlı)
  func activateSession(_ session: AISession) {
    if let app = NSRunningApplication(
      processIdentifier: pid_t(session.pid)
    ) {
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

  /// Peek tetiklendiğinde çağrılacak callback
  var onPeekRequested: (() -> Void)?

  /// Kullanıcı girdisi bekleniyor (CLI hook'tan çağrılır)
  func notifyWaitingInput(sessionId: String? = nil) {
    if let session = sessionId.flatMap({ id in sessions.first { $0.id == id } })
      ?? sessions.first {
      status = .waitingInput(session)
      soundManager.playNotification()
      onPeekRequested?()
    }
  }
}
