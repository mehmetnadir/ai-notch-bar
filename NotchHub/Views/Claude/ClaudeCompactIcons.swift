import SwiftUI

/// Notch'un sol tarafında görünen durum ikonu
struct ClaudeLeadingIcon: View {
  @ObservedObject var provider: ClaudeProvider

  var body: some View {
    Group {
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

      case .completed:
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
    }
    .font(.system(size: 11, weight: .medium))
  }
}

/// Notch'un sağ tarafında görünen oturum bilgisi
struct ClaudeTrailingIcon: View {
  @ObservedObject var provider: ClaudeProvider

  var body: some View {
    Group {
      if provider.sessions.count > 1 {
        Text("\(provider.sessions.count)")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 14, height: 14)
          .background(
            Circle().fill(.white.opacity(0.15))
          )
      } else if let session = provider.activeSession {
        Text(abbreviate(session.projectName))
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
      }
    }
  }

  private func abbreviate(_ name: String) -> String {
    let parts = name.split(separator: "-")
    if parts.count > 1 {
      return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }
    return String(name.prefix(3)).uppercased()
  }
}
