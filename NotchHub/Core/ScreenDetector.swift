import AppKit

/// macOS ekranında notch varlığını ve boyutunu tespit eder
final class ScreenDetector {
  static let shared = ScreenDetector()

  /// Dahili (built-in) ekranı döndürür
  var builtinScreen: NSScreen? {
    NSScreen.screens.first { screen in
      guard let id = screen.deviceDescription[
        NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
      else { return false }
      return CGDisplayIsBuiltin(id) != 0
    }
  }

  /// Ekranda notch var mı?
  var hasNotch: Bool {
    guard let screen = builtinScreen else { return false }
    if #available(macOS 12.0, *) {
      return screen.auxiliaryTopLeftArea != nil
        && screen.auxiliaryTopRightArea != nil
    }
    return false
  }

  /// Notch boyutu (genişlik x yükseklik)
  var notchSize: CGSize? {
    guard let screen = builtinScreen,
          #available(macOS 12.0, *),
          let left = screen.auxiliaryTopLeftArea,
          let right = screen.auxiliaryTopRightArea
    else { return nil }
    let width = screen.frame.width - left.width - right.width
    let height = screen.safeAreaInsets.top
    return CGSize(width: width, height: height)
  }

  /// Notch merkez noktası (ekran koordinatlarında)
  var notchCenter: CGPoint? {
    guard let screen = builtinScreen else { return nil }
    return CGPoint(
      x: screen.frame.midX,
      y: screen.frame.maxY - (screen.safeAreaInsets.top / 2)
    )
  }

  /// Notch alanının tam frame'i
  var notchFrame: NSRect? {
    guard let screen = builtinScreen,
          let size = notchSize
    else { return nil }
    let x = screen.frame.midX - (size.width / 2)
    let y = screen.frame.maxY - size.height
    return NSRect(x: x, y: y, width: size.width, height: size.height)
  }
}
