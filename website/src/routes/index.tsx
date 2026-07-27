import { createFileRoute } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { type Arg, ArgTable } from "#/components/arg-table";
import { CodeBlock } from "#/components/code-block";
import { MorphExplorer } from "#/components/morph-explorer";
import { NotchSimulator } from "#/components/notch-simulator";
import { Card, Section } from "#/components/section";

export const Route = createFileRoute("/")({ component: Home });

const GITHUB = "https://github.com/duongductrong/NotchKit";
const DOCS = "https://github.com/duongductrong/NotchKit/tree/master/docs";

function Nav() {
	return (
		<header className="sticky top-0 z-40 bg-background/80 backdrop-blur-md">
			<nav className="mx-auto flex h-14 w-full max-w-5xl items-center justify-between px-6">
				<div className="flex items-center gap-2">
					<span className="text-sm font-semibold tracking-tight text-foreground">
						NotchKit
					</span>
					<span className="rounded-full border border-border bg-muted/80 px-2 py-0.5 font-mono text-[10px] font-medium text-muted-foreground">
						v1.3.0
					</span>
				</div>
				<div className="flex items-center gap-6 text-sm text-muted-foreground">
					<a href={DOCS} className="transition-colors hover:text-foreground">
						Docs
					</a>
					<a href={GITHUB} className="transition-colors hover:text-foreground">
						GitHub
					</a>
				</div>
			</nav>
		</header>
	);
}

function Hero() {
	return (
		<section className="mx-auto flex w-full max-w-5xl flex-col items-center px-6 pb-24 pt-28 text-center">
			<p className="mb-4 mt-6 font-mono text-xs uppercase tracking-widest text-muted-foreground">
				SwiftUI · macOS 14+ · MIT
			</p>
			<h1 className="max-w-3xl text-5xl font-semibold tracking-tight text-foreground">
				Turn the MacBook notch into an interactive Dynamic Island
			</h1>
			<p className="mt-6 max-w-2xl text-lg leading-relaxed text-muted-foreground">
				An island rests as a pill against the screen edge and morphs open on
				hover or click — one shape whose width, height, and corner radii animate
				together. You write two SwiftUI views. NotchKit owns the window, the
				silhouette, hit testing, pointer hysteresis, and the motion.
			</p>
			<div className="mt-8 flex items-center gap-3">
				<a
					href={`${DOCS}/getting-started.md`}
					className="rounded-full bg-primary px-5 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
				>
					Get started
				</a>
				<a
					href={GITHUB}
					className="rounded-full border border-border bg-card px-5 py-2 text-sm text-foreground transition-colors hover:bg-accent"
				>
					View on GitHub
				</a>
			</div>
			<CodeBlock
				className="mt-10 w-full max-w-xl text-left"
				filename="Package.swift"
				code={`.package(url: "https://github.com/duongductrong/NotchKit.git", from: "1.3.0")`}
			/>
			<p className="mt-6 flex items-center gap-2 text-xs text-muted-foreground">
				The island above is live — hover it, click it, or
				<NotchSimulator />
			</p>
		</section>
	);
}

function MorphSection() {
	return (
		<Section
			eyebrow="The idea"
			title="One shape morphs — nothing cross-fades"
			description={
				<>
					A cross-fade always reads as a <em>switch</em>: at no instant is there
					a single object changing form. NotchKit keeps everything to one{" "}
					<code className="text-foreground">NotchShape</code> — the collapsed
					pill is that same shape at a small top corner radius, flaring into the
					bezel just like the open panel, only less. Hover the elements to see
					where each one lives on the shape, and tune the knobs to feel the
					parameters.
				</>
			}
		>
			<MorphExplorer />
		</Section>
	);
}

function ComponentSection({
	eyebrow,
	title,
	description,
	args,
	code,
	visual,
	reverse,
}: {
	eyebrow: string;
	title: string;
	description: string;
	args: Arg[];
	code: string;
	visual?: ReactNode;
	reverse?: boolean;
}) {
	return (
		<Section eyebrow={eyebrow} title={title} description={description}>
			<div className="grid items-start gap-6 lg:grid-cols-5">
				<div className={reverse ? "lg:order-2 lg:col-span-3" : "lg:col-span-3"}>
					<ArgTable args={args} />
				</div>
				<div
					className={`flex flex-col gap-6 lg:col-span-2 ${reverse ? "lg:order-1" : ""}`}
				>
					{visual}
					<CodeBlock code={code} />
				</div>
			</div>
		</Section>
	);
}

