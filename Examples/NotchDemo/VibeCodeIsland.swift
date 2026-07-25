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
            spacing: 2.5,
            height: 9.5,
            period: 0.7,
            // Just under a quarter of the period, so the wave never lines back up.
            stagger: 0.11,
            tint: tint
        )
    }

    static func paused(tint: Color) -> NotchBarsStyle {
        // No peaks, so no animation object is created at all — a paused indicator
        // should cost nothing, not idle at 60fps.
        steady([0.55, 0.3, 0.55, 0.3], spacing: 2.5, height: 9.5, tint: tint)
    }
}

// MARK: - Preset

extension IslandPreset {
    static let vibeCode = IslandPreset(
        id: "vibe-code",
        name: "Vibe Code",
        configuration: {
            var configuration = NotchConfiguration.standard
            configuration.expandedSize = CGSize(width: 540, height: 265)
            configuration.collapsedWidth = .wrapCutout(reserve: 58)
            return configuration
        }(),
        motion: .standard,
        style: .standard,
        collapsedLeading: { model in
            AnyView(VibeCodePixelPetLeading(isRunning: model.isRunning))
        },
        collapsedTrailing: { model in AnyView(VibeCodeBadge(model: model)) },
        expanded: { model in AnyView(VibeCodePanel(model: model)) }
    )
}

// MARK: - Collapsed Walking Pixel Cat Widget

private struct VibeCodePixelPetLeading: View {
    let isRunning: Bool
    @State private var walkFrame = 0
    @State private var glowPhase = false

    // Frame 1: Stride A
    private let frame1: [[Int]] = [
        [0, 1, 0, 0, 1, 0], // Ears & Tail
        [1, 1, 1, 1, 1, 1], // Head & Body
        [0, 1, 1, 1, 1, 0], // Torso
        [0, 1, 0, 0, 1, 0], // Legs upper
        [1, 0, 0, 0, 0, 1]  // Paws stride
    ]

    // Frame 2: Stride B
    private let frame2: [[Int]] = [
        [0, 1, 0, 0, 1, 0], // Ears & Tail
        [1, 1, 1, 1, 1, 1], // Head & Body
        [0, 1, 1, 1, 1, 0], // Torso
        [0, 0, 1, 1, 0, 0], // Legs upper
        [0, 1, 0, 0, 1, 0]  // Paws center
    ]

    private var activeGrid: [[Int]] {
        walkFrame == 0 ? frame1 : frame2
    }

    private var greenColor: Color {
        Color(red: 0.65, green: 0.95, blue: 0.2) // Single Consistent Lime Green
    }

    var body: some View {
        VStack(spacing: 0.7) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 0.7) {
                    ForEach(0..<6, id: \.self) { col in
                        let val = activeGrid[row][col]
                        if val == 0 {
                            Color.clear
                                .frame(width: 2.3, height: 2.3)
                        } else {
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(greenColor)
                                .frame(width: 2.3, height: 2.3)
                                .shadow(
                                    color: greenColor.opacity(glowPhase ? 0.9 : 0.4),
                                    radius: glowPhase ? 2.5 : 1.0
                                )
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
            startWalkTimer()
        }
    }

    private func startWalkTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            if isRunning {
                walkFrame = (walkFrame + 1) % 2
            }
        }
    }
}

// MARK: - Collapsed

private struct VibeCodeBadge: View {
    let model: DemoModel

    var body: some View {
        HStack(spacing: 4) {
            Text("\(model.completedSteps)/\(model.steps.count)")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.9))
            Circle()
                .fill(model.permissionRequested ? Color.orange : (model.isRunning ? Color.green : Color.yellow))
                .frame(width: 4.5, height: 4.5)
        }
    }
}

// MARK: - Expanded

private struct VibeCodePanel: View {
    let model: DemoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header Row: Agent Name, Model & Status
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.9))

                Text("Vibe Code")
                    .font(.system(size: 13, weight: .bold))

                Text("claude-3.7-sonnet")
                    .font(.system(size: 9, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Interactive Permission Card (Claude / Codex Style)
            if model.permissionRequested {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "shield.amber.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.orange)
                        Text("PERMISSION REQUIRED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.orange)
                        Spacer()
                    }

                    Text("bash: git commit -m \"feat: implement auth flow\"")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.95))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Button {
                            model.grantPermission()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Approve")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.85)))
                            .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.denyPermission()
                        } label: {
                            Text("Deny")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                                .foregroundStyle(Color(white: 0.85))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                )
            }

            // Task Step List (Scrollable when height limit reached)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(model.steps) { step in
                        HStack(spacing: 8) {
                            StepDot(state: step.state, isRunning: model.isRunning)
                            Text(step.title)
                                .font(.system(size: 11))
                                .foregroundStyle(step.state == .queued ? .secondary : .primary)
                            Spacer(minLength: 0)
                            if step.state == .running {
                                Text("running")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.green)
                            }
                        }
                        .frame(height: 20)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .animation(model.presenter.motion.contentMorph, value: model.steps)

            // Progress & Action Bar
            HStack {
                ProgressView(value: Double(model.completedSteps), total: Double(max(1, model.steps.count)))
                    .tint(.green)
                    .frame(maxWidth: 140)

                Spacer()

                Button(model.isRunning ? "Pause" : "Resume") {
                    model.isRunning.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

                Button("+ Task") {
                    model.addStep()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 32)
    }

    private var statusText: String {
        if model.permissionRequested { return "Permission" }
        return model.isRunning ? "Working" : "Paused"
    }

    private var statusColor: Color {
        if model.permissionRequested { return .orange }
        return model.isRunning ? .green : .yellow
    }
}

private struct StepDot: View {
    let state: DemoModel.Step.State
    let isRunning: Bool

    var body: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .running:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(isRunning ? .green : .orange)
        case .queued:
            Circle()
                .fill(Color(white: 0.35))
                .frame(width: 5, height: 5)
        }
    }
}
