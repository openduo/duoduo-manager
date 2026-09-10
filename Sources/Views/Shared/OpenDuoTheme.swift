import AppKit
import SwiftUI

// The OpenDuo design system, translated to SwiftUI.
//
// This file is the single visual source for Manager. Views, presentation
// mappers and AppKit chrome all read tokens and primitives from here —
// not from per-surface palettes.
//
// Dark is Manager's only skin, mirroring the source product ("dark is the
// product's only shipped skin"). The system defines a light mirror under
// the same token names; Manager deliberately pins dark on every window
// instead of resolving the OS appearance.
//
// Editorial, sharp, restrained. Hierarchy comes from typography, scale,
// whitespace and hairlines — not from radius, shadows, gradients or blur.
//
// 1. Radius is zero. The only round thing is a status dot.
// 2. No shadows, no glow, no gradients. Separation is a 1px hairline.
//    The two sanctioned shadows are the emerald signal-dot halo and the
//    keyboard focus ring.
// 3. Cyan is earned: the single primary action, live state, one emphasis
//    per scene, and the full stop that ends a page-level headline.
// 4. Emerald marks a live daemon, amber the user's own workspace, rose an
//    error *state*. Nothing else is coloured — the text ramp does the work.

enum OpenDuo {
    // MARK: - Surfaces — near-black, cool, desaturated. No pure #000.

    static let page = Color(hex: 0x07090C)
    static let surface = Color(hex: 0x0B0E12)
    static let surfaceElevated = Color(hex: 0x10151B)
    static let surfacePanel = Color(hex: 0x090C10)
    static let surfaceShade = Color(hex: 0x090B0E)
    static let surfaceInset = Color(hex: 0x0A0E12)
    static let surfaceRaised = Color(hex: 0x0C1116)
    static let surfaceSunken = Color(hex: 0x05070A)

    // MARK: - Brand — electric cyan. A signal, never ambient decoration.

    static let brand = Color(hex: 0x00E5FF)
    static let brandSoft = Color(hex: 0x92F4FF)
    static let brandLight = Color(hex: 0xD5FBFF)
    static let cyan100 = Color(hex: 0xCFFAFE)
    static let cyan200 = Color(hex: 0xA5F3FC)
    static let cyan300 = Color(hex: 0x67E8F9)

    // MARK: - Status — three accents, used sparingly.

    static let ok = Color(hex: 0x6EE7B7)
    static let okSoft = Color(hex: 0xA7F3D0)
    static let attention = Color(hex: 0xFDE68A)
    static let alert = Color(hex: 0xFDA4AF)

    // MARK: - Text ramp — white at descending opacity.

    static let textStrong = Color.white
    static let textPrimary = Color.white.opacity(0.88)
    static let textBody = Color.white.opacity(0.62)
    static let textSecondary = Color.white.opacity(0.56)
    static let textMuted = Color.white.opacity(0.48)
    static let textFaint = Color.white.opacity(0.34)
    static let textGhost = Color.white.opacity(0.28)
    static let textAccent = Color(hex: 0xCFFAFE).opacity(0.86)
    static let textAccentSoft = Color(hex: 0x92F4FF).opacity(0.62)
    static let textKicker = Color(hex: 0xCFFAFE).opacity(0.58)
    static let textKickerNeutral = Color.white.opacity(0.30)

    // MARK: - Hairlines — five border opacities do all the structural work.

    static let borderHairline = Color.white.opacity(0.08)
    static let borderSubtle = Color.white.opacity(0.10)
    static let borderDefault = Color.white.opacity(0.12)
    static let borderInput = Color.white.opacity(0.14)
    static let borderStrong = Color.white.opacity(0.28)
    static let borderBrand = Color(hex: 0x67E8F9).opacity(0.35)

    // MARK: - On-brand ink — type on a full cyan fill, identical in both themes.

    static let onBrandText = Color(hex: 0x061014)
    static let onBrandBody = Color(hex: 0x061014).opacity(0.72)
    static let onBrandKicker = Color(hex: 0x061014).opacity(0.56)

    // MARK: - AppKit mirrors — Host window / popover chrome.

    static let nsPage = NSColor(srgbRed: 7 / 255, green: 9 / 255, blue: 12 / 255, alpha: 1)
    static let nsSurfacePanel = NSColor(srgbRed: 9 / 255, green: 12 / 255, blue: 16 / 255, alpha: 1)
    static let nsAppearance = NSAppearance(named: .darkAqua)

