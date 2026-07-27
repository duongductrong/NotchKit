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
            name: "Ink & Shadow",
            icon: "paintpalette",
            mission: "Pitch-black hardware blending vs warm paper translucent ink.",
            parameters: ["ink: Color", "shadowColor: Color", "shadowRadius: CGFloat"],
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
            configuration.collapsedWidth = .wrapCutout(reserve: 44)
            return configuration
        }(),
        motion: .playful,
        style: .standard,
        collapsedLeading: { _ in AnyView(MorphInspectorLeading()) },
        collapsedTrailing: { _ in AnyView(MorphInspectorTrailing()) },
        expanded: { model in AnyView(MorphInspectorPanel(model: model)) }
    )
}

// MARK: - Collapsed Leading 6x6 Pixel Matrix

private struct MorphInspectorLeading: View {
    @State private var pulsePhase = false

    // 6x6 pixel opacity map
    private let matrix: [[Double]] = [
        [0.9, 0.9, 0.9, 0.9, 0.9, 0.9],
        [0.9, 0.2, 0.2, 0.2, 0.2, 0.9],
        [0.9, 0.2, 0.8, 0.8, 0.2, 0.9],
        [0.9, 0.2, 0.8, 0.8, 0.2, 0.9],
        [0.7, 0.9, 0.2, 0.2, 0.9, 0.7],
        [0.3, 0.7, 0.9, 0.9, 0.7, 0.3]
    ]

    var body: some View {
        VStack(spacing: 0.8) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0.8) {
                    ForEach(0..<6, id: \.self) { col in
                        let active = isPixelActive(row: row, col: col)
                        RoundedRectangle(cornerRadius: 0.4)
                            .fill(
                                active
                                    ? Color(red: 0.65, green: 0.95, blue: 0.2)
                                    : Color.white.opacity(matrix[row][col])
                            )
                            .frame(width: 1.5, height: 1.5)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
    }

    private func isPixelActive(row: Int, col: Int) -> Bool {
        if pulsePhase {
            return (row == 2 && col == 2) || (row == 3 && col == 3)
        } else {
            return (row == 2 && col == 3) || (row == 3 && col == 2)
        }
    }
}

// MARK: - Collapsed Trailing Animated Widget

private struct MorphInspectorTrailing: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            Text("7")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.9))

            // Animated pixel bars with green/yellow lighting
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.65, green: 0.95, blue: 0.2), // Lime Green
                                    Color(red: 0.98, green: 0.85, blue: 0.15) // Amber Yellow
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2.5, height: isAnimating ? 12 : 5)
                        .opacity(isAnimating ? 1.0 : 0.45)
                        .shadow(color: Color(red: 0.7, green: 0.95, blue: 0.2).opacity(0.6), radius: 2)
                        .animation(
                            .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 12, alignment: .center)
        }
        .onAppear {
            isAnimating = true
        }
    }
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
                    .foregroundStyle(.primary)

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
                                    .fill(activeElement.id == elem.id ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(activeElement.id == elem.id ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
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

            // Detailed Card (Scrollable when height limit reached)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: activeElement.icon)
                                    .foregroundStyle(.primary)
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
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundStyle(.secondary)
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
                                    .foregroundStyle(.white.opacity(0.9))
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
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.bottom, 32)
    }
}
