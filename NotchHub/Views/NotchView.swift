import SwiftUI
import Combine

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
  @State private var showSettings = false
  @State private var hoverTask: Task<Void, Never>?
  @State private var peekTask: Task<Void, Never>?
  @State private var resizeTask: Task<Void, Never>?
  @State private var globalMonitor: Any?
  @State private var localMonitor: Any?

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

      Spacer(minLength: 0)
    }
    .ignoresSafeArea()
    .frame(
      width: NotchWindow.openSize.width,
      height: NotchWindow.openSize.height + NotchWindow.shadowPadding
    )
    .onAppear {
      setupPeekCallback()
      setupMouseMonitor()
      updateClickThrough()
    }
    .onDisappear {
      removeMouseMonitor()
    }
    .onChange(of: notchState) {
      updateClickThrough()
    }
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
    .contentShape(Rectangle())
    .onTapGesture {
      manager.activeProvider?.onActivate()
    }
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
      // Üst: notch yüksekliği kadar boşluk + gear butonu
      HStack {
        Spacer()
        Button(action: { showSettings.toggle() }) {
          Image(systemName: showSettings
            ? "xmark.circle.fill"
            : "gearshape.fill")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.35))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 14)
      }
      .frame(height: notchHeight)

      // Genişletilmiş içerik veya ayarlar
      if showSettings {
        SettingsView(onClose: { showSettings = false })
      } else if let provider = manager.activeProvider {
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
        try? await Task.sleep(
          for: .milliseconds(Int(settings.hoverDelay))
        )
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

  // MARK: - Mouse Monitor (NSEvent)
  //
  // .onHover nonactivatingPanel'da çalışmaz çünkü SwiftUI'nin dahili
  // NSTrackingArea'sı .activeInKeyWindow kullanır. Pencere hiç key
  // olmadığı için event tetiklenmez.
  //
  // Çözüm: NSEvent global+local monitor ile mouse pozisyonunu ekran
  // koordinatlarında takip edip notch hit area'sında mı kontrol etmek.

  /// Notch hit area'sı — ekran koordinatlarında (macOS: sol-alt origin)
  private var notchHitRect: NSRect {
    guard let screen = screenDetector.builtinScreen else {
      return .zero
    }
    // Açık durumda daha büyük alan, kapalı/peek'te notch boyutu
    let hitWidth: CGFloat
    let hitHeight: CGFloat
    switch notchState {
    case .closed:
      hitWidth = currentWidth + 20
      hitHeight = notchHeight + 10
    case .peeking:
      hitWidth = peekWidth + 20
      hitHeight = peekHeight + 10
    case .open:
      hitWidth = openWidth
      hitHeight = openHeight
    }
    return NSRect(
      x: screen.frame.midX - hitWidth / 2,
      y: screen.frame.maxY - hitHeight,
      width: hitWidth,
      height: hitHeight
    )
  }

  private func checkMousePosition() {
    let mouseLocation = NSEvent.mouseLocation
    let inNotch = notchHitRect.contains(mouseLocation)
    if inNotch != isHovering {
      handleHover(inNotch)
    }
  }

  private func setupMouseMonitor() {
    // Global: uygulama arka plandayken (başka pencere aktifken)
    globalMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.mouseMoved]
    ) { [self] _ in
      checkMousePosition()
    }
    // Local: uygulama ön plandayken
    localMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.mouseMoved]
    ) { [self] event in
      checkMousePosition()
      return event
    }
  }

  private func removeMouseMonitor() {
    if let monitor = globalMonitor {
      NSEvent.removeMonitor(monitor)
      globalMonitor = nil
    }
    if let monitor = localMonitor {
      NSEvent.removeMonitor(monitor)
      localMonitor = nil
    }
  }

  // MARK: - Click-Through Yönetimi

  /// Panel frame'ini notch durumuna göre günceller.
  ///
  /// ignoresMouseEvents macOS'ta güvenilir çalışmadığından,
  /// panel fiziksel olarak küçültülür. Kapalıyken sadece notch
  /// alanı kadar yer kaplar — altındaki hiçbir şeyi engellemez.
  ///
  /// Global/local NSEvent monitor'lar bağımsız çalışır —
  /// panel boyutu hover tespitini etkilemez.
  private func updateClickThrough() {
    let shouldAcceptClicks = notchState != .closed
    manager.notchWindow?.acceptsClicks = shouldAcceptClicks
    resizeTask?.cancel()

    switch notchState {
    case .open:
      manager.notchWindow?.updatePanelFrame(
        width: openWidth,
        height: openHeight + NotchWindow.shadowPadding
      )
    case .peeking:
      manager.notchWindow?.updatePanelFrame(
        width: peekWidth + 20,
        height: peekHeight + 10
      )
    case .closed:
      // Kapatma animasyonu bittikten sonra küçült
      resizeTask = Task {
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        await MainActor.run {
          guard notchState == .closed else { return }
          manager.notchWindow?.updatePanelFrame(
            width: currentWidth + 20,
            height: notchHeight + 10
          )
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
      try? await Task.sleep(for: .seconds(settings.peekDuration))
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
