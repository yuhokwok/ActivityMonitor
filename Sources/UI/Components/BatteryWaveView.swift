import SwiftUI
import UIKit

/// Decodes frames on demand and retains only a small number of images in memory.
struct BatterySequenceView: View {
    let level: Double?
    let reduceMotion: Bool
    private let frameRate = 30.0
    @State private var animationStart = Date.timeIntervalSinceReferenceDate

    private var sequenceName: String? {
        guard let level else { return nil }
        if level < 0.20 { return "batteryLow" }
        if level > 0.80 { return "batteryHigh" }
        return "batteryMedium"
    }

    var body: some View {
        Group {
            if let sequenceName {
                TimelineView(.animation(minimumInterval: 1 / frameRate, paused: reduceMotion)) { timeline in
                    let loopFrames = BatteryFrameCache.shared.frames(for: sequenceName)
                    let entryFrames = BatteryFrameCache.shared.frames(for: "\(sequenceName)FloatUp")
                    let elapsed = max(0, timeline.date.timeIntervalSinceReferenceDate - animationStart)
                    let entryDuration = Double(entryFrames.count) / frameRate
                    let image: UIImage? = {
                        if !reduceMotion && !entryFrames.isEmpty && elapsed < entryDuration {
                            return BatteryFrameCache.shared.image(at: min(Int(elapsed * frameRate), entryFrames.count - 1), in: "\(sequenceName)FloatUp")
                        }
                        guard !loopFrames.isEmpty else { return nil }
                        let index = reduceMotion ? min(loopFrames.count - 1, loopFrames.count / 3) : Int(max(0, elapsed - entryDuration) * frameRate) % loopFrames.count
                        return BatteryFrameCache.shared.image(at: index, in: sequenceName)
                    }()
                    if let image {
                        Image(uiImage: image).resizable().interpolation(.high).scaledToFit().accessibilityHidden(true)
                    } else {
                        Image("batteryFrame").resizable().scaledToFit().accessibilityHidden(true)
                    }
                }
            } else {
                Image("batteryFrame").resizable().scaledToFit().accessibilityHidden(true)
            }
        }
        .frame(width: 82, height: 154)
        .accessibilityHidden(true)
        .onAppear { animationStart = Date.timeIntervalSinceReferenceDate }
        .onChange(of: sequenceName) { _, _ in animationStart = Date.timeIntervalSinceReferenceDate }
    }
}

private final class BatteryFrameCache {
    static let shared = BatteryFrameCache()
    private let cache = NSCache<NSString, UIImage>()
    private var frameURLs: [String: [URL]] = [:]
    private let lock = NSLock()

    private init() { cache.countLimit = 14 }

    func frames(for sequence: String) -> [URL] {
        lock.lock(); defer { lock.unlock() }
        if let frames = frameURLs[sequence] { return frames }
        let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "BatterySequences/\(sequence)") ?? []
        let sorted = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        frameURLs[sequence] = sorted
        return sorted
    }

    func image(at index: Int, in sequence: String) -> UIImage? {
        let key = "\(sequence)-\(index)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let all = frames(for: sequence)
        guard all.indices.contains(index), let image = UIImage(contentsOfFile: all[index].path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct BatteryWave: Shape {
    var level: Double
    var phase: CGFloat
    var animatableData: CGFloat { get { phase } set { phase = newValue } }
    func path(in rect: CGRect) -> Path {
        let surface = rect.height * (1 - level.clamped(to: 0...1))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: surface))
        for x in stride(from: CGFloat(0), through: rect.width, by: 2) {
            let y = surface + sin((x / max(rect.width, 1) * 2 * .pi * 2.5) + phase) * 9
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct FlowingWave: View {
    let level: Double
    let color: Color
    let phaseOffset: CGFloat
    let reduceMotion: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : CGFloat(timeline.date.timeIntervalSinceReferenceDate * 1.3) + phaseOffset
            BatteryWave(level: level, phase: phase).fill(color)
        }
        .accessibilityHidden(true)
    }
}

struct BatteryWaveField: View {
    let level: Double?
    let reduceMotion: Bool
    private var bandColor: Color {
        guard let level else { return .clear }
        if level < 0.20 { return .red }
        if level > 0.80 { return .monitorGreen }
        return Color(red: 1, green: 0.76, blue: 0.02)
    }
    var body: some View {
        Group {
            if let level {
                ZStack(alignment: .bottom) {
                    FlowingWave(level: min(1, level + 0.07), color: bandColor.opacity(0.32), phaseOffset: 1.8, reduceMotion: reduceMotion)
                    FlowingWave(level: level, color: bandColor.opacity(0.94), phaseOffset: 0, reduceMotion: reduceMotion)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
