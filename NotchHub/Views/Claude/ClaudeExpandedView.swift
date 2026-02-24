import SwiftUI

/// Claude Code genişletilmiş görünüm (hover/tıklama ile)
struct ClaudeExpandedView: View {
  @ObservedObject var provider: ClaudeProvider

  var body: some View {
    VStack(spacing: 6) {
      // Üst satır: durum + proje
      HStack {
        statusBadge
        Spacer()
        if let session = provider.activeSession {
          Text(session.ideName)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }
      }

      // Alt satır: oturum detayları
      if provider.sessions.count > 1 {
        HStack(spacing: 4) {
          Image(systemName: "square.stack.3d.up")
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.4))
          Text("\(provider.sessions.count) aktif oturum")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var statusBadge: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)

      Text(statusText)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)

      if let session = provider.activeSession {
        Text("— \(session.projectName)")
          .font(.system(size: 11))
          .foregroundStyle(.white.opacity(0.7))
          .lineLimit(1)
      }
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
