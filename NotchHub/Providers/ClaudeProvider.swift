import SwiftUI
import Combine

/// Claude Code durum bilgisi
enum ClaudeStatus: Equatable {
  case idle                    // Aktif oturum yok
  case working(AISession)      // Çalışıyor
  case waitingInput(AISession) // Kullanıcı girdisi bekliyor
  case completed(AISession)    // Görev tamamlandı
}

/// Claude Code entegrasyonu — lock dosyalarını izleyerek durum takibi
final class ClaudeProvider: ObservableObject, NotchProvider {
  let id = "claude-code"
  let name = "Claude Code"

  @Published var status: ClaudeStatus = .idle
  @Published private(set) var sessions: [AISession] = []

  /// Oturum bazlı durum takibi (session.id → SessionStatus)
  @Published var sessionStatuses: [String: SessionStatus] = [:]

  /// Belirli oturumun durumunu döndür
  func statusFor(session: AISession) -> SessionStatus {
    sessionStatuses[session.id] ?? .idle
  }

  /// Tıklama döngüsü için son aktive edilen session index'i
  private var lastActivatedIndex: Int = -1

  /// .waitingInput durumunun otomatik temizlenmesi için timeout timer
  private var waitingInputTimeoutTask: Task<Void, Never>?
  /// Oturum bazlı waitingInput timeout'ları
  private var sessionTimeoutTasks: [String: Task<Void, Never>] = [:]

  private let watcher = LockFileWatcher()
  private let soundManager = SoundManager.shared
  private var cancellables = Set<AnyCancellable>()

  /// Mevcut duruma göre provider önceliği
  var priority: ProviderPriority {
    switch status {
    case .idle: return .low
    case .working: return .normal
    case .waitingInput: return .critical
    case .completed: return .normal
    }
  }

  /// Provider durumu
  var state: ProviderState {
    switch status {
    case .idle: return .inactive
    case .working: return .active
    case .waitingInput: return .attention
    case .completed: return .active
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
    // sessions.count değişmiş olabilir — sınır dışı erişimi önle
    if lastActivatedIndex >= sessions.count { lastActivatedIndex = -1 }
    lastActivatedIndex = (lastActivatedIndex + 1) % sessions.count
    activateSession(sessions[lastActivatedIndex])
  }

  /// Belirli bir oturumun IDE penceresini öne getir
  ///
  /// Aynı PID altında birden fazla pencere olabilir (Cursor gibi IDE'ler
  /// her workspace için ayrı pencere açar ama tek process kullanır).
  /// CGWindowList + AXUIElement ile workspace adına göre doğru pencereyi bulur.
  func activateSession(_ session: AISession) {
    let pid = pid_t(session.pid)
    let projectName = session.projectName

    // AXUIElement ile pencere başlığından eşleştir
    let appElement = AXUIElementCreateApplication(pid)
    var windowsRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      appElement, kAXWindowsAttribute as CFString, &windowsRef
    )

    if result == .success,
       let windows = windowsRef as? [AXUIElement] {
      for window in windows {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(
          window, kAXTitleAttribute as CFString, &titleRef
        )
        if let title = titleRef as? String,
           title.localizedCaseInsensitiveContains(projectName) {
          // Pencereyi öne getir
          AXUIElementSetAttributeValue(
            window, kAXFrontmostAttribute as CFString, true as CFTypeRef
          )
          AXUIElementPerformAction(window, kAXRaiseAction as CFString)
          // Uygulamayı da aktive et (pencere focus için gerekli)
          if let app = NSRunningApplication(processIdentifier: pid) {
            if #available(macOS 14.0, *) {
              app.activate()
            } else {
              app.activate(options: [.activateIgnoringOtherApps])
            }
          }
          return
        }
      }
    }

