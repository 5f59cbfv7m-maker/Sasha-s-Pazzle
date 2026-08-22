import AVFoundation
import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Haptic and audio confirmation for snaps, merges and completion.
///
/// Sounds are synthesised at launch rather than shipped as assets: a handful of
/// decaying sine partials is smaller, needs no licence, and works offline. If
/// audio cannot start for any reason the engine simply switches itself off — a
/// silent game is fine, a crashing one is not.
@MainActor
final class Feedback {
    static let shared = Feedback()

    enum Tone: CaseIterable { case snap, merge, complete }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [Tone: AVAudioPCMBuffer] = [:]
    private var audioReady = false

    private init() {}

    func report(_ outcome: SettleOutcome?, settings: AppSettings) {
        guard let outcome, outcome.didSnap else { return }
        if outcome.didComplete {
            play(.complete, settings: settings)
            impact(.strong, settings: settings)
        } else if outcome.didMerge {
            play(.merge, settings: settings)
            impact(.medium, settings: settings)
        } else {
            play(.snap, settings: settings)
            impact(.light, settings: settings)
        }
    }

    // MARK: - Haptics

    enum Strength { case light, medium, strong }

    func impact(_ strength: Strength, settings: AppSettings) {
        guard settings.hapticsEnabled else { return }
        #if os(macOS)
        // Trackpad haptics; a no-op on hardware without a Force Touch surface.
        let pattern: NSHapticFeedbackManager.FeedbackPattern = switch strength {
        case .light: .alignment
        case .medium: .levelChange
        case .strong: .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        #else
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch strength {
        case .light: .light
        case .medium: .medium
        case .strong: .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    // MARK: - Audio

    func play(_ tone: Tone, settings: AppSettings) {
        guard settings.soundEnabled else { return }
        prepareAudioIfNeeded()
        guard audioReady, let buffer = buffers[tone] else { return }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func prepareAudioIfNeeded() {
        guard !audioReady else { return }
        #if !os(macOS)
        // Ambient: the game never interrupts the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        for tone in Tone.allCases {
            buffers[tone] = Self.synthesize(tone, format: format)
        }
        do {
            try engine.start()
            audioReady = true
        } catch {
            audioReady = false
        }
    }

    /// Additive synthesis: a few partials with exponential decay. Short, dry and
    /// unobtrusive — the opposite of a stock "ding" sample.
    private nonisolated static func synthesize(_ tone: Tone, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        struct Partial { var frequency: Double; var amplitude: Double; var start: Double; var decay: Double }

        let partials: [Partial]
        let duration: Double
        switch tone {
        case .snap:
            duration = 0.16
            partials = [Partial(frequency: 1_180, amplitude: 0.35, start: 0, decay: 42),
                        Partial(frequency: 1_760, amplitude: 0.18, start: 0, decay: 60),
                        Partial(frequency: 520, amplitude: 0.14, start: 0, decay: 34)]
        case .merge:
            duration = 0.5
            partials = [Partial(frequency: 523.25, amplitude: 0.24, start: 0, decay: 9),
                        Partial(frequency: 659.25, amplitude: 0.2, start: 0.05, decay: 9),
                        Partial(frequency: 783.99, amplitude: 0.18, start: 0.1, decay: 9)]
        case .complete:
            duration = 1.5
            partials = [Partial(frequency: 523.25, amplitude: 0.22, start: 0.0, decay: 4),
                        Partial(frequency: 659.25, amplitude: 0.22, start: 0.14, decay: 4),
                        Partial(frequency: 783.99, amplitude: 0.22, start: 0.28, decay: 4),
                        Partial(frequency: 1_046.5, amplitude: 0.26, start: 0.42, decay: 2.6),
                        Partial(frequency: 1_567.98, amplitude: 0.1, start: 0.42, decay: 3.4)]
        }

        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            var sample = 0.0
            for partial in partials where t >= partial.start {
                let local = t - partial.start
                sample += partial.amplitude * sin(2 * .pi * partial.frequency * local)
                    * exp(-local * partial.decay)
            }
            // Short fade-out prevents a click at the buffer edge.
            let fade = min(1, (duration - t) * 40)
            let value = Float(sample * max(0, fade))
            for channel in 0..<Int(format.channelCount) { channels[channel][frame] = value }
        }
        return buffer
    }
}
