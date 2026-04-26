import SwiftUI

enum UrbanTheme {
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.12)
    static let panel = Color(red: 0.14, green: 0.15, blue: 0.18)
    static let panelSoft = Color(red: 0.18, green: 0.19, blue: 0.22)
    static let line = Color.white.opacity(0.07)
    static let mist = Color.white.opacity(0.68)
    static let frost = Color.white.opacity(0.46)
    static let accent = Color(red: 0.97, green: 0.58, blue: 0.20)
    static let accentSoft = Color(red: 0.92, green: 0.43, blue: 0.27)
    static let danger = Color(red: 0.92, green: 0.39, blue: 0.33)
    static let success = Color(red: 0.25, green: 0.80, blue: 0.56)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.09, blue: 0.11),
            Color(red: 0.13, green: 0.14, blue: 0.17)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension FuelType {
    var urbanAccent: Color {
        switch self {
        case .gazole:
            return Color(red: 0.95, green: 0.64, blue: 0.19)
        case .sp95:
            return Color(red: 0.16, green: 0.39, blue: 0.24)
        case .sp98:
            return Color(red: 0.12, green: 0.33, blue: 0.20)
        case .e10:
            return Color(red: 0.56, green: 0.82, blue: 0.31)
        case .e85:
            return Color(red: 0.16, green: 0.27, blue: 0.56)
        case .gplc:
            return Color(red: 0.48, green: 0.50, blue: 0.56)
        }
    }
}

struct UrbanCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(UrbanTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(UrbanTheme.line, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func urbanCard() -> some View {
        modifier(UrbanCardModifier())
    }
}

struct UrbanSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(UrbanTheme.frost)
                .tracking(0.8)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UrbanTheme.frost)
            }
        }
    }
}

struct UrbanMetricChip: View {
    let text: String
    var tint: Color = UrbanTheme.panelSoft

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(UrbanTheme.mist)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.92))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(UrbanTheme.line, lineWidth: 1)
                    )
            )
    }
}

struct UrbanFloatingButtonStyle: ButtonStyle {
    var tint: Color = UrbanTheme.panel
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(configuration.isPressed ? tint.opacity(0.72) : tint.opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct UrbanCTAButtonStyle: ButtonStyle {
    var tint: Color = UrbanTheme.accent
    var foreground: Color = Color.black.opacity(0.88)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(configuration.isPressed ? tint.opacity(0.84) : tint)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct UrbanGhostButtonStyle: ButtonStyle {
    var border: Color = UrbanTheme.line

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(configuration.isPressed ? UrbanTheme.panelSoft : UrbanTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