const presenterArgs: Arg[] = [
	{
		name: "configuration",
		type: "NotchConfiguration",
		defaultValue: ".standard",
		description:
			"Everything tunable about the island, in one value type. Mutable at runtime.",
	},
	{
		name: "motion",
		type: "NotchMotion?",
		defaultValue: ".resolved()",
		description:
			"Animation vocabulary. nil resolves Reduce Motion automatically.",
	},
	{
		name: "style",
		type: "NotchStyle",
		defaultValue: ".standard",
		description:
			"Ink, hairline, shadow, foreground. Independent of motion and placement.",
	},
	{
		name: "preferredScreenID",
		type: "String?",
		defaultValue: "nil",
		description:
			"Pin to a display by NSScreen.notch_stableID. nil picks the notched screen, then main.",
	},
];

const presenterMethods: Arg[] = [
	{
		name: "install(collapsed:expanded:)",
		type: "Void",
		description:
			"Builds the window and shows the collapsed island. Both views are wrapped in the silhouette, hairline, and shadow for you.",
	},
	{
		name: "expand(reason:)",
		type: "Void",
		description:
			"Opens the panel. Only .click takes key status — a hover never steals your keystrokes.",
	},
	{
		name: "collapse()",
		type: "Void",
		description:
			"Closes the panel. The window stays; only interactivity is withdrawn.",
	},
	{ name: "toggle()", type: "Void", description: "Expands or collapses." },
	{
		name: "peek()",
		type: "Void",
		description:
			"A brief scale bump, then back to collapsed. For “something happened” without taking over the screen.",
	},
	{
		name: "uninstall()",
		type: "Void",
		description: "Tears down the window and all monitors.",
	},
];

const configurationArgs: Arg[] = [
	{
		name: "expandedSize",
		type: "CGSize",
		defaultValue: "540 × 260",
		description:
			"Size of the expanded panel's content, excluding shadow insets. Also the window size — pick the largest panel you will show.",
	},
	{
		name: "collapsedWidth",
		type: "NotchCollapsedWidth",
		defaultValue: ".wrapCutout(reserve: 44)",
		description:
			"How wide the collapsed pill is drawn. Separate from the hit target on purpose.",
	},
	{
		name: "collapsedHitPadding",
		type: "CGFloat",
		defaultValue: "6",
		description:
			"Invisible hit-target margin around the collapsed pill. Users aim at the notch, not your pill.",
	},
	{
		name: "shadowInsetHorizontal",
		type: "CGFloat",
		defaultValue: "18",
		description:
			"Transparent margin reserved inside the window for the SwiftUI-drawn shadow.",
	},
	{
		name: "shadowInsetBottom",
		type: "CGFloat",
		defaultValue: "22",
		description:
			"Bottom shadow room. AppKit's own shadow would box the window, so the panel draws its own.",
	},
	{
		name: "expandedTopCornerRadius",
		type: "CGFloat",
		defaultValue: "22",
		description: "Concave top curl of the expanded panel.",
	},
	{
		name: "expandedBottomCornerRadius",
		type: "CGFloat",
		defaultValue: "22",
		description: "Convex bottom round of the expanded panel.",
	},
	{
		name: "expandedContentInsetsOverride",
		type: "EdgeInsets?",
		defaultValue: "nil",
		description:
			"nil derives insets guaranteed to clear the silhouette — including the taper below the top curl.",
	},
	{
		name: "expandedTopReserve",
		type: "NotchExpandedTopReserve",
		defaultValue: ".cutoutOnly",
		description:
			"How much of the panel's top stays clear of the hardware cutout.",
	},
	{
		name: "expandedContentAlignment",
		type: "Alignment",
		defaultValue: ".top",
		description:
			"Content pinned to the top does not appear to slide while the surface is still growing.",
	},
	{
		name: "expandsOnHover",
		type: "Bool",
		defaultValue: "true",
		description: "Open on hover, not just click.",
	},
	{
		name: "hoverOpenDelay",
		type: "TimeInterval",
		defaultValue: "0.15",
		description: "Filters pointers merely transiting to the menu bar.",
	},
	{
		name: "hoverCancelGrace",
		type: "TimeInterval",
		defaultValue: "0.10",
		description:
			"Hysteresis for pointer jitter at the cutout edge. What separates solid from haunted.",
	},
	{
		name: "collapsesOnPointerExit",
		type: "Bool",
		defaultValue: "true",
		description:
			"Hover-opened islands close when the pointer leaves. Click-opened ones ignore this.",
	},
	{
		name: "collapsesOnOutsideClick",
		type: "Bool",
		defaultValue: "true",
		description:
			"Close on outside click, and forward that click to whatever was underneath.",
	},
	{
		name: "hapticOnHoverOpen",
		type: "Bool",
		defaultValue: "true",
		description:
			"Light tap on Force Touch trackpads when a hover opens the island. No-op elsewhere.",
	},
	{
		name: "pointerSampleInterval",
		type: "TimeInterval",
		defaultValue: "0.05",
		description:
			"20Hz pointer sampling — imperceptible for hit testing, invisible in Activity Monitor.",
	},
];

