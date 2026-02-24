import SwiftUI

/// Claude Code genişletilmiş görünüm — grid layout, bireysel tıklama
struct ClaudeExpandedView: View {
  @ObservedObject var provider: ClaudeProvider

  /// Proje adına göre ikon seçimi (deterministik)
  private static let projectIcons = [
    "folder.fill", "doc.text.fill", "terminal.fill",
    "hammer.fill", "wrench.and.screwdriver.fill",
    "cpu.fill", "server.rack", "externaldrive.fill",
    "network", "globe", "bolt.fill", "leaf.fill",
  ]

  private func iconFor(session: AISession) -> String {
    let hash = abs(session.projectName.hashValue)
    return Self.projectIcons[hash % Self.projectIcons.count]
  }

  /// Grid sütun tanımı — 2 sütunlu
  private let columns = [
    GridItem(.flexible(), spacing: 8),
    GridItem(.flexible(), spacing: 8),
  ]

  var body: some View {
    VStack(spacing: 6) {
      // Üst satır: durum badge
      HStack {
        statusBadge
        Spacer()
        Text("\(provider.sessions.count) oturum")
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.4))
      }

      if provider.sessions.count > 1 {
        Divider()
          .background(.white.opacity(0.1))

        // Grid — her oturum bir kart
        LazyVGrid(columns: columns, spacing: 6) {
          ForEach(provider.sessions, id: \.id) { session in
            SessionTile(
              session: session,
              icon: iconFor(session: session),
              isActive: provider.activeSession?.id == session.id
            )
            .onTapGesture {
              provider.activateSession(session)
            }
          }
        }
      } else if let session = provider.activeSession {
        // Tek oturum — basit görünüm
        HStack(spacing: 8) {
          Image(systemName: iconFor(session: session))
            .font(.system(size: 14))
            .foregroundStyle(.cyan)
          VStack(alignment: .leading, spacing: 2) {
            Text(session.projectName)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.white)
              .lineLimit(1)
            Text(session.ideName)
              .font(.system(size: 9))
              .foregroundStyle(.white.opacity(0.4))
          }
          Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
          provider.activateSession(session)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  // MARK: - Status Badge

  @ViewBuilder
  private var statusBadge: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)

      Text(statusText)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
    }
  }

  private var statusColor: Color {
    switch provider.status {
    case .idle: return .gray
    case .working: return .cyan
    case .waitingInput: return .orange
    }
  }

  private var statusText: String {
    switch provider.status {
    case .idle: return "Hazır"
    case .working: return "Çalışıyor"
    case .waitingInput: return "Yanıt Bekliyor"
    }
  }
}

// MARK: - Session Tile

/// Grid içindeki tek oturum kartı
private struct SessionTile: View {
  let session: AISession
  let icon: String
  let isActive: Bool

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 11))
        .foregroundStyle(isActive ? .cyan : .white.opacity(0.6))
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 1) {
        Text(session.projectName)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.white.opacity(0.9))
          .lineLimit(1)

        Text(session.ideName)
          .font(.system(size: 8))
          .foregroundStyle(.white.opacity(0.35))
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      Circle()
        .fill(session.isAlive ? .green : .red)
        .frame(width: 5, height: 5)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(.white.opacity(isHovering ? 0.1 : 0.05))
    )
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
    }
  }
}
