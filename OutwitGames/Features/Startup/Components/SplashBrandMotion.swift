import CoreGraphics
import Foundation

nonisolated struct SplashBrandMotion {
  static let duration: TimeInterval = 2.4

  private let seconds: CGFloat

  init(progress: CGFloat) {
    seconds = clampUnit(progress) * Self.duration
  }

  var markOpacity: CGFloat { interval(from: 0.65, to: 1.3, easing: easeOut) }
  var markScale: CGFloat { 0.94 + (0.06 * markOpacity) }

  var initialOffsetX: CGFloat { -30 * position }
  var initialOffsetY: CGFloat { -14 * position }
  var initialOpacity: CGFloat { 1 - settle }
  var initialScale: CGFloat { 1 - (0.62 * position) }

  var eyeCoverOpacity: CGFloat { 1 - settle }
  var copyOpacity: CGFloat { copy }
  var copyOffsetY: CGFloat { 12 * (1 - copy) }

  var winkScale: CGFloat {
    let progress = clampUnit((seconds - 1.18) / 0.52)
    guard progress > 0.18, progress < 0.82 else { return 1 }
    if progress <= 0.5 {
      return 1 - (0.92 * easeInOut((progress - 0.18) / 0.32))
    }
    return 0.08 + (0.92 * easeInOut((progress - 0.5) / 0.32))
  }

  private var position: CGFloat {
    interval(from: 0.412, to: 1.15, easing: emphasizedEaseOut)
  }

  private var settle: CGFloat {
    interval(from: 1.72, to: 1.94, easing: easeOut)
  }

  private var copy: CGFloat {
    interval(from: 1.98, to: Self.duration, easing: easeOut)
  }

  private func interval(
    from start: CGFloat,
    to end: CGFloat,
    easing: (CGFloat) -> CGFloat
  ) -> CGFloat {
    easing(clampUnit((seconds - start) / (end - start)))
  }

  private func emphasizedEaseOut(_ value: CGFloat) -> CGFloat {
    let inverse = 1 - value
    return (3 * inverse * inverse * value * 0.8) + (3 * inverse * value * value)
      + (value * value * value)
  }

  private func easeOut(_ value: CGFloat) -> CGFloat {
    1 - ((1 - value) * (1 - value) * (1 - value))
  }

  private func easeInOut(_ value: CGFloat) -> CGFloat {
    value < 0.5
      ? 4 * value * value * value
      : 1 - ((-2 * value + 2) * (-2 * value + 2) * (-2 * value + 2) / 2)
  }
}

private nonisolated func clampUnit(_ value: CGFloat) -> CGFloat {
  min(max(value, 0), 1)
}