const cutoutArgs: Arg[] = [
	{
		name: "cutoutWidth",
		type: "CGFloat",
		description:
			"Width of the hardware cutout to reserve. Pass 0 on plain displays — it becomes an ordinary bar.",
	},
	{
		name: "gutterWidth",
		type: "CGFloat",
		description:
			"Usable width on each side of the cutout. Pass presenter.collapsedGutterWidth rather than recomputing.",
	},
	{
		name: "pillHeight",
		type: "CGFloat",
		description:
			"Height of the pill. Used to derive a provably safe edgeInset.",
	},
	{
		name: "edgeInset",
		type: "CGFloat?",
		defaultValue: "nil",
		description:
			"nil derives pillHeight / 2 — the smallest inset that is safe for content of any height.",
	},
	{
		name: "alignment",
		type: "VerticalAlignment",
		defaultValue: ".center",
		description:
			".firstTextBaseline when the two sides hold text at different sizes.",
	},
	{
		name: "leading / trailing",
		type: "@ViewBuilder",
		description:
			"Content either side of the cutout. The middle sits behind hardware — anything there is invisible.",
	},
];

const motionArgs: Arg[] = [
	{
		name: "expand",
		type: "Animation",
		defaultValue: "spring(0.42, 0.80)",
		description:
			"Collapsed → expanded. A spring: the panel is arriving, a touch of overshoot feels physical.",
	},
	{
		name: "collapse",
		type: "Animation",
		defaultValue: "smooth(0.30)",
		description:
			"Monotonic ease. A spring on the way out reads as the UI arguing.",
	},
	{
		name: "peek",
		type: "Animation",
		defaultValue: "spring(0.30, 0.50)",
		description: "The attention bump. Bouncy by design.",
	},
	{
		name: "hover",
		type: "Animation",
		defaultValue: "spring(0.38, 0.80)",
		description: "Hover scale on the collapsed pill.",
	},
	{
		name: "contentMorph",
		type: "Animation",
		defaultValue: "timingCurve(0.45)",
		description:
			"Content changing inside an open panel. Content should not spring — overshoot on text is hard to read.",
	},
	{
		name: "highlight",
		type: "Animation",
		defaultValue: "easeInOut(0.15)",
		description: "Small state flips: selection, checkmarks.",
	},
	{
		name: "contentRevealDuration",
		type: "TimeInterval",
		defaultValue: "0.22",
		description: "How long incoming content takes to fade up.",
	},
	{
		name: "contentRevealDelay",
		type: "TimeInterval",
		defaultValue: "0.08",
		description:
			"Head start given to the shape before content appears, so text never renders squeezed into a sliver.",
	},
	{
		name: "contentHideDuration",
		type: "TimeInterval",
		defaultValue: "0.12",
		description:
			"Quicker than the reveal: content must be gone before the shape closes over it.",
	},
	{
		name: "expandedUnmountDelay",
		type: "TimeInterval",
		defaultValue: "0.36",
		description: "Must outlast collapse, or the panel flashes empty mid-morph.",
	},
	{
		name: "hoverScale",
		type: "CGFloat",
		defaultValue: "1.028",
		description:
			"Tiny for a reason: past ~1.05 the pill visibly clips against the screen edge.",
	},
	{
		name: "peekScale",
		type: "CGFloat",
		defaultValue: "1.04",
		description: "Scale at the top of a peek.",
	},
	{
		name: "peekDuration",
		type: "TimeInterval",
		defaultValue: "0.30",
		description: "How long a peek holds before returning to collapsed.",
	},
];