    // Fallback: eşleşme bulunamazsa uygulamayı aktive et
    if let app = NSRunningApplication(processIdentifier: pid) {
      if #available(macOS 14.0, *) {
        app.activate()
      } else {
        app.activate(options: [.activateIgnoringOtherApps])
      }
    }
  }

  /// İzlemeyi başlat
  func start() {
    watcher.start()

    // Oturum listesini takip et
    watcher.$sessions
      .receive(on: DispatchQueue.main)
      .sink { [weak self] sessions in
        // Sessions listesi değişince round-robin index'i sıfırla
        // Aksi halde eski index yanlış oturuma tıklar
        self?.lastActivatedIndex = -1
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
    waitingInputTimeoutTask?.cancel()
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
      waitingInputTimeoutTask?.cancel()
      sessionStatuses.removeAll()
      sessionTimeoutTasks.values.forEach { $0.cancel() }
      sessionTimeoutTasks.removeAll()
    } else if let session = sessions.first {
      // Yeni oturumları idle ile başlat (bildirim gelene kadar boşta)
      for s in sessions where sessionStatuses[s.id] == nil {
        sessionStatuses[s.id] = .idle
      }
      // Kapanan oturumların status'unu temizle
      let activeIds = Set(sessions.map(\.id))
      for key in sessionStatuses.keys where !activeIds.contains(key) {
        sessionStatuses.removeValue(forKey: key)
        sessionTimeoutTasks[key]?.cancel()
        sessionTimeoutTasks.removeValue(forKey: key)
      }
      // .waitingInput / .completed durumu CLI hook tarafından tetiklenir, korunur
      if case .waitingInput = status { return }
      if case .completed = status { return }
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

  /// Oturum çalışmaya başladı (CLI hook'tan çağrılır)
  func notifyWorking(sessionId: String? = nil) {
    if let session = sessionId.flatMap({ id in sessions.first { $0.id == id } })
      ?? sessions.first {
      sessionStatuses[session.id] = .working
      // waitingInput timeout'u varsa iptal et
      sessionTimeoutTasks[session.id]?.cancel()
      sessionTimeoutTasks.removeValue(forKey: session.id)
      // Provider-level güncelle
      if case .waitingInput = status {
        status = .working(session)
        waitingInputTimeoutTask?.cancel()
      } else if case .completed = status {
        status = .working(session)
        completedTimeoutTask?.cancel()
      }
    }
  }

  /// Görev tamamlandı timeout task'i
  private var completedTimeoutTask: Task<Void, Never>?

  /// Oturum boşta (CLI hook'tan çağrılır)
  func notifyIdle(sessionId: String? = nil) {
    if let session = sessionId.flatMap({ id in sessions.first { $0.id == id } })
      ?? sessions.first {
      sessionStatuses[session.id] = .idle
      sessionTimeoutTasks[session.id]?.cancel()
      sessionTimeoutTasks.removeValue(forKey: session.id)

      // Görev tamamlandı bildirimi — peek tetikle
      status = .completed(session)
      soundManager.playSubtle()
      onPeekRequested?()

      // 5 saniye sonra idle'a geç
      completedTimeoutTask?.cancel()
      completedTimeoutTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
        guard let self, !Task.isCancelled else { return }
        await MainActor.run {
          if case .completed = self.status {
            self.status = self.sessions.isEmpty
              ? .idle
              : .working(self.sessions[0])
          }
        }
      }
    }
  }

  /// Kullanıcı girdisi bekleniyor (CLI hook'tan çağrılır)
  func notifyWaitingInput(sessionId: String? = nil) {
    if let session = sessionId.flatMap({ id in sessions.first { $0.id == id } })
      ?? sessions.first {
      // Provider-level durum
      status = .waitingInput(session)
      // Oturum-level durum
      sessionStatuses[session.id] = .waitingInput
      soundManager.playNotification()
      onPeekRequested?()

      // Provider-level timeout
      waitingInputTimeoutTask?.cancel()
      waitingInputTimeoutTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
        guard let self, !Task.isCancelled else { return }
        await MainActor.run {
          guard case .waitingInput(let timedSession) = self.status else { return }
          if self.sessions.contains(where: { $0.id == timedSession.id }) {
            self.status = .working(timedSession)
          } else {
            self.status = self.sessions.isEmpty ? .idle : .working(self.sessions[0])
          }
        }
      }

      // Oturum-level timeout
      let sid = session.id
      sessionTimeoutTasks[sid]?.cancel()
      sessionTimeoutTasks[sid] = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
        guard let self, !Task.isCancelled else { return }
        await MainActor.run {
          if self.sessionStatuses[sid] == .waitingInput {
            self.sessionStatuses[sid] = .working
          }
        }
      }
    }
  }
}
