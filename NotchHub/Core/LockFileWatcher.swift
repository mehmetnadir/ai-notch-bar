import Foundation
import Combine

/// Tek bir oturumun durumu
enum SessionStatus: Equatable {
  case working       // Çalışıyor (varsayılan — lock dosyası var = aktif)
  case waitingInput  // Kullanıcı girdisi bekliyor (CLI hook tetikler)
  case idle          // Boşta (oturum var ama aktif değil)
}

/// AI IDE oturumu bilgisi
struct AISession: Identifiable, Equatable {
  let id: String          // Port numarası
  let port: Int
  let pid: Int
  let workspaceFolders: [String]
  let ideName: String
  let transport: String

  /// Proje adı (son klasör ismi)
  var projectName: String {
    workspaceFolders.first
      .flatMap { URL(fileURLWithPath: $0).lastPathComponent }
      ?? "Bilinmeyen"
  }

  /// PID hâlâ canlı mı?
  var isAlive: Bool {
    kill(Int32(pid), 0) == 0
  }

  static func == (lhs: AISession, rhs: AISession) -> Bool {
    lhs.id == rhs.id && lhs.pid == rhs.pid
  }
}

/// Lock dosya değişiklik olayları
enum LockFileEvent {
  case sessionStarted(AISession)
  case sessionEnded(String)      // port id
  case sessionCrashed(AISession) // PID ölü
}

/// ~/.claude/ide/*.lock dosyalarını FSEvents ile izler
final class LockFileWatcher: ObservableObject {
  @Published var sessions: [AISession] = []

  let events = PassthroughSubject<LockFileEvent, Never>()

  private var stream: FSEventStreamRef?
  private let watchPath: String
  private var healthCheckTimer: Timer?

  init() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    self.watchPath = "\(home)/.claude/ide"
  }

  /// İzlemeyi başlat
  func start() {
    // Dizin yoksa oluştur (ilk kullanım)
    try? FileManager.default.createDirectory(
      atPath: watchPath,
      withIntermediateDirectories: true
    )

    // Mevcut lock dosyalarını tara
    scanLockFiles()

    // FSEvents stream başlat
    var context = FSEventStreamContext()
    context.info = Unmanaged.passUnretained(self).toOpaque()

    let paths = [watchPath] as CFArray
    stream = FSEventStreamCreate(
      nil,
      fsEventCallback,
      &context,
      paths,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
      0.5,  // 500ms debounce
      UInt32(
        kFSEventStreamCreateFlagUseCFTypes
        | kFSEventStreamCreateFlagFileEvents
      )
    )

    if let stream = stream {
      FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
      FSEventStreamStart(stream)
    }

    // Her 5 saniyede PID sağlık kontrolü
    healthCheckTimer = Timer.scheduledTimer(
      withTimeInterval: 5.0,
      repeats: true
    ) { [weak self] _ in
      self?.checkHealth()
    }
  }

  /// İzlemeyi durdur
  func stop() {
    healthCheckTimer?.invalidate()
    healthCheckTimer = nil

    if let stream = stream {
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
      self.stream = nil
    }
  }

  /// Lock dosyalarını tara ve session listesini güncelle
  /// `fileprivate` — C callback'inden erişim için gerekli
  fileprivate func scanLockFiles() {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: watchPath) else {
      return
    }

    let lockFiles = files.filter { $0.hasSuffix(".lock") }
    var newSessions: [AISession] = []

    for file in lockFiles {
      let path = "\(watchPath)/\(file)"
      if let session = parseLockFile(at: path) {
        newSessions.append(session)
      }
    }

    // Yeni oturumları tespit et
    let oldIds = Set(sessions.map(\.id))
    let newIds = Set(newSessions.map(\.id))

    for session in newSessions where !oldIds.contains(session.id) {
      events.send(.sessionStarted(session))
    }

    for id in oldIds.subtracting(newIds) {
      events.send(.sessionEnded(id))
    }

    DispatchQueue.main.async {
      self.sessions = newSessions
    }
  }

  /// Tek bir lock dosyasını parse et
  private func parseLockFile(at path: String) -> AISession? {
    guard let data = FileManager.default.contents(atPath: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let pid = json["pid"] as? Int,
          let workspaceFolders = json["workspaceFolders"] as? [String],
          let ideName = json["ideName"] as? String
    else { return nil }

    let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    let port = Int(fileName) ?? 0
    let transport = json["transport"] as? String ?? "unknown"
    // authToken kasıtlı olarak okunmuyor — güvenlik

    return AISession(
      id: fileName,
      port: port,
      pid: pid,
      workspaceFolders: workspaceFolders,
      ideName: ideName,
      transport: transport
    )
  }

  /// PID sağlık kontrolü
  private func checkHealth() {
    for session in sessions where !session.isAlive {
      events.send(.sessionCrashed(session))
    }
    // Ölü oturumları temizle
    DispatchQueue.main.async {
      self.sessions.removeAll { !$0.isAlive }
    }
  }
}

/// FSEvents callback (C fonksiyonu)
private func fsEventCallback(
  _ streamRef: ConstFSEventStreamRef,
  _ clientCallBackInfo: UnsafeMutableRawPointer?,
  _ numEvents: Int,
  _ eventPaths: UnsafeMutableRawPointer,
  _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
  _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
  guard let info = clientCallBackInfo else { return }
  let watcher = Unmanaged<LockFileWatcher>.fromOpaque(info).takeUnretainedValue()
  watcher.scanLockFiles()
}
