import SwiftUI

/// Fiziksel notch köşelerini taklit eden özel şekil
/// Üst köşelerde convex (dışa doğru) kavis, alt köşelerde standart yuvarlama
struct NotchShape: InsettableShape, Animatable {
  var topRadius: CGFloat
  var bottomRadius: CGFloat
  var insetAmount: CGFloat = 0

  func inset(by amount: CGFloat) -> NotchShape {
    var shape = self
    shape.insetAmount += amount
    return shape
  }

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(topRadius, bottomRadius) }
    set {
      topRadius = newValue.first
      bottomRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height
    let tr = min(topRadius, w / 4, h / 4)
    let br = min(bottomRadius, w / 4, h / 4)

    // Üst-sol köşe — convex (dışa kavis)
    path.move(to: CGPoint(x: 0, y: tr))
    path.addQuadCurve(
      to: CGPoint(x: tr, y: 0),
      control: CGPoint(x: 0, y: 0)
    )

    // Üst kenar
    path.addLine(to: CGPoint(x: w - tr, y: 0))

    // Üst-sağ köşe — convex
    path.addQuadCurve(
      to: CGPoint(x: w, y: tr),
      control: CGPoint(x: w, y: 0)
    )

    // Sağ kenar
    path.addLine(to: CGPoint(x: w, y: h - br))

    // Alt-sağ köşe — concave (standart yuvarlama)
    path.addQuadCurve(
      to: CGPoint(x: w - br, y: h),
      control: CGPoint(x: w, y: h)
    )

    // Alt kenar
    path.addLine(to: CGPoint(x: br, y: h))

    // Alt-sol köşe — concave
    path.addQuadCurve(
      to: CGPoint(x: 0, y: h - br),
      control: CGPoint(x: 0, y: h)
    )

    path.closeSubpath()
    return path
  }
}