    // MARK: - Motion

    static let durationFast: Double = 0.15

    // MARK: - Event type colour
    //
    // The cyan ramp differentiates flow; emerald and rose are reserved for
    // genuine success/error states. Routine tool use stays neutral.

    static func color(forEventType type: String) -> Color {
        switch type {
        case "agent.tool_use": return textSecondary
        case "agent.tool_result": return ok
        case "agent.result": return cyan300
        case "route.deliver": return cyan200
        case "channel.message": return cyan100
        case "agent.error": return alert
        case "job.spawn", "job.complete", "job.fail": return cyan200
        default: return textMuted
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Typography
//
// System sans carries display and body; system mono marks what is literally
// machine-readable (a path, a command, a state name) or a label that wants
// to read as instrumentation. The wide-tracked uppercase mono label is the
// system's most recognisable typographic move — its legibility comes from
// tracking and casing, never from size.

extension Font {
    /// Section eyebrow / panel header label: tiny mono, uppercase, wide tracking.
    static func odKicker(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// Mono value or machine-readable string.
    static func odMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Display headline: sans, semibold, tight tracking. Never bold.
    static func odDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}

/// A section eyebrow: sentence-case source text, uppercased by the view,
/// mono, wide tracking. Never more than four or five words.
struct ODKicker: View {
    let text: String
    var tint: Color = OpenDuo.textKickerNeutral
    var size: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.odKicker(size))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

/// The cyan full stop that ends a page-level headline. One per headline.
struct ODBrandStop: View {
    var body: some View {
        Text(".")
            .foregroundStyle(OpenDuo.brand)
    }
}

/// Page-level headline. A trailing period in `text` is stripped and replaced
/// by the cyan brand stop.
struct ODHeadline: View {
    let text: String
    var size: CGFloat = 48

    private var displayText: String {
        text.hasSuffix(".") ? String(text.dropLast()) : text
    }

    var body: some View {
        (
            Text(displayText)
                .foregroundStyle(OpenDuo.textStrong)
            + Text(".")
                .foregroundStyle(OpenDuo.brand)
        )
        .font(.odDisplay(size))
        .tracking(-size * 0.025)
    }
}

// MARK: - Panels
//
// There is no card in the conventional sense: a panel is a 1px frame on a
// flat surface — no radius, no shadow, no elevation — optionally with a mono
// header bar and hairline-separated rows.

/// A panel header bar: mono uppercase label on the panel surface, closed by
/// a bottom hairline.
struct ODPanelHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ODKicker(text: title, tint: OpenDuo.textKickerNeutral)
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(OpenDuo.surfacePanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
        }
    }
}

extension View {
    /// Pin Manager surfaces to the dark OpenDuo plate.
    func odChrome() -> some View {
        preferredColorScheme(.dark)
    }

    /// Flat surface + 1px frame. The hairline "card".
    func odPanel(
        surface: Color = OpenDuo.surface,
        border: Color = OpenDuo.borderDefault
    ) -> some View {
        self
            .background(surface)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
    }

    /// Inset row / code plate: one step inside a panel, closed by hairlines.
    func odInset() -> some View {
        self
            .background(OpenDuo.surfaceInset)
            .overlay(Rectangle().stroke(OpenDuo.borderHairline, lineWidth: 1))
    }

    /// Square text field / editor chrome: inset plate, input hairline, zero radius.
    func odField(horizontal: CGFloat = 8, vertical: CGFloat = 5) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(OpenDuo.surfaceInset)
            .overlay(Rectangle().stroke(OpenDuo.borderInput, lineWidth: 1))
    }

    /// A vertical hairline rule.
    func odVRule() -> some View {
        Rectangle().fill(OpenDuo.borderHairline).frame(width: 1)
    }

    /// A horizontal hairline rule.
    func odHRule() -> some View {
        Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
    }
}

// MARK: - Status markers

/// The live indicator. The one element allowed a glow: the emerald halo.
struct ODSignalDot: View {
    var tint: Color = OpenDuo.ok
    var isLive: Bool = true
    var diameter: CGFloat = 6