const styleArgs: Arg[] = [
	{
		name: "ink",
		type: "Color",
		defaultValue: ".black",
		description:
			"The island body. Pure black is the only value that merges with the hardware — the cutout emits no light.",
	},
	{
		name: "hairline",
		type: "Color",
		defaultValue: "white 8%",
		description:
			"Inner hairline along the silhouette. Invisible on light backgrounds, rescues the edge on dark ones.",
	},
	{
		name: "hairlineWidth",
		type: "CGFloat",
		defaultValue: "1",
		description: "Width of the inner hairline.",
	},
	{
		name: "shadowColor",
		type: "Color",
		defaultValue: "black 45%",
		description:
			"Drawn in SwiftUI so it follows the concave path instead of boxing the window. Suppressed while collapsed.",
	},
	{
		name: "shadowRadius",
		type: "CGFloat",
		defaultValue: "14",
		description: "Shadow blur radius.",
	},
	{
		name: "shadowOffsetY",
		type: "CGFloat",
		defaultValue: "8",
		description: "Shadow vertical offset.",
	},
	{
		name: "foreground",
		type: "Color",
		defaultValue: "white 96%",
		description: "Tint for content drawn on the ink.",
	},
	{
		name: "colorScheme",
		type: "ColorScheme?",
		defaultValue: ".dark",
		description:
			"Forced on your content. nil inherits the system — correct only for deliberately light islands.",
	},
];

const barsArgs: Arg[] = [
	{
		name: "levels",
		type: "[CGFloat]",
		description:
			"Resting height of each bar as a fraction of height, 0...1. The bar count is levels.count — nothing to keep in sync.",
	},
	{
		name: "peaks",
		type: "[CGFloat]?",
		defaultValue: "nil",
		description:
			"Height each bar animates toward. nil leaves the bar static — a resting indicator costs zero animation.",
	},
	{
		name: "barWidth",
		type: "CGFloat",
		defaultValue: "2.5",
		description: "Width of each bar.",
	},
	{
		name: "spacing",
		type: "CGFloat",
		defaultValue: "3",
		description: "Gap between bars.",
	},
	{
		name: "cornerRadius",
		type: "CGFloat?",
		defaultValue: "nil",
		description: "nil gives fully rounded capsule ends.",
	},
	{
		name: "height",
		type: "CGFloat",
		defaultValue: "14",
		description: "Height of a bar at level 1, and the view's own height.",
	},
	{
		name: "period",
		type: "TimeInterval",
		defaultValue: "0.9",
		description: "One full level → peak → level cycle.",
	},
	{
		name: "stagger",
		type: "TimeInterval",
		defaultValue: "0.15",
		description:
			"Extra delay per bar. 0 throbs as one object; a small value turns it into a wave.",
	},
	{
		name: "curve",
		type: "Curve",
		defaultValue: ".easeInOut",
		description: ".linear, .easeIn, .easeOut, or .easeInOut.",
	},
	{
		name: "tint",
		type: "Color",
		defaultValue: ".white",
		description: "Bar color.",
	},
	{
		name: "label",
		type: "String?",
		defaultValue: "nil",
		description: "VoiceOver label. nil marks the view purely decorative.",
	},
];

function StylePresets() {
	const presets = [
		{
			name: ".standard",
			ink: "#000000",
			hairline: "rgba(255,255,255,0.08)",
			fg: "#f5f5f5",
			note: "Merges with the hardware.",
		},
		{
			name: ".warmPaper",
			ink: "#0d0d0f",
			hairline: "rgba(255,255,255,0.07)",
			fg: "#f1ead9",
			note: "Reads as its own object beside the cutout.",
		},
		{
			name: ".contrast",
			ink: "#000000",
			hairline: "rgba(255,255,255,0.16)",
			fg: "#f5f5f5",
			note: "Stronger edge for busy wallpapers.",
		},
		{
			name: ".translucent",
			ink: "rgba(0,0,0,0.72)",
			hairline: "rgba(255,255,255,0.12)",
			fg: "#f5f5f5",
			note: "Great over wallpaper, worse over video.",
		},
	];
	return (
		<div className="grid gap-4 sm:grid-cols-2">
			{presets.map((p) => (
				<Card key={p.name} className="flex items-center gap-4">
					<div
						className="flex h-10 w-24 items-center justify-center rounded-b-2xl"
						style={{
							backgroundColor: p.ink,
							boxShadow: `inset 0 0 0 1px ${p.hairline}`,
						}}
					>
						<span className="text-xs" style={{ color: p.fg }}>
							Aa
						</span>
					</div>
					<div>
						<p className="font-mono text-xs text-foreground">{p.name}</p>
						<p className="mt-1 text-xs text-muted-foreground">{p.note}</p>
					</div>
				</Card>
			))}
		</div>
	);
}

