import NotchKit
import SwiftUI

// MARK: - Morph Element Model

public struct MorphElement: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let icon: String
    public let mission: String
    public let parameters: [String]
    public let details: String

    public static let all: [MorphElement] = [
        MorphElement(
            id: "silhouette",
            name: "NotchShape",
            icon: "square.on.square.intersection",
            mission: "Single morphing surface with top concave and bottom convex corner radii.",
            parameters: ["topRadius: CGFloat", "bottomRadius: CGFloat", "width: CGFloat", "height: CGFloat"],
            details: "Interpolates 4 numbers on one continuous outline. Eliminates cross-fade switching artifacts."
        ),
        MorphElement(
            id: "cutout",
            name: "Cutout Bridge",
            icon: "camera.aperture",
            mission: "Shields physical camera housing and calculates safe gutter spacing.",
            parameters: ["cutoutWidth: CGFloat", "gutterWidth: CGFloat", "pillHeight: CGFloat"],
            details: "Reserves cutout space on notched displays while keeping content flush."
        ),
        MorphElement(
            id: "motion",
            name: "Spring Engine",
            icon: "waveform.path",
            mission: "Drives single-surface spring morphing and content reveal delays.",
            parameters: ["response: Double", "dampingFraction: Double", "contentRevealDelay: Double"],
            details: "Choreographs shape morphing with delayed content opacity transitions."
        ),
        MorphElement(
            id: "style",
            name: "Ink & Hairline",
            icon: "paintpalette",
            mission: "Pitch-black hardware blending vs warm paper translucent ink.",
            parameters: ["ink: Color", "hairline: Color", "shadow: ShadowStyle"],
            details: "Matches OLED black bezels or applies distinct card styling."
        ),
        MorphElement(
            id: "pointer",
            name: "Pointer Hysteresis",
            icon: "cursorarrow.motionlines",
            mission: "Dual-delay pointer gate preventing accidental open and edge jitter.",
            parameters: ["hoverOpenDelay: 0.15s", "hoverCancelGrace: 0.10s", "interactiveRect: CGRect"],
            details: "Filters fast cursor transits and absorbs boundary tremor."
        ),
        MorphElement(
            id: "reserve",
            name: "Top Reserve",
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            mission: "Clears hardware cutout and calculates taper-aware content insets.",
            parameters: ["topReserve: Policy", "contentInsets: EdgeInsets"],
            details: "Pads expanded content below the cutout and inside side-wall tapers."
        ),
        MorphElement(
            id: "bars",
            name: "Activity Bars",
            icon: "chart.bar.fill",
            mission: "Zero-CPU CoreAnimation layer rendering without main-thread cost.",
            parameters: ["barCount: Int", "period: Double", "stagger: Double", "tint: Color"],
            details: "CAShapeLayer scale animations offloaded to the render server."
        )
    ]
}

// MARK: - Preset

extension IslandPreset {
    static let morphInspector = IslandPreset(
        id: "morph-inspector",
        name: "Morph Inspector",
        configuration: {
            var configuration = NotchConfiguration.standard
            configuration.expandedSize = CGSize(width: 580, height: 320)
            configuration.collapsedWidth = .wrapCutout(reserve: 50)
            return configuration
        }(),
        motion: .playful,
        style: .standard,
        collapsedLeading: { _ in
            AnyView(
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    Text("Inspector")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            )
        },
        collapsedTrailing: { _ in
            AnyView(
                Text("7 Elements")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cyan)
            )
        },
        expanded: { model in AnyView(MorphInspectorPanel(model: model)) }
    )
}

// MARK: - Expanded Panel View

private struct MorphInspectorPanel: View {
    let model: DemoModel
    @State private var selectedElement: MorphElement = MorphElement.all[0]
    @State private var hoveredElement: MorphElement?

    private var activeElement: MorphElement {
        hoveredElement ?? selectedElement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label("MorphSection Inspector", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.cyan)

                Spacer()

                Text("Hover or tap an element")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // Element Grid / Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MorphElement.all) { elem in
                        Button {
                            selectedElement = elem
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: elem.icon)
                                    .font(.system(size: 10))
                                Text(elem.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(activeElement.id == elem.id ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(activeElement.id == elem.id ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            if isHovered {
                                hoveredElement = elem
                            } else if hoveredElement?.id == elem.id {
                                hoveredElement = nil
                            }
                        }
                    }
                }
            }

            // Detailed Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: activeElement.icon)
                                .foregroundStyle(Color.cyan)
                            Text(activeElement.name)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(activeElement.mission)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Text("MISSION")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.cyan.opacity(0.2)))
                        .foregroundStyle(Color.cyan)
                }

                Divider().background(Color.white.opacity(0.1))

                // Arguments & Parameters
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments & Parameters:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(activeElement.parameters, id: \.self) { param in
                            Text(param)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)))
                                .foregroundStyle(Color.cyan.opacity(0.9))
                        }
                    }
                }

                Text(activeElement.details)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )

            Spacer(minLength: 0)
        }
    }
}
