import MonitorDomain
import SwiftUI

struct HalfGauge: View {
    let value: Double?
    let maximum: Double
    let displayValue: String
    let label: LocalizedStringKey
    let tint: Color
    var artworkHueRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: Double { guard let value else { return 0 }; return (value / maximum).clamped(to: 0...1) }

    var body: some View {
        VStack(spacing: 18) {
            Text(displayValue)
                .font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.58)
                .modifier(NumberJump(value: displayValue))
            GeometryReader { proxy in
                let gaugeHeight = min(proxy.size.height, max(0, proxy.size.width - 36) / 2.078)
                ZStack(alignment: .bottom) {
                    Image("dashboardHalfYellow").resizable().renderingMode(.original)
                        .aspectRatio(2.078, contentMode: .fit)
                        .frame(width: gaugeHeight * 2.078, height: gaugeHeight)
                    if value != nil {
                        Image("dashboardPinYellow").resizable().renderingMode(.original)
                            .frame(width: max(3, gaugeHeight * 0.045), height: gaugeHeight * 0.77)
                            .rotationEffect(.degrees(-90 + fraction * 180), anchor: .bottom)
                            .offset(y: -gaugeHeight * 0.015)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.72), value: value)
                    }
                }
                .hueRotation(.degrees(artworkHueRotation))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 88)
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.72)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(displayValue))
    }
}

struct NetworkRing: View {
    let primaryValue: String
    let secondaryValue: String?
    let label: LocalizedStringKey
    let tint: Color
    let symbol: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().stroke(tint, lineWidth: 2.5)
                HStack {
                    Circle().fill(tint).frame(width: 9, height: 9).offset(x: -4)
                    Spacer(minLength: 0)
                    Circle().fill(tint).frame(width: 9, height: 9).offset(x: 4)
                }
                VStack(spacing: 1) {
                    if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(tint) }
                    Text(primaryValue).font(.system(size: side * 0.22, weight: .light, design: .rounded)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.55).foregroundStyle(.white)
                        .modifier(NumberJump(value: primaryValue))
                    if let secondaryValue {
                        Rectangle().fill(tint.opacity(0.75)).frame(height: 1).padding(.horizontal, side * 0.20)
                        Text(secondaryValue).font(.system(size: side * 0.22, weight: .light, design: .rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.55).foregroundStyle(.white)
                            .modifier(NumberJump(value: secondaryValue))
                        Image(systemName: symbol == "arrow.up" ? "arrow.down" : "arrow.up").font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
                    } else {
                        Text(label).font(.system(size: 11)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .padding(.vertical, side * 0.14)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(secondaryValue.map { String(format: String(localized: "accessibility.paired_values"), primaryValue, $0) } ?? primaryValue)
    }
}

struct ThermometerGauge: View {
    let state: ThermalStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedFill: CGFloat = 0

    private var fillLevel: CGFloat? {
        switch state {
        case .nominal: 0.50
        case .fair: 0.70
        case .serious: 0.85
        case .critical: 1.0
        case .unknown: nil
        }
    }

    private var stateColor: Color {
        switch state {
        case .nominal: .monitorGreen
        case .fair: .monitorYellow
        case .serious: .orange
        case .critical: .red
        case .unknown: Color.white.opacity(0.28)
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(state.localizedName)
                .font(.system(size: 30, weight: .light, design: .rounded))
                .foregroundStyle(stateColor)
                .lineLimit(1).minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity)
            ZStack {
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(LinearGradient(colors: [stateColor.opacity(0.76), stateColor], startPoint: .top, endPoint: .bottom))
                        .frame(width: 8, height: 58 * displayedFill)
                        .padding(.bottom, 4)
                        .opacity(fillLevel == nil ? 0 : 1)
                }
                .frame(width: 16, height: 68)
                .overlay(Capsule().stroke(Color.white.opacity(0.88), lineWidth: 1.5))
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(fillLevel == nil ? Color.black : stateColor)
                        .frame(width: 23, height: 23)
                        .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 1.5))
                        .offset(y: 6)
                }
                .frame(width: 30, height: 82)
            }
            .frame(height: 88)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.85), value: state)
            Text("hardware.thermal_status")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.72))
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("hardware.thermal_status"))
        .accessibilityValue(Text(state.localizedName))
        .onAppear { updateFill() }
        .onChange(of: state) { _, _ in updateFill() }
    }

    private func updateFill() {
        // Decorative proportions only: iOS reports categories, not Celsius values.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.85)) {
            displayedFill = fillLevel ?? 0
        }
    }
}

/// One small hop when the displayed number changes, without moving its layout slot.
struct NumberJump: ViewModifier {
    let value: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let motionDisabled = reduceMotion
        return content
            .contentTransition(.identity)
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: value) { view, lift in
                view.offset(y: motionDisabled ? 0 : lift)
            } keyframes: { _ in
                CubicKeyframe(-4, duration: 0.12)
                SpringKeyframe(0, duration: 0.38, spring: .smooth)
            }
    }
}
