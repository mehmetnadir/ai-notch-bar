import SwiftUI

struct NotchView: View {
  @ObservedObject var manager: NotchHubManager
  @State private var isHovering = false

  private let screenDetector = ScreenDetector.shared

  /// Notch genişliği (veya fallback)
  private var notchWidth: CGFloat {
    screenDetector.notchSize?.width ?? 200
  }

  /// Notch yüksekliği
  private var notchHeight: CGFloat {
    screenDetector.notchSize?.height ?? 32
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Arka plan kapsül
        capsuleBackground

        // İçerik
        if let provider = manager.activeProvider {
          if manager.isExpanded || isHovering {
            provider.expandedView()
              .transition(.opacity.combined(with: .scale(scale: 0.95)))
          } else {
            provider.compactView()
              .transition(.opacity)
          }
        } else {
          // Aktif provider yok — minimal görünüm
          idleView
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .onHover { hovering in
      withAnimation(.interactiveSpring(duration: 0.4, extraBounce: 0.2)) {
        isHovering = hovering
      }
    }
    .onTapGesture {
      manager.activeProvider?.onActivate()
    }
  }

  /// Siyah kapsül arka plan (Dynamic Island tarzı)
  private var capsuleBackground: some View {
    RoundedRectangle(
      cornerRadius: isHovering ? 20 : notchHeight / 2,
      style: .continuous
    )
    .fill(.black)
    .frame(
      width: isHovering ? notchWidth + 80 : notchWidth,
      height: isHovering ? notchHeight + 40 : notchHeight
    )
    .shadow(
      color: .black.opacity(0.3),
      radius: isHovering ? 12 : 0,
      y: isHovering ? 4 : 0
    )
    .animation(
      .interactiveSpring(duration: 0.5, extraBounce: 0.25, blendDuration: 0.125),
      value: isHovering
    )
  }

  /// Hiçbir provider aktif değilken gösterilen minimal görünüm
  private var idleView: some View {
    HStack(spacing: 6) {
      Image(systemName: "sparkle")
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.5))
    }
    .frame(width: notchWidth, height: notchHeight)
  }
}
