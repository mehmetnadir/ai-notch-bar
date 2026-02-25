import AppKit
import SwiftUI

// MARK: - NSHostingView Safe Area Override
// Kaynak: ArdentSwift (ardentswift.com/posts/macos-hide-toolbar/)
// boring.notch, NotchDrop, DynamicNotchKit projelerindeki ortak pattern.
//
// KÖK NEDEN: NSHostingView, pencere ekranın üst kenarında yer aldığında
// macOS notch safe area insets'ini otomatik olarak SwiftUI view hierarchy'ye
// aktarır. Bu da içeriğin ~32px aşağı kaymasına neden olur.
//
// ÇÖZÜM: NSHostingView subclass'ı ile safeAreaRect, safeAreaInsets,
// safeAreaLayoutGuide ve additionalSafeAreaInsets override edilerek
// safe area tamamen sıfırlanır. Bu, NSHostingView'in SwiftUI'ye
// "safe area yok" demesini sağlar.
//
// NEDEN DİĞER YÖNTEMLER BAŞARISIZ:
// 1. .ignoresSafeArea() -> SwiftUI tarafında çalışır ama NSHostingView
//    zaten layout'u hesaplamış olduğundan etkisiz kalır.
// 2. .fullSizeContentView -> Borderless pencerede zaten titlebar yok,
//    bu flag sadece titlebar olan pencerelerde işe yarar.
// 3. Wrapper NSView + frame kaydırma -> Kırılgan, farklı ekran
//    boyutlarında/çözünürlüklerde tutarsız davranır.
// 4. Pencereyi büyük yapma -> NSHostingView ekran konumuna göre
//    safe area hesaplamaya devam eder.
// 5. .hudWindow + .utilityWindow -> HUD pencereleri farklı görünüme
//    sahip olabilir ve safe area davranışı garantili değildir.

/// NSHostingView subclass'ı — safe area insets'i tamamen devre dışı bırakır.
/// Bu sayede SwiftUI içeriği notch arkasına (ekranın en üst kenarına) oturur.
final class SafeAreaFreeHostingView<Content: View>: NSHostingView<Content> {