function BarsDemo() {
	return (
		<Card className="flex items-center justify-center gap-10 py-8">
			<div className="flex flex-col items-center gap-2">
				<div className="flex items-center gap-1">
					{[0.3, 0.6, 1, 0.45].map((h) => (
						<span
							key={h}
							className="w-0.5 rounded-full bg-foreground"
							style={{ height: h * 14 }}
						/>
					))}
				</div>
				<span className="font-mono text-xs text-muted-foreground">.steady</span>
			</div>
			<div className="flex flex-col items-center gap-2">
				<div className="flex items-center gap-1">
					{[0, 1, 2, 3].map((i) => (
						<span
							key={i}
							className="w-0.5 animate-eq rounded-full bg-foreground"
							style={{ height: 14, animationDelay: `${i * 0.15}s` }}
						/>
					))}
				</div>
				<span className="font-mono text-xs text-muted-foreground">.wave</span>
			</div>
		</Card>
	);
}

function EnumCards() {
	const enums = [
		{
			name: "NotchCollapsedWidth",
			cases: [".wrapCutout(reserve:)", ".fixed(_:)"],
			note: "Wrap the cutout on notched hardware; a fixed width sized to content everywhere else.",
		},
		{
			name: "NotchExpandedTopReserve",
			cases: [".cutoutOnly", ".always", ".fixed(_:)", ".none"],
			note: "How much of the panel's top stays clear of the cutout. A policy, not a number.",
		},
		{
			name: "NotchShape / NotchPillShape",
			cases: ["topCornerRadius", "bottomCornerRadius"],
			note: "The island silhouette. Concave top corners curl inward; the bezel appears to flow into the panel.",
		},
		{
			name: "NotchGeometry",
			cases: ["collapsedHeight", "notchWidth", "hasPhysicalNotch", "notchRect"],
			note: "Where the island lives on one screen. Plain data, recomputed on display changes.",
		},
	];
	return (
		<Section
			eyebrow="Value types"
			title="Enums that carry the policy"
			description="The decisions that are easy to get wrong — cutout wrapping, top reserve, the silhouette — are modelled as small value types, not booleans."
		>
			<div className="grid gap-4 sm:grid-cols-2">
				{enums.map((e) => (
					<Card key={e.name}>
						<p className="font-mono text-sm text-foreground">{e.name}</p>
						<div className="mt-3 flex flex-wrap gap-2">
							{e.cases.map((c) => (
								<span
									key={c}
									className="rounded-full border border-border bg-muted px-2.5 py-1 font-mono text-xs text-muted-foreground"
								>
									{c}
								</span>
							))}
						</div>
						<p className="mt-3 text-sm text-muted-foreground">{e.note}</p>
					</Card>
				))}
			</div>
		</Section>
	);
}

