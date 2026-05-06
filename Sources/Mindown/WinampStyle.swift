import SwiftUI

/// Classic Winamp / MINPAW-style colour palette: dark grey chrome,
/// pure-black panel interiors, bright green LCD text.
enum WinampPalette {
    static let windowBackground = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let panelChrome      = Color(red: 0.21, green: 0.21, blue: 0.22)
    static let panelDark        = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let panelMid         = Color(red: 0.32, green: 0.32, blue: 0.33)
    static let panelLight       = Color(red: 0.45, green: 0.45, blue: 0.46)
    static let bevelLight       = Color(red: 0.58, green: 0.58, blue: 0.60)
    static let bevelDark        = Color(red: 0.03, green: 0.03, blue: 0.04)

    static let lcdBackground    = Color.black
    static let lcdGreen         = Color(red: 0.20, green: 1.00, blue: 0.45)
    static let lcdGreenDim      = Color(red: 0.10, green: 0.55, blue: 0.25)
    static let lcdAmber         = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let lcdRed           = Color(red: 1.00, green: 0.30, blue: 0.30)

    static let titlebarTop      = Color(red: 0.32, green: 0.32, blue: 0.34)
    static let titlebarBottom   = Color(red: 0.10, green: 0.10, blue: 0.11)

    static let textBright       = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let textDim          = Color(red: 0.65, green: 0.65, blue: 0.70)
    static let selectionBlue    = Color(red: 0.15, green: 0.30, blue: 0.55)
    static let accent           = Color(red: 0.25, green: 0.70, blue: 1.00)
}

/// LCD-style monospaced text used for every readable label in the UI.
struct LCDText: View {
    let text: String
    var color: Color = WinampPalette.lcdGreen
    var size: CGFloat = 11
    var weight: Font.Weight = .bold
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.45), radius: 0.6, x: 0, y: 0)
            .lineLimit(1)
    }
}

/// 1-pixel inner bevel: light on top/left, dark on bottom/right (or vice versa when inset).
struct BevelOverlay: View {
    var inset: Bool = false
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

/// A solid panel with a 1-pixel bevel matching the MINPAW chrome.
struct BeveledPanel<Content: View>: View {
    var inset: Bool = false
    var fill: Color = WinampPalette.panelChrome
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            fill
            content()
        }
        .overlay(BevelOverlay(inset: inset))
    }
}

/// Slim section title bar — dark grey gradient with a green LCD label and optional
/// trailing controls. This is the `MINPAW`, `MINPAW EQUALIZER`, `MINPAW PLAYLIST`
/// strip seen in the reference image.
struct SectionHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WinampPalette.titlebarTop, WinampPalette.titlebarBottom],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 8) {
                LCDText(text: title, color: WinampPalette.lcdGreen, size: 11)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 20)
        .overlay(BevelOverlay(inset: false))
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// A complete MINPAW-style section: header strip on top, beveled grey chrome
/// around a black inner panel containing the supplied content.
struct SectionPanel<Header: View, Content: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header()
            ZStack {
                WinampPalette.lcdBackground
                content()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .overlay(BevelOverlay(inset: true))
            .padding(4)
        }
        .background(WinampPalette.panelChrome)
        .overlay(BevelOverlay(inset: false))
    }
}

/// LCD readout: black-backed, recessed, green text inside.
struct LCDPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            WinampPalette.lcdBackground
            content()
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
        }
        .overlay(BevelOverlay(inset: true))
    }
}

/// Squared-off, beveled grey button with a 1-pixel black outer border —
/// matches buttons like `EQ`, `PL`, `SHUFFLE`, `ADD`, `REM`, `SEL` in the image.
struct WinampButtonStyle: ButtonStyle {
    var tint: Color = WinampPalette.panelMid
    var labelColor: Color = WinampPalette.textBright
    var minWidth: CGFloat = 38
    var height: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(labelColor)
            .frame(minWidth: minWidth)
            .frame(height: height)
            .padding(.horizontal, 6)
            .background(pressed ? tint.opacity(0.75) : tint)
            .overlay(BevelOverlay(inset: pressed))
            .overlay(Rectangle().stroke(Color.black.opacity(0.85), lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// Tiny LED dot (e.g. used for STEREO/MONO indicators / queue activity).
struct LED: View {
    var color: Color
    var on: Bool = true
    var body: some View {
        Circle()
            .fill(on ? color : color.opacity(0.2))
            .overlay(Circle().stroke(WinampPalette.bevelDark, lineWidth: 0.5))
            .shadow(color: on ? color.opacity(0.7) : .clear, radius: 1.6)
            .frame(width: 6, height: 6)
    }
}

/// Classic Winamp time-slider feel: black recessed track with a green fill
/// rectangle whose width tracks the progress value (0.0 ... 1.0).
struct WinampProgressBar: View {
    var progress: Double
    var color: Color = WinampPalette.lcdGreen
    var body: some View {
        GeometryReader { geo in
            let clamped = CGFloat(max(0, min(1, progress)))
            ZStack(alignment: .leading) {
                Rectangle().fill(WinampPalette.lcdBackground)
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * clamped)
            }
            .overlay(BevelOverlay(inset: true))
        }
    }
}

/// Outer window title bar — dark grey gradient with the title on the left.
/// Pass `onClose` (and optionally `onMinimize` / `onZoom`) to draw fake
/// Windows-style `_ □ X` controls on the right; leave them nil for the main
/// window where the real macOS traffic lights provide those affordances.
struct WindowChromeTitleBar: View {
    var title: String
    var leadingInset: CGFloat = 0
    var onMinimize: (() -> Void)? = nil
    var onZoom: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        // Bottom-anchor the HStack so that, when the parent applies
        // `.ignoresSafeArea(edges: .top)` and the chrome's drawing region
        // grows up into the macOS titlebar safe area, the title and buttons
        // stay anchored at the bottom (visible) edge instead of getting
        // pushed off-screen by the default centered alignment.
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [WinampPalette.titlebarTop, WinampPalette.titlebarBottom],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 4) {
                LCDText(text: title, color: WinampPalette.lcdGreen, size: 12)
                Spacer()
                if let onMinimize {
                    Button(action: onMinimize) { Text("_") }
                        .buttonStyle(WinampButtonStyle(minWidth: 22, height: 16))
                }
                if let onZoom {
                    Button(action: onZoom) { Text("□") }
                        .buttonStyle(WinampButtonStyle(minWidth: 22, height: 16))
                }
                if let onClose {
                    Button(action: onClose) { Text("X") }
                        .buttonStyle(WinampButtonStyle(minWidth: 22, height: 16))
                }
            }
            .padding(.leading, 8 + leadingInset)
            // Trailing padding kept large enough that the rightmost button
            // does not get clipped by the window's rounded top-right corner
            // (~10px radius).
            .padding(.trailing, 18)
            .padding(.bottom, 6)
        }
        .frame(height: 30)
        .overlay(BevelOverlay(inset: false))
    }
}
