import NotchKit
import SwiftUI

// A background coding agent: what is running, how far along, and a way to stop it.
// Wide, short panel; hardware-matched black; standard springs.

// MARK: - Bar styles

///
/// NotchKit ships only shape-descriptive styles — `wave`, `steady` — and leaves
/// naming the *states* to the app that has them. This is where "running" and
/// "paused" become real, next to the code that knows what they mean.
private extension NotchBarsStyle {
    static func running(tint: Color) -> NotchBarsStyle {
        wave(
            count: 4,
            low: 0.22,
            high: 1,
            spacing: 3,
            height: 13,
            period: 0.7,
            // Just under a quarter of the period, so the wave never lines back up.
            stagger: 0.11,
            tint: tint
        )
    }

    static func paused(tint: Color) -> NotchBarsStyle {
        // No peaks, so no animation object is created at all — a paused indicator
        // should cost nothing, not idle at 60fps.
        steady([0.55, 0.3, 0.55, 0.3], spacing: 3, height: 13, tint: tint)
    }
}

// MARK: - Preset

extension IslandPreset {
    static let vibeCode = IslandPreset(
        id: "vibe-code",
        name: "Vibe Code",
        configuration: {
            var configuration = NotchConfiguration.standard
            configuration.expandedSize = CGSize(width: 520, height: 250)
            configuration.collapsedWidth = .wrapCutout(reserve: 46)
            return configuration
        }(),
        motion: .standard,
        style: .standard,
        collapsedLeading: { model in
            AnyView(
                NotchBars(
                    model.isRunning
                        ? .running(tint: Color(white: 0.96))
                        : .paused(tint: Color(white: 0.55))
                )
            )
        },
        collapsedTrailing: { model in AnyView(VibeCodeBadge(model: model)) },
        expanded: { model in AnyView(VibeCodePanel(model: model)) }
    )
}

// MARK: - Collapsed

private struct VibeCodeBadge: View {
    let model: DemoModel

    var body: some View {
        HStack(spacing: 5) {
            Text("\(model.completedSteps)/\(model.steps.count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Circle()
                .fill(model.isRunning ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
        }
    }
}

// MARK: - Expanded

private struct VibeCodePanel: View {
    let model: DemoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Vibe Code").font(.system(size: 13, weight: .semibold))
                Text(model.isRunning ? "working" : "paused")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(model.isRunning ? "Pause" : "Resume") { model.isRunning.toggle() }
                Button("Add step") { model.addStep() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))

            ProgressView(value: Double(model.completedSteps), total: Double(max(1, model.steps.count)))
                .tint(.green)

            VStack(spacing: 0) {
                ForEach(model.steps) { step in
                    HStack(spacing: 8) {
                        StepDot(state: step.state, isRunning: model.isRunning)
                        Text(step.title).font(.system(size: 12))
                        Spacer(minLength: 0)
                        if step.state == .running {
                            Text("running")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 26)
                }
            }
            // Content inside an open panel eases; it never springs. Overshoot
            // under text makes the text hard to read.
            .animation(model.presenter.motion.contentMorph, value: model.steps)

            Spacer(minLength: 0)
        }
    }
}

private struct StepDot: View {
    let state: DemoModel.Step.State
    let isRunning: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay {
                if state == .running, isRunning {
                    Circle().stroke(color.opacity(0.4), lineWidth: 3)
                }
            }
    }

    private var color: Color {
        switch state {
        case .done: .green
        case .running: isRunning ? .blue : .orange
        case .queued: Color(white: 0.4)
        }
    }
}