function PresetsShowcase() {
	const islands = [
		{
			name: "Vibe Code",
			file: "VibeCodeIsland.swift",
			description:
				"AI coding agent with interactive permission prompt cards, subagent status list, and walking pixel cat indicator.",
			leading: "pixel cat",
			trailing: "3/4 tasks",
		},
		{
			name: "Now playing",
			file: "NowPlayingIsland.swift",
			description:
				"Native macOS Apple Music style player with album artwork, transport controls, and dynamic scrubber.",
			leading: "artwork",
			trailing: "2:41",
		},
		{
			name: "Morph inspector",
			file: "MorphInspectorIsland.swift",
			description:
				"Interactive geometry morph inspector with live cutout inset, corner radii, and motion tokens visualization.",
			leading: "pixel grid",
			trailing: "morph",
		},
	];
	return (
		<Section
			eyebrow="Presets"
			title="Three islands, one presenter"
			description={
				<>
					Everything in{" "}
					<code className="text-foreground">Examples/NotchDemo</code> is the
					same <code className="text-foreground">NotchPresenter</code> with
					different configuration and content. Run{" "}
					<code className="text-foreground">swift run NotchDemo</code> and move
					the pointer to the notch.
				</>
			}
		>
			<div className="grid gap-4 md:grid-cols-3">
				{islands.map((island) => (
					<Card key={island.name} className="flex flex-col">
						<div className="mx-auto flex h-9 w-48 items-center justify-between rounded-b-2xl bg-notch-ink px-4 shadow-[inset_0_0_0_1px_var(--border)]">
							<span className="font-mono text-xs text-muted-foreground">
								{island.leading}
							</span>
							<span className="font-mono text-xs text-muted-foreground">
								{island.trailing}
							</span>
						</div>
						<p className="mt-4 text-sm font-medium text-foreground">
							{island.name}
						</p>
						<p className="mt-1 font-mono text-xs text-muted-foreground">
							{island.file}
						</p>
						<p className="mt-2 text-sm text-muted-foreground">
							{island.description}
						</p>
					</Card>
				))}
			</div>
		</Section>
	);
}

const QUICK_START = `import AppKit
import SwiftUI
import NotchKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Hold this strongly — the presenter owns the window.
    private var presenter: NotchPresenter?

    func applicationDidFinishLaunching(_ note: Notification) {
        let presenter = NotchPresenter()
        self.presenter = presenter

        presenter.install(
            collapsed: {
                NotchCutoutLayout(
                    cutoutWidth: presenter.geometry.hasPhysicalNotch
                        ? presenter.geometry.notchWidth : 0,
                    gutterWidth: presenter.collapsedGutterWidth,
                    pillHeight: presenter.geometry.collapsedHeight
                ) {
                    Image(systemName: "waveform")
                } trailing: {
                    Text("3").monospacedDigit()
                }
            },
            expanded: {
                VStack(alignment: .leading) {
                    Text("Panel content")
                }
            }
        )
    }
}`;

function QuickStart() {
	const steps = [
		{
			n: "1",
			title: "Add the package",
			body: "File → Add Package Dependencies… in Xcode, or the Package.swift line above.",
		},
		{
			n: "2",
			title: "Install two views",
			body: "What the pill shows and what the panel shows. Silhouette, hairline, and shadow come free.",
		},
		{
			n: "3",
			title: "Drive it",
			body: "expand(), collapse(), toggle(), peek() — or just let hover policy do its thing.",
		},
	];
	return (
		<Section
			eyebrow="Quick start"
			title="Three steps to an island"
			description="Configure, install two views, drive it."
		>
			<div className="grid items-start gap-6 lg:grid-cols-5">
				<div className="flex flex-col gap-4 lg:col-span-2">
					{steps.map((s) => (
						<Card key={s.n} className="flex gap-4">
							<span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-muted font-mono text-xs text-foreground">
								{s.n}
							</span>
							<div>
								<p className="text-sm font-medium text-foreground">{s.title}</p>
								<p className="mt-1 text-sm text-muted-foreground">{s.body}</p>
							</div>
						</Card>
					))}
				</div>
				<CodeBlock
					className="lg:col-span-3"
					filename="AppDelegate.swift"
					code={QUICK_START}
				/>
			</div>
		</Section>
	);
}

function Footer() {
	return (
		<footer className="border-t border-border">
			<div className="mx-auto flex w-full max-w-5xl flex-col items-center justify-between gap-4 px-6 py-10 text-sm text-muted-foreground sm:flex-row">
				<span>NotchKit — MIT license</span>
				<div className="flex gap-6">
					<a href={DOCS} className="transition-colors hover:text-foreground">
						Docs
					</a>
					<a href={GITHUB} className="transition-colors hover:text-foreground">
						GitHub
					</a>
				</div>
			</div>
		</footer>
	);
}

