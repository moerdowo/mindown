import SwiftUI

/// Classic Winamp-inspired colour palette.
enum WinampPalette {
    static let windowBackground = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let panelDark        = Color(red: 0.13, green: 0.13, blue: 0.16)
    static let panelMid         = Color(red: 0.22, green: 0.22, blue: 0.26)
    static let panelLight       = Color(red: 0.34, green: 0.34, blue: 0.38)
    static let bevelLight       = Color(red: 0.55, green: 0.55, blue: 0.60)
    static let bevelDark        = Color(red: 0.05, green: 0.05, blue: 0.06)

    static let lcdBackground    = Color(red: 0.02, green: 0.04, blue: 0.02)
    static let lcdGreen         = Color(red: 0.10, green: 1.00, blue: 0.40)
    static let lcdGreenDim      = Color(red: 0.10, green: 0.55, blue: 0.25)
    static let lcdAmber         = Color(red: 1.00, green: 0.70, blue: 0.10)
    static let lcdRed           = Color(red: 1.00, green: 0.25, blue: 0.20)

    static let titlebarTop      = Color(red: 0.18, green: 0.20, blue: 0.40)
    static let titlebarBottom   = Color(red: 0.06, green: 0.07, blue: 0.18)

    static let textBright       = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let textDim          = Color(red: 0.65, green: 0.65, blue: 0.70)
    static let accent           = Color(red: 0.20, green: 0.70, blue: 1.00)
}

/// LCD-style monospaced text used throughout the UI for that classic Winamp feel.
struct LCDText: View {
    let text: String
    var color: Color = WinampPalette.lcdGreen
    var size: CGFloat = 11
    var weight: Font.Weight = .bold
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.55), radius: 1.0, x: 0, y: 0)
            .lineLimit(1)
    }
}

/// Beveled panel like the classic Winamp main-window chrome (light top/left, dark bottom/right).
struct BeveledPanel<Content: View>: View {
    var inset: Bool = false
    var fill: Color = WinampPalette.panelMid
    @ViewBuilder var content: () -> Content

    var body: some View {
        let topLeft     = inset ? WinampPalette.bevelDark  : WinampPalette.bevelLight
        let bottomRight = inset ? WinampPalette.bevelLight : WinampPalette.bevelDark

        ZStack {
            fill
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: 10000, y: 0))
            }
        }
        .overlay(
            ZStack {
                Rectangle()
                    .stroke(topLeft, lineWidth: 1)
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle().frame(height: 1)
                            HStack(spacing: 0) {
                                Rectangle().frame(width: 1)
                                Spacer()
                            }
                            Spacer()
                        }
                    )
                Rectangle()
                    .stroke(bottomRight, lineWidth: 1)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer()
                            HStack(spacing: 0) {
                                Spacer()
                                Rectangle().frame(width: 1)
                            }
                            Rectangle().frame(height: 1)
                        }
                    )
            }
        )
        .overlay(content().padding(6))
    }
}

/// LCD readout container: dark recessed panel with green text.
struct LCDPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            WinampPalette.lcdBackground
            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .overlay(
            Rectangle()
                .stroke(WinampPalette.bevelDark, lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .stroke(WinampPalette.bevelLight.opacity(0.4), lineWidth: 1)
                .padding(1)
        )
    }
}

/// Beveled push-button. Switches bevel direction while pressed for a tactile feel.
struct WinampButtonStyle: ButtonStyle {
    var tint: Color = WinampPalette.panelMid
    var labelColor: Color = WinampPalette.textBright
    var minWidth: CGFloat = 64
    var height: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(labelColor)
            .frame(minWidth: minWidth)
            .frame(height: height)
            .padding(.horizontal, 10)
            .background(
                ZStack {
                    LinearGradient(
                        colors: pressed
                            ? [tint.opacity(0.7), tint]
                            : [tint, tint.opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            )
            .overlay(BevelOverlay(inset: pressed))
            .offset(y: pressed ? 1 : 0)
            .contentShape(Rectangle())
    }
}

private struct BevelOverlay: View {
    var inset: Bool
    var body: some View {
        let topLeft     = inset ? WinampPalette.bevelDark  : WinampPalette.bevelLight
        let bottomRight = inset ? WinampPalette.bevelLight : WinampPalette.bevelDark
        ZStack {
            Rectangle()
                .stroke(topLeft, lineWidth: 1)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().frame(height: 1)
                        HStack(spacing: 0) {
                            Rectangle().frame(width: 1)
                            Spacer()
                        }
                        Spacer()
                    }
                )
            Rectangle()
                .stroke(bottomRight, lineWidth: 1)
                .mask(
                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            Spacer()
                            Rectangle().frame(width: 1)
                        }
                        Rectangle().frame(height: 1)
                    }
                )
        }
    }
}

/// Custom title bar drawn inside the window, styled like the classic Winamp blue gradient.
struct WinampTitleBar: View {
    var title: String
    var onSettings: () -> Void
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WinampPalette.titlebarTop, WinampPalette.titlebarBottom],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(i.isMultiple(of: 2) ? WinampPalette.bevelLight.opacity(0.6) : WinampPalette.bevelDark.opacity(0.7))
                        .frame(width: 2, height: 2)
                }
                LCDText(text: title, color: WinampPalette.lcdGreen, size: 10)
                Spacer()
                Button(action: onSettings) {
                    LCDText(text: "PREFS", color: WinampPalette.lcdAmber, size: 10)
                }
                .buttonStyle(WinampButtonStyle(minWidth: 56, height: 16))
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 22)
        .overlay(BevelOverlay(inset: false))
    }
}

/// Small LED dot used as a status indicator.
struct LED: View {
    var color: Color
    var on: Bool = true
    var body: some View {
        Circle()
            .fill(on ? color : color.opacity(0.2))
            .overlay(
                Circle().stroke(WinampPalette.bevelDark, lineWidth: 0.5)
            )
            .shadow(color: on ? color.opacity(0.8) : .clear, radius: 2)
            .frame(width: 6, height: 6)
    }
}

/// Custom progress bar in the Winamp visualizer style: vertical bars marching across.
struct WinampProgressBar: View {
    var progress: Double // 0.0 ... 1.0
    var color: Color = WinampPalette.lcdGreen
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                WinampPalette.lcdBackground
                let count = max(1, Int(geo.size.width / 4))
                let filled = Int(Double(count) * max(0, min(1, progress)))
                HStack(spacing: 1) {
                    ForEach(0..<count, id: \.self) { i in
                        Rectangle()
                            .fill(i < filled ? color : color.opacity(0.12))
                            .frame(width: 3)
                    }
                }
                .padding(.horizontal, 1)
            }
            .overlay(
                Rectangle().stroke(WinampPalette.bevelDark, lineWidth: 1)
            )
        }
    }
}
