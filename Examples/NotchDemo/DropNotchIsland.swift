import NotchKit
import SwiftUI

// A drag-and-drop shelf. Narrow and tall where Vibe Code is wide and short,
// warm ink where that one is hardware black, playful springs where that one is
// standard. Same library, no shared content code.

private extension NotchBarsStyle {
    /// A single fat bar breathing — a "drop here" heartbeat rather than a meter.
    /// Same component as Vibe Code's four-bar equaliser; only the numbers differ.
    static func beacon(tint: Color) -> NotchBarsStyle {
        NotchBarsStyle(
            levels: [0.45],
            peaks: [1],
            barWidth: 9,
            cornerRadius: 4.5,
            height: 9,
            period: 1.1,
            tint: tint
        )
    }

    static func resting(tint: Color) -> NotchBarsStyle {
        steady([0.45], barWidth: 9, height: 9, tint: tint)
    }
}

// MARK: - Preset

extension IslandPreset {
    static let dropNotch = IslandPreset(
        id: "drop-notch",
        name: "Drop Notch",
        configuration: {
            var configuration = NotchConfiguration.standard
            // Narrow and tall. The window resizes itself when this is swapped in.
            configuration.expandedSize = CGSize(width: 400, height: 300)
            // A tighter pill than Vibe Code's, with the hit target left generous.
            configuration.collapsedWidth = .wrapCutout(reserve: 30)
            configuration.collapsedHitPadding = 14
            configuration.expandedBottomCornerRadius = 28
            // Identical layout on every display, so the drop zone never shifts.
            configuration.expandedTopReserve = .always
            return configuration
        }(),
        motion: .playful,
        style: .warmPaper,
        collapsedLeading: { model in
            AnyView(
                NotchBars(
                    model.isDropTargeted
                        ? .beacon(tint: .green)
                        : .resting(tint: NotchStyle.warmPaper.foreground.opacity(0.7))
                )
            )
        },
        collapsedTrailing: { model in AnyView(DropNotchBadge(model: model)) },
        expanded: { model in AnyView(DropNotchPanel(model: model)) }
    )
}

// MARK: - Collapsed

private struct DropNotchBadge: View {
    let model: DemoModel

    var body: some View {
        if model.files.isEmpty {
            Image(systemName: "tray")
                .font(.system(size: 11, weight: .medium))
                .opacity(0.6)
        } else {
            Text("\(model.files.count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.9)))
                .foregroundStyle(.black)
        }
    }
}

// MARK: - Expanded

private struct DropNotchPanel: View {
    let model: DemoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Drop Notch").font(.system(size: 13, weight: .semibold))
                Spacer()
                if !model.files.isEmpty {
                    Button("Clear") { model.files.removeAll() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            dropZone

            if !model.files.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.files, id: \.self) { file in
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                    .font(.system(size: 10))
                                    .opacity(0.6)
                                Text(file)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Spacer(minLength: 0)
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                model.isDropTargeted ? Color.green : Color.white.opacity(0.18),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
            .frame(height: 74)
            .overlay {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 15, weight: .light))
                    Text(model.isDropTargeted ? "Release to add" : "Drag files here")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            // Real drop handling, because a shelf that cannot accept a file is a
            // picture of a shelf. The panel is interactive only while expanded,
            // which is exactly when this is on screen.
            .dropDestination(for: URL.self) { urls, _ in
                model.addFiles(urls)
                return true
            } isTargeted: { targeted in
                model.isDropTargeted = targeted
            }
            .animation(.easeOut(duration: 0.15), value: model.isDropTargeted)
    }
}