    var body: some View {
        Circle()
            .fill(isLive ? tint : OpenDuo.textFaint)
            .frame(width: diameter, height: diameter)
            .shadow(color: isLive ? tint.opacity(0.55) : .clear, radius: isLive ? 2.5 : 0)
            .animation(.easeInOut(duration: OpenDuo.durationFast), value: isLive)
    }
}

/// A square state marker — the non-round sibling of the signal dot.
struct ODStateTick: View {
    var tint: Color
    var size: CGFloat = 6

    var body: some View {
        Rectangle().fill(tint).frame(width: size, height: size)
    }
}

// MARK: - Buttons
//
// Hover is colour only, one step brighter: cyan lightens to brand-light,
// outlines go from border-input to border-strong. Nothing lifts, scales or
// shadows. Disabled drops to text-faint territory.

private struct ODFocusRing: View {
    let isFocused: Bool

    var body: some View {
        Rectangle()
            .stroke(OpenDuo.page, lineWidth: 2)
            .padding(-2)
            .overlay {
                Rectangle()
                    .stroke(OpenDuo.brandSoft, lineWidth: 2)
                    .padding(-4)
            }
            .opacity(isFocused ? 1 : 0)
            .allowsHitTesting(false)
    }
}

/// The primary action: full cyan fill, near-black ink. One per scene.
struct ODPrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10 : 11, weight: .semibold))
            .foregroundStyle(OpenDuo.onBrandText)
            .padding(.horizontal, compact ? 0 : 12)
            .padding(.vertical, compact ? 0 : 6)
            .frame(
                maxWidth: compact ? .infinity : nil,
                maxHeight: compact ? .infinity : nil
            )
            .background(isHovering && isEnabled ? OpenDuo.brandLight : OpenDuo.brand)
            .overlay { ODFocusRing(isFocused: isFocused) }
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: OpenDuo.durationFast), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Secondary action: hairline outline, quiet ink, stronger border on hover.
struct ODOutlineButtonStyle: ButtonStyle {
    var tint: Color = OpenDuo.textSecondary
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isHovering && isEnabled ? OpenDuo.textStrong : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(OpenDuo.surfaceInset)
            .overlay(
                Rectangle().stroke(
                    isHovering && isEnabled ? OpenDuo.borderStrong : OpenDuo.borderInput,
                    lineWidth: 1
                )
            )
            .overlay { ODFocusRing(isFocused: isFocused) }
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: OpenDuo.durationFast), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// A square hairline icon button (22×22) for row-level actions.
struct ODIconButtonStyle: ButtonStyle {
    var tint: Color = OpenDuo.textSecondary
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovering && isEnabled ? OpenDuo.cyan200 : tint)
            .frame(width: 22, height: 22)
            .background(OpenDuo.surfaceInset)
            .overlay(
                Rectangle().stroke(
                    isHovering && isEnabled ? OpenDuo.borderStrong : OpenDuo.borderInput,
                    lineWidth: 1
                )
            )
            .overlay { ODFocusRing(isFocused: isFocused) }
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: OpenDuo.durationFast), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// In-flow cyan text link. No plate, no padding.
struct ODQuietButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isHovering && isEnabled ? OpenDuo.textStrong : OpenDuo.cyan100)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: OpenDuo.durationFast), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

// MARK: - Form controls
//
// The source system defines no Input / Toggle / Tabs. These match Select's
// metrics: square, `--border-input` hairline, zero radius.

/// Hairline segmented control. Selected cell is a surface step, not a capsule.
struct ODSegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let title = options[index].1
                let isSelected = selection == value
                Button {
                    selection = value
                } label: {
                    Text(title)
                        .font(.odMono(10))
                        .foregroundStyle(isSelected ? OpenDuo.textStrong : OpenDuo.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? OpenDuo.surfaceElevated : OpenDuo.surfaceInset)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(OpenDuo.borderHairline)
        .overlay(Rectangle().stroke(OpenDuo.borderInput, lineWidth: 1))
    }
}

/// Square on/off marker. Never a rounded switch.
struct ODToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                Rectangle()
                    .fill(OpenDuo.surfaceInset)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Rectangle().stroke(isOn ? OpenDuo.brand : OpenDuo.borderInput, lineWidth: 1)
                    )
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(OpenDuo.brand)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: OpenDuo.durationFast), value: isOn)
    }
}
