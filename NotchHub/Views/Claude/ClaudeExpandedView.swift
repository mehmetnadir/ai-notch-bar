import SwiftUI

/// Claude Code genişletilmiş görünüm — 3 sütunlu grid, marka ikonlu tile'lar
struct ClaudeExpandedView: View {
  @ObservedObject var provider: ClaudeProvider

  /// Bu provider'ın markası
  private let providerBrand: AIBrand = .claude

  /// Oturum durumuna göre renk döndür
  private func colorFor(session: AISession) -> Color {
    switch provider.statusFor(session: session) {
    case .working: return .green
    case .waitingInput: return .red
    case .idle: return .gray
    }
  }

  /// Grid sütun tanımı — 2 sütunlu (yatay tile ile daha iyi okunur)
  private let columns = [
    GridItem(.flexible(), spacing: 6),
    GridItem(.flexible(), spacing: 6),
  ]

  var body: some View {
    VStack(spacing: 6) {
      // Üst satır: marka ikonu + durum badge
      HStack(spacing: 6) {
        BrandIcon(brand: providerBrand, size: 14)
        statusBadge
        Spacer()
        Text("\(provider.sessions.count) oturum")
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.4))
      }

      if provider.sessions.count > 1 {
        Divider()
          .background(.white.opacity(0.1))

        // Grid — 3 sütunlu, her oturum renkli kart
        LazyVGrid(columns: columns, spacing: 6) {
          ForEach(provider.sessions, id: \.id) { session in
            SessionTile(
              session: session,
              brand: providerBrand,
              accentColor: colorFor(session: session),
              sessionStatus: provider.statusFor(session: session),
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
          BrandIcon(brand: providerBrand, size: 14)
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
    case .working: return .green
    case .waitingInput: return .red
    case .completed: return .cyan
    }
  }

  private var statusText: String {
    switch provider.status {
    case .idle: return "Hazır"
    case .working: return "Çalışıyor"
    case .waitingInput: return "Yanıt Bekliyor"
    case .completed: return "Tamamlandı"
    }
  }
}

// MARK: - Session Tile

/// Grid içindeki tek oturum kartı — duruma göre renkli arka plan
private struct SessionTile: View {
  let session: AISession
  let brand: AIBrand
  let accentColor: Color
  let sessionStatus: SessionStatus
  let isActive: Bool

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 5) {
      // Sol: provider marka ikonu
      BrandIcon(brand: brand, size: 12)

      // Proje adı — truncation ile
      Text(session.projectName)
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer(minLength: 0)

      // Durum göstergesi — küçük dot + kısa etiket
      HStack(spacing: 3) {
        Circle()
          .fill(accentColor)
          .frame(width: 5, height: 5)
        Text(statusLabel)
          .font(.system(size: 7, weight: .medium))
          .foregroundStyle(accentColor.opacity(0.8))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 5)
    .padding(.horizontal, 6)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(accentColor.opacity(isHovering ? 0.25 : 0.15))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
              accentColor.opacity(isActive ? 0.6 : 0.25),
              lineWidth: 1
            )
        )
    )
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
    }
  }

  private var statusLabel: String {
    switch sessionStatus {
    case .working: return "aktif"
    case .waitingInput: return "bekliyor"
    case .idle: return "boşta"
    }
  }
}
