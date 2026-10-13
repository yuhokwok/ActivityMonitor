import SwiftUI

/// Deliberately static: WidgetKit controls Live Activity rendering and ignores animation loops.
struct BatteryTank: View {
    let level: Double?

    var body: some View {
        GeometryReader { geometry in
            let bodyHeight = geometry.size.height - 5
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(.white)
                    .frame(width: 9, height: 3)
                    .position(x: geometry.size.width / 2, y: 1.5)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.14))
                    if let level {
                        ZStack(alignment: .bottom) {
                            StaticWave(reversed: true)
                                .fill(Color.monitorGreen.opacity(0.4))
                                .frame(height: max(0, (bodyHeight - 5) * min(1, max(0, level)) + 2))
                            StaticWave(reversed: false)
                                .fill(Color.monitorGreen)
                                .frame(height: max(0, (bodyHeight - 5) * min(1, max(0, level))))
                        }
                        .padding(2.5)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Text("—").foregroundStyle(Color.monitorGreen).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    RoundedRectangle(cornerRadius: 4).stroke(.white, lineWidth: 1.5)
                }
                .frame(height: bodyHeight)
            }
        }
    }
}

struct StaticWave: Shape {
    let reversed: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let wave = min(4, rect.height * 0.2)
        path.move(to: CGPoint(x: 0, y: wave))
        path.addCurve(to: CGPoint(x: rect.maxX, y: wave),
                      control1: CGPoint(x: rect.width * 0.3, y: reversed ? wave * 3 : -wave),
                      control2: CGPoint(x: rect.width * 0.6, y: reversed ? -wave : wave * 3))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
