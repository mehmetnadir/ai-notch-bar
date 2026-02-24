import SwiftUI

/// Notch durumları — boring.notch tarzı + bildirim peek
enum NotchState: Equatable {
  case closed    // Fiziksel notch boyutu, gizli
  case peeking   // Hafif aşağı genişleme (bildirim)
  case open      // Tam genişleme (hover)
}

struct NotchView: View {
  @ObservedObject var manager: NotchHubManager
  @ObservedObject private var settings = AppSettings.shared

  @State private var notchState: NotchState = .closed
  @State private var isHovering = false
  @State private var hoverTask: Task<Void, Never>?
  @State private var peekTask: Task<Void, Never>?

  private let screenDetector = ScreenDetector.shared

  // MARK: - Boyut Sabitleri

  /// Fiziksel notch genişliği
  private var notchWidth: CGFloat {
    screenDetector.notchSize?.width ?? 200
  }

  /// Fiziksel notch yüksekliği
  private var notchHeight: CGFloat {
    screenDetector.notchSize?.height ?? 32
  }

  /// Yan ikon kutusu boyutu (notch yüksekliğine uyumlu)
  private var sideIconSize: CGFloat {
    max(0, notchHeight - 12)
  }

  /// Açık durum boyutları
  private var openWidth: CGFloat { NotchWindow.openSize.width }
  private var openHeight: CGFloat { NotchWindow.openSize.height }

  /// Peek durumu boyutları
  private var peekWidth: CGFloat { notchWidth + 60 }
  private var peekHeight: CGFloat { notchHeight + 24 }

  // MARK: - Duruma Göre Boyutlar

  private var currentWidth: CGFloat {
    switch notchState {
    case .closed: return notchWidth + sideIconWidth * 2
    case .peeking: return peekWidth
    case .open: return openWidth
    }
  }

  private var currentHeight: CGFloat {
    switch notchState {
    case .closed: return notchHeight
    case .peeking: return peekHeight
    case .open: return openHeight
    }
  }

  /// Yan ikonların toplam genişliği (provider aktifse)
  private var sideIconWidth: CGFloat {
    manager.activeProvider != nil ? sideIconSize + 6 : 0
  }

  // MARK: - NotchShape Parametreleri

  private var topRadius: CGFloat {
    switch notchState {
    case .closed: return 6
    case .peeking: return 10
    case .open: return 19
    }
  }

  private var bottomRadius: CGFloat {
    switch notchState {
    case .closed: return 14
    case .peeking: return 16
    case .open: return 24
    }
  }

  private var currentShape: NotchShape {
    NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      notchContent
        .frame(width: currentWidth, height: currentHeight)
        .animation(currentAnimation, value: notchState)
        .clipShape(currentShape)
        .contentShape(currentShape)
        .onHover { handleHover($0) }
        .onTapGesture {
          if notchState == .closed {
            manager.activeProvider?.onActivate()
          }
        }

      Spacer(minLength: 0)
    }
    .ignoresSafeArea()
    .frame(
      width: NotchWindow.openSize.width,
      height: NotchWindow.openSize.height + NotchWindow.shadowPadding
    )
    .onAppear { setupPeekCallback() }
  }

  // MARK: - Ana İçerik

  @ViewBuilder
  private var notchContent: some View {
    ZStack(alignment: .top) {
      // Siyah arka plan
      currentShape
        .fill(.black)
        .overlay(
          currentShape
            .strokeBorder(
              settings.borderColor.opacity(
                notchState == .open
                  ? settings.borderOpacity
                  : settings.borderOpacity * 0.2
              ),
              lineWidth: settings.borderWidth
            )
        )
        .shadow(
          color: .black.opacity(0.4),
          radius: notchState == .open ? 16 : 0,
          y: notchState == .open ? 6 : 0
        )

      // İçerik katmanı
      Group {
        switch notchState {
        case .closed:
          closedLayout
        case .peeking:
          peekingLayout
        case .open:
          openLayout
        }
      }
    }
  }

  // MARK: - Kapalı Durum: [solİkon] [notchAlanı] [sağİkon]

  private var closedLayout: some View {
    HStack(spacing: 0) {
      // Sol ikon
      if let provider = manager.activeProvider {
        provider.compactLeadingView()
          .frame(width: sideIconSize, height: sideIconSize)
          .padding(.leading, 6)
      }

      // Ortadaki notch alanı (fiziksel notch genişliği)
      Rectangle()
        .fill(.clear)
        .frame(width: notchWidth)

      // Sağ ikon
      if let provider = manager.activeProvider {
        provider.compactTrailingView()
          .frame(width: sideIconSize, height: sideIconSize)
          .padding(.trailing, 6)
      }
    }
    .frame(height: notchHeight)
  }

  // MARK: - Peek Durum: Kısa bildirim genişlemesi

  private var peekingLayout: some View {
    VStack(spacing: 2) {
      Spacer(minLength: notchHeight - 4)

      if let provider = manager.activeProvider {
        provider.compactView()
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 8)
    .padding(.bottom, 4)
  }

  // MARK: - Açık Durum: Tam genişletilmiş

  private var openLayout: some View {
    VStack(spacing: 0) {
      // Üst: notch yüksekliği kadar boşluk (fiziksel notch alanı)
      Spacer()
        .frame(height: notchHeight)

      // Genişletilmiş içerik
      if let provider = manager.activeProvider {
        provider.expandedView()
      } else {
        idleExpandedView
      }
    }
  }

  // MARK: - Animasyon

  private var currentAnimation: Animation {
    switch notchState {
    case .closed:
      return .spring(response: 0.45, dampingFraction: 1.0)
    case .peeking:
      return .spring(response: 0.3, dampingFraction: 0.85)
    case .open:
      return .spring(response: 0.42, dampingFraction: 0.8)
    }
  }

  // MARK: - Hover Yönetimi

  private func handleHover(_ hovering: Bool) {
    hoverTask?.cancel()

    if hovering {
      isHovering = true
      guard notchState == .closed || notchState == .peeking else { return }

      hoverTask = Task {
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        await MainActor.run {
          guard isHovering else { return }
          peekTask?.cancel()
          notchState = .open
        }
      }
    } else {
      hoverTask = Task {
        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled else { return }
        await MainActor.run {
          isHovering = false
          if notchState == .open {
            notchState = .closed
          }
        }
      }
    }
  }

  // MARK: - Peek (Bildirim Genişlemesi)

  private func setupPeekCallback() {
    manager.claudeProvider?.onPeekRequested = { [self] in
      triggerPeek()
    }
  }

  private func triggerPeek() {
    guard notchState == .closed else { return }
    peekTask?.cancel()

    notchState = .peeking
    peekTask = Task {
      try? await Task.sleep(for: .seconds(4))
      guard !Task.isCancelled else { return }
      await MainActor.run {
        if notchState == .peeking {
          notchState = .closed
        }
      }
    }
  }

  // MARK: - Idle

  private var idleExpandedView: some View {
    VStack {
      Spacer()
      Image(systemName: "sparkle")
        .font(.system(size: 16))
        .foregroundStyle(.white.opacity(0.3))
      Text("NotchHub")
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.3))
      Spacer()
    }
  }
}
