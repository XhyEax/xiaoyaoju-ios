// Views/ShakeDetector.swift
// CoreMotion accelerometer-based shake detection for SwiftUI.
import SwiftUI
import CoreMotion
import AudioToolbox
import UIKit

// MARK: - Haptics

enum Haptics {
    /// Strong, obvious shake feedback (WeChat-style):
    /// crisp heavy Taptic impact + the classic long system vibration.
    @MainActor static func shake() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)

        // Classic strong buzz — the unmistakable "摇一摇" feel.
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        // Second crisp tap shortly after for a pronounced double-pulse.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let again = UIImpactFeedbackGenerator(style: .rigid)
            again.impactOccurred(intensity: 1.0)
        }
    }

    /// Completion alert: two consecutive strong vibrations (起卦完成提醒).
    @MainActor static func complete() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        let notify = UINotificationFeedbackGenerator()
        notify.notificationOccurred(.success)

        // Second buzz to form a clear "double" alert.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred(intensity: 1.0)
        }
    }
}

@MainActor
@Observable
final class ShakeDetector {
    /// Acceleration magnitude (in g) above which a movement counts as a shake.
    var threshold: Double = 2.3
    /// Minimum seconds between two accepted shakes (debounce).
    var cooldown: TimeInterval = 0.6

    private let manager = CMMotionManager()
    private var lastShake: Date = .distantPast
    private var onShake: (() -> Void)?

    /// Begin listening. Call `stop()` when leaving the view.
    func start(onShake: @escaping () -> Void) {
        self.onShake = onShake
        // 在 Mac 上运行（Designed for iPad / Catalyst）无加速度计，CoreMotion 不可靠，跳过以避免崩溃
        if ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp { return }
        guard manager.isAccelerometerAvailable else { return }
        manager.accelerometerUpdateInterval = 1.0 / 50.0   // 50 Hz
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            // Total acceleration magnitude; ~1g at rest, spikes when shaken.
            let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if magnitude > self.threshold {
                let now = Date()
                if now.timeIntervalSince(self.lastShake) > self.cooldown {
                    self.lastShake = now
                    self.onShake?()
                }
            }
        }
    }

    func stop() {
        if manager.isAccelerometerActive {
            manager.stopAccelerometerUpdates()
        }
    }

    deinit {
        manager.stopAccelerometerUpdates()
    }
}

private struct ShakeDetectorModifier: ViewModifier {
    let action: () -> Void
    @State private var detector = ShakeDetector()

    func body(content: Content) -> some View {
        content
            .onAppear { detector.start(onShake: action) }
            .onDisappear { detector.stop() }
    }
}

extension View {
    /// Runs `action` whenever the device is shaken (CoreMotion accelerometer).
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetectorModifier(action: action))
    }
}