function CutoutDiagram() {
	return (
		<Card className="flex flex-col items-center gap-4 py-8">
			<div className="flex h-10 w-64 items-center overflow-hidden rounded-b-3xl bg-notch-ink shadow-[inset_0_0_0_1px_var(--border)]">
				<div className="flex h-full flex-1 items-center justify-center border-r border-dashed border-border">
					<span className="font-mono text-xs text-muted-foreground">
						leading
					</span>
				</div>
				<div className="flex h-full w-24 items-center justify-center bg-card">
					<span className="font-mono text-xs text-muted-foreground">
						cutout
					</span>
				</div>
				<div className="flex h-full flex-1 items-center justify-center border-l border-dashed border-border">
					<span className="font-mono text-xs text-muted-foreground">
						trailing
					</span>
				</div>
			</div>
			<div className="flex w-64 justify-between font-mono text-xs text-muted-foreground">
				<span>← gutterWidth →</span>
				<span>← gutterWidth →</span>
			</div>
			<p className="max-w-sm text-center text-xs text-muted-foreground">
				The middle of a pill sits behind the hardware — invisible only on
				notched Macs, which is how it survives development on an external
				monitor.
			</p>
		</Card>
	);
}

function Home() {
	return (
		<div className="min-h-screen bg-background text-foreground">
			<Nav />
			<Hero />
			<MorphSection />
			<ComponentSection
				eyebrow="The entry point"
				title="NotchPresenter"
				description="The only object you interact with. Create one, install your two views, then drive it with expand / collapse / peek. Keep a strong reference for as long as the island should exist."
				args={[...presenterArgs, ...presenterMethods]}
				code={`let presenter = NotchPresenter(
    configuration: .standard,
    motion: .resolved(),
    style: .standard
)

presenter.install {
    // collapsed pill content
} expanded: {
    // panel content
}

presenter.peek()`}
			/>
			<ComponentSection
				reverse
				eyebrow="Configuration"
				title="NotchConfiguration"
				description="Everything tunable about an island, in one value type. Mutable at runtime — anything that changes the window's size repositions it immediately."
				args={configurationArgs}
				code={`// Presets
.standard     // hover-to-open, medium panel
.clickOnly    // controls users must not open by accident
.statusOnly   // thin strip; peek and collapsed only
.canvas       // full-bleed content, no padding
.standalone(pillWidth: 220) // no hardware cutout`}
			/>
			<ComponentSection
				eyebrow="Layout"
				title="NotchCutoutLayout"
				description="Lays content on either side of the physical cutout. The dead zone is a fixed-width Color.clear, not a Spacer — a flexible spacer lets content creep under the cutout, and that only shows up on real notched hardware."
				args={cutoutArgs}
				visual={<CutoutDiagram />}
				code={`NotchCutoutLayout(
    cutoutWidth: presenter.geometry.hasPhysicalNotch
        ? presenter.geometry.notchWidth : 0,
    gutterWidth: presenter.collapsedGutterWidth,
    pillHeight: presenter.geometry.collapsedHeight
) {
    NotchBars(.wave())
} trailing: {
    Text("3").monospacedDigit()
}`}
			/>
			<ComponentSection
				reverse
				eyebrow="Motion"
				title="NotchMotion"
				description="Opening is a spring and closing is a monotonic ease, on purpose: a spring on the way out means the shape bounces back after the user already dismissed it. .resolved() swaps in .reduced when the system asks for less motion."
				args={motionArgs}
				code={`// Presets
.standard  // the tuned defaults
.crisp     // faster, flatter, no overshoot
.playful   // looser and springier
.reduced   // cross-fades only — Reduce Motion

let motion = NotchMotion.resolved()`}
			/>
			<ComponentSection
				eyebrow="Style"
				title="NotchStyle"
				description="How the island looks, independent of how it moves. The ink defaults to pure black — not laziness, but the only value that merges with hardware that emits no light."
				args={styleArgs}
				visual={<StylePresets />}
				code={`var style = NotchStyle.standard
style.hairline = Color.white.opacity(0.12)

let paper = NotchStyle.warmPaper`}
			/>
			<ComponentSection
				reverse
				eyebrow="Indicators"
				title="NotchBars + NotchBarsStyle"
				description="Equalizer bars for the collapsed pill. Every visual decision is a value you can build, store, or ship as your own preset. A bar with no peak has no animation object at all — a resting indicator costs zero."
				args={barsArgs}
				visual={<BarsDemo />}
				code={`NotchBars(.steady([0.3, 0.6, 1, 0.45]))

NotchBars(.wave(count: 3, low: 0.35, high: 1))`}
			/>
			<EnumCards />
			<PresetsShowcase />
			<QuickStart />
			<Footer />
		</div>
	);
}