  /// İlk tıklama window activation için harcanmasın — direkt SwiftUI'ye iletilsin
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }

  private lazy var zeroLayoutGuide: NSLayoutGuide = {
    let guide = NSLayoutGuide()
    addLayoutGuide(guide)
    NSLayoutConstraint.activate([
      leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      topAnchor.constraint(equalTo: guide.topAnchor),
      trailingAnchor.constraint(equalTo: guide.trailingAnchor),
      bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
    return guide
  }()

  @MainActor required init(rootView: Content) {
    super.init(rootView: rootView)
    // Layout guide'ı hemen oluştur
    _ = zeroLayoutGuide
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) kullanılmaz")
  }

  // -- Safe area override'ları --

  override var safeAreaRect: NSRect {
    return frame
  }

  override var safeAreaInsets: NSEdgeInsets {
    return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
  }

  override var safeAreaLayoutGuide: NSLayoutGuide {
    return zeroLayoutGuide
  }

  override var additionalSafeAreaInsets: NSEdgeInsets {
    get { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    set { /* yok say — macOS safe area enjekte etmeye çalışabilir */ }
  }
}

// MARK: - NotchPanel (constrainFrameRect Override)

/// NSPanel subclass'ı — macOS'un pencereyi notch/menu bar safe area'nın
/// altına itmesini engeller.
///
/// KÖK NEDEN: NSWindow.setFrame/setFrameOrigin çağrıları dahili olarak
/// constrainFrameRect'ten geçer. macOS bu metotla ekranın üst ~33px'ine
/// (safeAreaInsets.top) pencere yerleştirmeyi engeller. Override ile
/// istenen frame'i olduğu gibi döndürüyoruz.
final class NotchPanel: NSPanel {
  override func constrainFrameRect(
    _ frameRect: NSRect, to screen: NSScreen?
  ) -> NSRect {
    return frameRect
  }

  /// nonactivatingPanel mouse event'lerini aktif pencere olmadan da alsın
  override var canBecomeKey: Bool { true }

  /// İlk tıklamada panel'i key yap — SwiftUI Button action'ları tetiklensin
  override func mouseDown(with event: NSEvent) {
    makeKey()
    super.mouseDown(with: event)
  }
}

// MARK: - NotchWindow

/// Notch alanı penceresi — kanıtlanmış açık kaynak yaklaşımı
///
/// boring.notch (BoringNotchWindow) + NotchDrop (NotchWindow) +
/// DynamicNotchKit (DynamicNotchPanel) projelerinden derlenen çözüm:
///
/// 1. NotchPanel: borderless + nonactivatingPanel + constrainFrameRect
///    override (macOS pencere kısıtlamasını aşar)
/// 2. SafeAreaFreeHostingView: safe area sıfırlama (ArdentSwift pattern)
/// 3. Pencere konumlandırma: ekranın üst kenarı, yeterli boyut
///    (NotchDrop pattern)
final class NotchWindow {
  private var panel: NSPanel?
  private var hostingView: NSView?
  private let screenDetector = ScreenDetector.shared

  /// Açık durumda notch içerik boyutu (görsel animasyon için referans)
  static let openSize = CGSize(width: 640, height: 210)
  /// Gölge için ekstra padding
  static let shadowPadding: CGFloat = 20

  /// Mevcut window level (çakışma yönetimi için ayarlanabilir)
  var windowLevel: NSWindow.Level = NSWindow.Level(
    rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2
  ) {
    didSet { panel?.level = windowLevel }
  }

  /// Pencereyi oluştur ve göster
  @MainActor func setup<Content: View>(with content: Content) {
    guard let screen = screenDetector.builtinScreen else { return }

    // Pencere boyutu: içeriğin ihtiyaç duyduğu kadar
    // openSize + shadowPadding — tam olarak SwiftUI içeriğinin boyutu
    let panelWidth = NotchWindow.openSize.width
    let panelHeight = NotchWindow.openSize.height
      + NotchWindow.shadowPadding

    // NotchPanel — constrainFrameRect override ile ekranın
    // üst kenarına yerleşebilen panel
    let newPanel = NotchPanel(
      contentRect: NSRect(
        x: 0, y: 0, width: panelWidth, height: panelHeight
      ),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    // Pencere konfigürasyonu — boring.notch BoringNotchWindow referans
    newPanel.isOpaque = false
    newPanel.backgroundColor = .clear
    newPanel.isMovable = false
    newPanel.level = windowLevel
    newPanel.hasShadow = false
    newPanel.isFloatingPanel = true
    newPanel.titleVisibility = .hidden
    newPanel.titlebarAppearsTransparent = true
    newPanel.collectionBehavior = [
      .fullScreenAuxiliary,
      .stationary,
      .canJoinAllSpaces,
      .ignoresCycle,
    ]
    // Mouse tracking — global/local NSEvent monitor hover için yeterli.
    // ignoresMouseEvents = true: başlangıçta click-through aktif.
    // NotchView.updateClickThrough() state'e göre toggle eder.
    newPanel.acceptsMouseMovedEvents = true
    newPanel.ignoresMouseEvents = true
    newPanel.becomesKeyOnlyIfNeeded = false

    // İçerik: SafeAreaFreeHostingView ile safe area SIFIRLANMIŞ
    let wrappedContent = content
      .frame(
        width: panelWidth,
        height: panelHeight,
        alignment: .top
      )

    let newHostingView = SafeAreaFreeHostingView(
      rootView: wrappedContent
    )
    newHostingView.frame = NSRect(
      x: 0, y: 0, width: panelWidth, height: panelHeight
    )
    newHostingView.autoresizingMask = []

    // Wrapper view — panel küçüldüğünde hosting view'ı klipler
    let wrapper = NSView(
      frame: NSRect(
        x: 0, y: 0, width: panelWidth, height: panelHeight
      )
    )
    wrapper.wantsLayer = true
    wrapper.layer?.masksToBounds = true
    wrapper.addSubview(newHostingView)
    newPanel.contentView = wrapper

    // Pencereyi ekranın üst ortasına konumlandır
    // NotchPanel.constrainFrameRect override sayesinde macOS
    // pencereyi aşağı itemez — tam istenen konuma oturur.
    let panelX = screen.frame.midX - panelWidth / 2
    let panelY = screen.frame.maxY - panelHeight
    newPanel.setFrame(
      NSRect(
        x: panelX, y: panelY,
        width: panelWidth, height: panelHeight
      ),
      display: false
    )

    newPanel.orderFrontRegardless()
    self.panel = newPanel
    self.hostingView = newHostingView
  }

  /// Mouse event'lerini geçir/yakala toggle'ı.
  /// true = pencere tıklamaları yakalar (notch açıkken).
  /// false = tıklamalar altındaki uygulamalara geçer (notch kapalıyken).
  var acceptsClicks: Bool {
    get { !(panel?.ignoresMouseEvents ?? true) }
    set { panel?.ignoresMouseEvents = !newValue }
  }

  /// Panel frame'ini duruma göre güncelle.
  ///
  /// Click-through için kritik: `ignoresMouseEvents` macOS'ta yüksek
  /// seviyeli floating panel'larda güvenilir çalışmıyor. Bunun yerine
  /// panel fiziksel olarak küçültülür — altındaki hiçbir şeyi engellemez.
  ///
  /// Hosting view sabit boyutta kalır (SwiftUI layout bozulmasın),
  /// wrapper view panel'e göre klipler, hosting view top-center hizalı
  /// olarak reposition edilir.
  @MainActor
  func updatePanelFrame(width: CGFloat, height: CGFloat) {
    guard let screen = screenDetector.builtinScreen,
          let panel = panel,
          let wrapper = panel.contentView,
          let hostingView = hostingView else { return }

    let fullWidth = Self.openSize.width
    let fullHeight = Self.openSize.height + Self.shadowPadding

    let panelX = screen.frame.midX - width / 2
    let panelY = screen.frame.maxY - height

    panel.setFrame(
      NSRect(
        x: panelX, y: panelY,
        width: width, height: height
      ),
      display: false
    )

    // Wrapper panel'i doldurur
    wrapper.frame = NSRect(
      x: 0, y: 0, width: width, height: height
    )

    // Hosting view: sabit boyut, top-center hizalı
    // macOS koordinatları: origin sol-alt
    hostingView.frame = NSRect(
      x: (width - fullWidth) / 2,
      y: height - fullHeight,
      width: fullWidth,
      height: fullHeight
    )
  }

  /// Pencereyi gizle
  func hide() {
    panel?.orderOut(nil)
  }

  /// Pencereyi göster
  func show() {
    panel?.orderFrontRegardless()
  }

  /// Window level'ı geçici olarak yükselt (bildirim modu)
  func temporarilyElevate(duration: TimeInterval = 5.0) {
    let originalLevel = windowLevel
    windowLevel = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 8
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      [weak self] in
      self?.windowLevel = originalLevel
    }
  }
}
