import MonitorDomain
import MonitorActivity
import SwiftUI

struct LiveThermometer: View {
    let rawValue: String?
    private var level: CGFloat {
        switch rawValue {
        case "nominal": 0.50
        case "fair": 0.70
        case "serious": 0.85
        case "critical": 1
        default: 0
        }
    }
    private var color: Color {
        switch rawValue {
        case "nominal": .monitorGreen
        case "fair": .monitorYellow
        case "serious": .orange
        case "critical": .red
        default: .gray
        }
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(.white.opacity(0.08)).frame(width: 12, height: 46)
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
            Capsule().fill(color).frame(width: 5, height: 40 * level).padding(.bottom, 3)
            Circle().fill(level > 0 ? color : .black).frame(width: 19, height: 19)
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1)).offset(y: 4)
        }
    }
}

struct HardwareDial: View {
    let fraction: Double?
    var color: Color = .monitorYellow
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width / 2 - 2, size.height - 2)
            let center = CGPoint(x: size.width / 2, y: size.height - 2)
            var sector = Path()
            sector.move(to: center)
            sector.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .zero, clockwise: false)
            sector.closeSubpath()
            context.fill(sector, with: .linearGradient(Gradient(colors: [color.opacity(0.19), color.opacity(0.02)]), startPoint: .zero, endPoint: center))
            var rim = Path()
            rim.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .zero, clockwise: false)
            context.stroke(rim, with: .color(color), lineWidth: 1.3)
            for step in 0...10 {
                let angle = Double(step) / 10 * Double.pi
                let x = center.x - cos(angle) * (radius - 4)
                let y = center.y - sin(angle) * (radius - 4)
                context.fill(Path(ellipseIn: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4)), with: .color(color))
            }
            if let fraction {
                let angle = min(1, max(0, fraction)) * Double.pi
                var needle = Path()
                needle.move(to: center)
                needle.addLine(to: CGPoint(x: center.x - cos(angle) * (radius - 7), y: center.y - sin(angle) * (radius - 7)))
                context.stroke(needle, with: .color(color), lineWidth: 1.3)
            }
            for x in [center.x - radius, center.x, center.x + radius] {
                context.fill(Path(ellipseIn: CGRect(x: x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6)), with: .color(color))
            }
        }
    }
}

struct NetworkDial: View {
    let state: MonitorAttributes.ContentState
    var body: some View {
        ZStack {
            Circle().stroke(Color.monitorCyan, lineWidth: 1.3)
            Rectangle().fill(Color.monitorCyan.opacity(0.06)).frame(height: 37).offset(y: -18)
                .clipShape(Circle())
            HStack {
                Circle().fill(Color.monitorCyan).frame(width: 4, height: 4)
                Spacer()
                Circle().fill(Color.monitorCyan).frame(width: 4, height: 4)
            }
            VStack(spacing: 1) {
                Image(systemName: "arrow.up").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.monitorCyan)
                Text(verbatim: WidgetFormat.rate(state.sentBytesPerSecond))
                    .font(.system(size: 11, weight: .light, design: .rounded)).monospacedDigit()
                Rectangle().fill(Color.monitorCyan.opacity(0.2)).frame(height: 0.5).padding(.horizontal, 8)
                Text(verbatim: WidgetFormat.rate(state.receivedBytesPerSecond))
                    .font(.system(size: 11, weight: .light, design: .rounded)).monospacedDigit()
                Image(systemName: "arrow.down").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.monitorCyan)
            }
            .lineLimit(1).minimumScaleFactor(0.65).padding(.horizontal, 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.upload") + Text(" " + WidgetFormat.rate(state.sentBytesPerSecond)) + Text(". ") + Text("widget.download") + Text(" " + WidgetFormat.rate(state.receivedBytesPerSecond)))
    }
}
