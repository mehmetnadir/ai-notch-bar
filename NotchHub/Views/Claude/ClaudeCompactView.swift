import SwiftUI

/// Claude Code kompakt görünüm (notch içinde küçük)
struct ClaudeCompactView: View {
  @ObservedObject var provider: ClaudeProvider

  var body: some View {
    HStack(spacing: 8) {
      // Durum ikonu
      statusIcon
        .font(.system(size: 12, weight: .medium))

      // Proje adı
      if let session = provider.activeSession {
        Text(session.projectName)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.white)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 12)
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch provider.status {
    case .idle:
      Image(systemName: "sparkle")
        .foregroundStyle(.white.opacity(0.4))

    case .working:
      Image(systemName: "bolt.fill")
        .foregroundStyle(.cyan)
        .symbolEffect(.pulse)

    case .waitingInput:
      Image(systemName: "exclamationmark.bubble.fill")
        .foregroundStyle(.orange)
        .symbolEffect(.pulse)
    }
  }
}
