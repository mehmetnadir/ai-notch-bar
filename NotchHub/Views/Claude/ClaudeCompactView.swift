import SwiftUI

/// Claude Code kompakt görünüm — peek bildiriminde gösterilir
struct ClaudeCompactView: View {
  @ObservedObject var provider: ClaudeProvider

  var body: some View {
    HStack(spacing: 6) {
      // Durum ikonu
      Image(systemName: statusIcon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(statusColor)
        .symbolEffect(.pulse, isActive: isAnimating)

      // Proje adı
      if let session = statusSession {
        Text(session.projectName)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.white)
          .lineLimit(1)
      }

      // Durum etiketi
      Text(statusLabel)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(statusColor)
    }
    .padding(.horizontal, 12)
  }

  // MARK: - Durum Bilgileri

  private var statusSession: AISession? {
    switch provider.status {
    case .idle: return nil
    case .working(let s): return s
    case .waitingInput(let s): return s
    case .completed(let s): return s
    }
  }

  private var statusIcon: String {
    switch provider.status {
    case .idle: return "sparkle"
    case .working: return "bolt.fill"
    case .waitingInput: return "exclamationmark.bubble.fill"
    case .completed: return "checkmark.circle.fill"
    }
  }

  private var statusColor: Color {
    switch provider.status {
    case .idle: return .white.opacity(0.4)
    case .working: return .green
    case .waitingInput: return .red
    case .completed: return .cyan
    }
  }

  private var statusLabel: String {
    switch provider.status {
    case .idle: return ""
    case .working: return "çalışıyor"
    case .waitingInput: return "yanıt bekliyor"
    case .completed: return "tamamlandı"
    }
  }

  private var isAnimating: Bool {
    if case .idle = provider.status { return false }
    return true
  }
}
