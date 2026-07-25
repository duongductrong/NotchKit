import { useCallback, useRef, useState } from "react";
import { cn } from "#/lib/cn";
import { notchPath, useSpringValue } from "./notch-simulator";

const COLLAPSED = { width: 278, height: 38, cutout: 190, bottomRadius: 19 };
const EXPANDED = { width: 440, height: 210 };

type MorphElementId =
	| "silhouette"
	| "cutout"
	| "motion"
	| "style"
	| "pointer"
	| "reserve"
	| "bars";

type MorphProperty = {
	name: string;
	type: string;
	defaultValue: string;
	info: string;
};

type MorphElement = {
	id: MorphElementId;
	name: string;
	monogram: string;
	blurb: string;
	params: MorphProperty[];
};

const ELEMENTS: MorphElement[] = [
	{
		id: "silhouette",
		name: "NotchShape",
		monogram: "NS",
		blurb:
			"One continuous outline — concave top corners, convex bottom. The whole morph is four interpolating numbers on this single shape.",
		params: [
			{
				name: "topCornerRadius",
				type: "CGFloat",
				defaultValue: "22",
				info: "Concave top curl radius where notch fuses into physical screen bezels.",
			},
			{
				name: "bottomCornerRadius",
				type: "CGFloat",
				defaultValue: "22",
				info: "Convex bottom rounding radius for the expanded panel corners.",
			},
		],
	},
	{
		id: "cutout",
		name: "Cutout Bridge",
		monogram: "CL",
		blurb:
			"Reserves the hardware cutout and splits what is left into a leading and a trailing gutter. Anything drawn in the middle is invisible.",
		params: [
			{
				name: "cutoutWidth",
				type: "CGFloat",
				defaultValue: "190",
				info: "Hardware camera cutout width reserved to shield physical display housing.",
			},
			{
				name: "gutterWidth",
				type: "CGFloat",
				defaultValue: "44",
				info: "Usable width on each side of cutout available for icons and indicators.",
			},
			{
				name: "pillHeight",
				type: "CGFloat",
				defaultValue: "38",
				info: "Collapsed pill height used to derive safe edge insets for content.",
			},
		],
	},
	{
		id: "motion",
		name: "Spring Engine",
		monogram: "NM",
		blurb:
			"Every curve and delay. Open is a spring, close is a monotonic ease — drag the stiffness and damping knobs to feel the response.",
		params: [
			{
				name: "expand",
				type: "Animation",
				defaultValue: "spring(0.42, 0.80)",
				info: "Spring animation with physical overshoot for panel arrival.",
			},
			{
				name: "collapse",
				type: "Animation",
				defaultValue: "smooth(0.30)",
				info: "Monotonic ease-out animation ensuring closing never fights pointer motion.",
			},
			{
				name: "contentRevealDelay",
				type: "TimeInterval",
				defaultValue: "0.08",
				info: "Head start given to continuous shape morph before text opacity fades in.",
			},
		],
	},
	{
		id: "style",
		name: "Ink & Hairline",
		monogram: "ST",
		blurb:
			"Ink, hairline, and shadow. Pure-black ink is the only value that merges with hardware that emits no light.",
		params: [
			{
				name: "ink",
				type: "Color",
				defaultValue: ".black",
				info: "Base ink color. Pure black merges seamlessly with hardware cutouts.",
			},
			{
				name: "hairline",
				type: "Color",
				defaultValue: "white 8%",
				info: "Inner hairline stroke defining panel bounds on dark backgrounds.",
			},
			{
				name: "shadowRadius",
				type: "CGFloat",
				defaultValue: "14",
				info: "Custom path shadow blur radius bypassing AppKit window boundaries.",
			},
		],
	},
	{
		id: "pointer",
		name: "Pointer Gate",
		monogram: "PP",
		blurb:
			"A hover delay filters pointers merely transiting to the menu bar, and a cancel grace absorbs jitter at the cutout edge.",
		params: [
			{
				name: "hoverOpenDelay",
				type: "TimeInterval",
				defaultValue: "0.15",
				info: "Hysteresis gate filtering pointers merely passing through to menu bar.",
			},
			{
				name: "hoverCancelGrace",
				type: "TimeInterval",
				defaultValue: "0.10",
				info: "Boundary tremor grace period preventing accidental closes on edge exit.",
			},
			{
				name: "collapsedHitPadding",
				type: "CGFloat",
				defaultValue: "6",
				info: "Invisible margin surrounding collapsed pill expanding the hit target.",
			},
		],
	},
	{
		id: "reserve",
		name: "Top Reserve",
		monogram: "TR",
		blurb:
			"How much of the open panel stays clear of the cutout. The highlighted strip is space your content never has to think about.",
		params: [
			{
				name: "expandedTopReserve",
				type: "Policy",
				defaultValue: ".cutoutOnly",
				info: "Policy controlling top space reserved clear of hardware cutout.",
			},
			{
				name: "expandedContentInsets",
				type: "EdgeInsets",
				defaultValue: "derived",
				info: "Derived padding ensuring content stays clear of silhouette tapers.",
			},
		],
	},
	{
		id: "bars",
		name: "Activity Bars",
		monogram: "NB",
		blurb:
			"Equalizer bars for the collapsed pill, driven by CoreAnimation off the main thread. A bar with no peak has zero animation overhead.",
		params: [
			{
				name: "levels",
				type: "[CGFloat]",
				defaultValue: "0...1",
				info: "Resting level height of each bar as a fraction (0...1).",
			},
			{
				name: "period",
				type: "TimeInterval",
				defaultValue: "0.9",
				info: "Duration of one complete level-to-peak bounce cycle off main thread.",
			},
			{
				name: "stagger",
				type: "TimeInterval",
				defaultValue: "0.15",
				info: "Phase stagger delay between adjacent bars creating dynamic wave motion.",
			},
		],
	},
];

const INK_PRESETS = [
	{ id: "standard", label: ".standard", ink: "#000000" },
	{ id: "warmPaper", label: ".warmPaper", ink: "#0d0d0f" },
	{ id: "translucent", label: ".translucent", ink: "rgba(0,0,0,0.72)" },
] as const;

function lerp(a: number, b: number, t: number) {
	return a + (b - a) * t;
}

function InfoTooltip({ text }: { text: string }) {
	return (
		<div className="group relative inline-flex items-center">
			<span className="flex h-4 w-4 cursor-pointer items-center justify-center rounded-full bg-muted font-mono text-[10px] font-bold text-muted-foreground transition-colors hover:bg-foreground hover:text-background">
				i
			</span>
			<div className="pointer-events-none absolute bottom-full left-1/2 z-50 mb-1.5 hidden w-48 -translate-x-1/2 rounded-lg border border-border bg-popover p-2 font-sans text-[11px] leading-snug text-popover-foreground shadow-xl group-hover:block">
				{text}
				<div className="absolute -bottom-1 left-1/2 h-2 w-2 -translate-x-1/2 rotate-45 border-b border-r border-border bg-popover" />
			</div>
		</div>
	);
}

function SlidersIcon({ className }: { className?: string }) {
	return (
		<svg
			className={cn("h-3.5 w-3.5", className)}
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			strokeWidth={1.5}
		>
			<title>Tune parameters</title>
			<path
				strokeLinecap="round"
				strokeLinejoin="round"
				d="M10.5 6h9.75M10.5 6a1.5 1.5 0 1 1-3 0m3 0a1.5 1.5 0 1 0-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 1 1-3 0m3 0a1.5 1.5 0 1 0-3 0M3.75 18H7.5M13.5 12h6.75m-6.75 0a1.5 1.5 0 1 1-3 0m3 0a1.5 1.5 0 1 0-3 0M3.75 12H10.5"
			/>
		</svg>
	);
}

function ExpandIcon({ className }: { className?: string }) {
	return (
		<svg
			className={cn("h-4 w-4", className)}
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			strokeWidth={1.5}
		>
			<title>Expand canvas</title>
			<path
				strokeLinecap="round"
				strokeLinejoin="round"
				d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M20.25 3.75v4.5m0-4.5h-4.5m4.5 0L15 9m5.25 11.25v-4.5m0 4.5h-4.5m4.5 0L15 15m-11.25 5.25v-4.5m0 4.5h4.5m-4.5 0L9 15"
			/>
		</svg>
	);
}

function ShrinkIcon({ className }: { className?: string }) {
	return (
		<svg
			className={cn("h-4 w-4", className)}
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			strokeWidth={1.5}
		>
			<title>Shrink canvas</title>
			<path
				strokeLinecap="round"
				strokeLinejoin="round"
				d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M15 9V4.5M15 9h4.5M15 9l5.25-5.25M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 15v4.5M15 15h4.5M15 15l5.25 5.25"
			/>
		</svg>
	);
}

function CloseIcon({ className }: { className?: string }) {
	return (
		<svg
			className={cn("h-3.5 w-3.5", className)}
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			strokeWidth={1.5}
		>
			<title>Close panel</title>
			<path
				strokeLinecap="round"
				strokeLinejoin="round"
				d="M6 18L18 6M6 6l12 12"
			/>
		</svg>
	);
}

function Knob({
	label,
	value,
	min,
	max,
	onChange,
	format,
}: {
	label: string;
	value: number;
	min: number;
	max: number;
	onChange: (v: number) => void;
	format?: (v: number) => string;
}) {
	return (
		<label className="block">
			<span className="flex items-center justify-between text-xs text-muted-foreground">
				<span>{label}</span>
				<span className="font-mono font-medium text-foreground">
					{format ? format(value) : value}
				</span>
			</span>
			<input
				type="range"
				min={min}
				max={max}
				value={value}
				onChange={(e) => onChange(Number(e.target.value))}
				className="mt-1.5 w-full cursor-pointer accent-foreground"
			/>
		</label>
	);
}

export function MorphExplorer() {
	const [activeId, setActiveId] = useState<MorphElementId>("silhouette");
	const [phase, setPhase] = useState<"collapsed" | "expanded">("collapsed");
	const [reason, setReason] = useState<"hover" | "click" | null>(null);
	const [isCanvasExpanded, setIsCanvasExpanded] = useState(false);
	const hoverTimer = useRef<number | null>(null);

	// Live knobs
	const [stiffness, setStiffness] = useState(190);
	const [damping, setDamping] = useState(22);
	const [topRadius, setTopRadius] = useState(22);
	const [bottomRadius, setBottomRadius] = useState(22);
	const [cutoutWidth, setCutoutWidth] = useState(COLLAPSED.cutout);
	const [inkId, setInkId] =
		useState<(typeof INK_PRESETS)[number]["id"]>("standard");

	const open = phase === "expanded";
	const t = useSpringValue(open ? 1 : 0, { stiffness, damping });

	const width = lerp(COLLAPSED.width, EXPANDED.width, t);
	const height = lerp(COLLAPSED.height, EXPANDED.height, t);
	const topR = lerp(0, topRadius, t);
	const bottomR = lerp(COLLAPSED.bottomRadius, bottomRadius, t);
	const contentOpacity = Math.max(0, (t - 0.35) / 0.65);
	const collapsedOpacity = Math.max(0, 1 - t * 3);

	const active = ELEMENTS.find((e) => e.id === activeId) ?? ELEMENTS[0];
	const ink = INK_PRESETS.find((p) => p.id === inkId) ?? INK_PRESETS[0];

	const expand = useCallback((why: "hover" | "click") => {
		setReason(why);
		setPhase("expanded");
	}, []);

	const collapse = useCallback(() => {
		setReason(null);
		setPhase("collapsed");
	}, []);

	const onPointerEnter = () => {
		if (open) return;
		hoverTimer.current = window.setTimeout(() => expand("hover"), 150);
	};

	const onPointerLeave = () => {
		if (hoverTimer.current) {
			window.clearTimeout(hoverTimer.current);
			hoverTimer.current = null;
		}
		if (reason === "hover") collapse();
	};

	const onClick = () => {
		if (hoverTimer.current) {
			window.clearTimeout(hoverTimer.current);
			hoverTimer.current = null;
		}
		if (open && reason === "click") {
			collapse();
		} else {
			expand("click");
		}
	};

	return (
		<div className="flex flex-col items-center gap-8 w-full">
			{/* Canvas box with border */}
			<div
				className={cn(
					"relative flex flex-col items-center justify-center overflow-hidden rounded-2xl border border-border bg-card/40 transition-all duration-300 py-10",
					isCanvasExpanded
						? "min-h-[540px] -mx-4 sm:-mx-10 md:-mx-16 lg:-mx-24 w-[calc(100%+2rem)] sm:w-[calc(100%+5rem)] md:w-[calc(100%+8rem)] lg:w-[calc(100%+12rem)] max-w-7xl self-center"
						: "w-full min-h-[340px]",
				)}
			>
				{/* Top screen edge subtle hairline */}
				<div className="absolute inset-x-0 top-0 h-px bg-border/80" />

				{/* Top-Right Controls: Notch Toggle & Canvas Expand Button */}
				<div className="absolute top-3 right-3 z-30 flex items-center gap-2">
					<button
						type="button"
						onClick={() =>
							setPhase((p) => (p === "expanded" ? "collapsed" : "expanded"))
						}
						className="cursor-pointer rounded-full border border-border/80 bg-background/90 px-3 py-1 text-xs font-medium text-foreground backdrop-blur-md transition-colors hover:bg-accent"
					>
						{open ? "Collapse notch" : "Expand notch"}
					</button>
					<button
						type="button"
						onClick={() => setIsCanvasExpanded((e) => !e)}
						title={
							isCanvasExpanded ? "Collapse canvas view" : "Expand canvas view"
						}
						className="flex h-7 w-7 cursor-pointer items-center justify-center rounded-full border border-border/80 bg-background/90 text-muted-foreground backdrop-blur-md transition-colors hover:bg-accent hover:text-foreground"
					>
						{isCanvasExpanded ? <ShrinkIcon /> : <ExpandIcon />}
					</button>
				</div>

				{/* Bottom-Right Floating Tune Button */}
				<div className="absolute bottom-3 right-3 z-30">
					{!isCanvasExpanded ? (
						<button
							type="button"
							onClick={() => setIsCanvasExpanded(true)}
							className="flex cursor-pointer items-center gap-1.5 rounded-full border border-border/80 bg-background/90 px-3.5 py-1.5 font-mono text-xs font-medium text-foreground backdrop-blur-md shadow-xs transition-colors hover:bg-accent"
						>
							<SlidersIcon />
							<span>Tune</span>
						</button>
					) : (
						<button
							type="button"
							onClick={() => setIsCanvasExpanded(false)}
							className="flex cursor-pointer items-center gap-1.5 rounded-full border border-border/80 bg-background/90 px-3.5 py-1.5 font-mono text-xs font-medium text-muted-foreground backdrop-blur-md transition-colors hover:bg-accent hover:text-foreground"
						>
							<CloseIcon />
							<span>Close view</span>
						</button>
					)}
				</div>

				{/* Expanded Canvas Side Panels (Floating Left & Right) */}
				{isCanvasExpanded ? (
					<>
						{/* Left Panel: Customization Properties & Tooltips */}
						<div className="absolute top-12 left-4 z-20 hidden w-80 max-w-[calc(50vw-2.5rem)] rounded-2xl border border-border bg-background/90 p-4 shadow-xl backdrop-blur-md sm:block">
							<div className="mb-2 flex items-center justify-between">
								<div className="flex items-center gap-2">
									<span className="flex h-5 w-5 items-center justify-center rounded-md bg-foreground font-mono text-[10px] font-semibold text-background">
										{active.monogram}
									</span>
									<span className="font-mono text-xs font-semibold text-foreground">
										{active.name}
									</span>
								</div>
								<span className="rounded-full bg-muted px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-muted-foreground">
									Properties
								</span>
							</div>
							<p className="text-xs leading-relaxed text-muted-foreground">
								{active.blurb}
							</p>

							<div className="mt-3 grid gap-2">
								{active.params.map((p) => (
									<div
										key={p.name}
										className="flex items-center justify-between gap-2 rounded-lg border border-border/60 bg-card/80 px-2.5 py-1.5 font-mono text-xs"
									>
										<div className="flex min-w-0 items-center gap-1.5">
											<span className="truncate font-medium text-foreground">
												{p.name}
											</span>
											<InfoTooltip text={p.info} />
										</div>
										<div className="flex shrink-0 items-center gap-1 text-[11px]">
											<span className="text-muted-foreground">{p.type}</span>
											<span className="font-medium text-primary">
												= {p.defaultValue}
											</span>
										</div>
									</div>
								))}
							</div>
						</div>

						{/* Right Panel: Live Tuning Controls */}
						<div className="absolute top-12 right-4 z-20 hidden w-72 max-w-[calc(50vw-2.5rem)] rounded-2xl border border-border bg-background/90 p-4 shadow-xl backdrop-blur-md sm:block">
							<div className="mb-3 flex items-center justify-between">
								<span className="font-mono text-xs font-semibold uppercase tracking-wider text-foreground">
									Live Parameters
								</span>
								<span className="rounded-full bg-primary/10 px-2 py-0.5 font-mono text-[9px] text-primary">
									Tuning
								</span>
							</div>
							<div className="grid gap-2.5">
								<Knob
									label="topCornerRadius"
									value={topRadius}
									min={0}
									max={32}
									onChange={setTopRadius}
									format={(v) => `${v}px`}
								/>
								<Knob
									label="bottomCornerRadius"
									value={bottomRadius}
									min={8}
									max={32}
									onChange={setBottomRadius}
									format={(v) => `${v}px`}
								/>
								<Knob
									label="cutoutWidth"
									value={cutoutWidth}
									min={120}
									max={260}
									onChange={setCutoutWidth}
									format={(v) => `${v}px`}
								/>
								<Knob
									label="spring stiffness"
									value={stiffness}
									min={80}
									max={400}
									onChange={setStiffness}
								/>
								<Knob
									label="spring damping"
									value={damping}
									min={8}
									max={60}
									onChange={setDamping}
								/>
								<div>
									<span className="block text-xs text-muted-foreground">
										ink preset
									</span>
									<div className="mt-1 grid grid-cols-3 gap-1 rounded-full border border-border bg-background p-1">
										{INK_PRESETS.map((p) => (
											<button
												key={p.id}
												type="button"
												onClick={() => setInkId(p.id)}
												className={cn(
													"cursor-pointer truncate rounded-full px-1 py-0.5 text-center font-mono text-[10px] transition-colors",
													inkId === p.id
														? "bg-muted font-medium text-foreground"
														: "text-muted-foreground hover:text-foreground",
												)}
											>
												{p.label}
											</button>
										))}
									</div>
								</div>
							</div>
						</div>
					</>
				) : null}

				{/* Interactive Notch Viewport */}
				{/* biome-ignore lint/a11y/useSemanticElements: interactive canvas wrapper */}
				<div
					className="relative flex cursor-pointer flex-col items-center focus:outline-none"
					style={{ width: EXPANDED.width, height: EXPANDED.height + 24 }}
					onPointerEnter={onPointerEnter}
					onPointerLeave={onPointerLeave}
					onClick={onClick}
					onKeyDown={(e) => e.key === "Enter" && onClick()}
					role="button"
					tabIndex={-1}
					aria-label="Interactive morph explorer notch island"
				>
					<svg
						width={EXPANDED.width}
						height={EXPANDED.height + 24}
						viewBox={`0 0 ${EXPANDED.width} ${EXPANDED.height + 24}`}
						className="block overflow-visible drop-shadow-xl"
						role="img"
						aria-label="Interactive notch island silhouette"
					>
						<title>Interactive notch island silhouette</title>
						<g transform={`translate(${(EXPANDED.width - width) / 2} 0)`}>
							{/* Pointer hit target outline */}
							{activeId === "pointer" ? (
								<path
									d={notchPath(width + 12, height + 6, topR, bottomR)}
									transform="translate(-6 0)"
									fill="none"
									stroke="var(--foreground)"
									strokeWidth="1.5"
									strokeDasharray="5 4"
									opacity="0.75"
								/>
							) : null}

							{/* Ink body */}
							<path
								d={notchPath(width, height, topR, bottomR)}
								fill={ink.ink}
								style={{ transition: "fill 200ms" }}
							/>

							{/* Single non-duplicated shape border */}
							{activeId === "silhouette" || activeId === "motion" ? (
								<path
									d={notchPath(width, height, topR, bottomR)}
									fill="none"
									stroke="var(--foreground)"
									strokeWidth="2"
									strokeDasharray="6 4"
								/>
							) : (
								<path
									d={notchPath(width - 1.5, height - 1.5, topR, bottomR)}
									transform="translate(0.75 0.75)"
									fill="none"
									stroke={
										activeId === "style" ? "var(--foreground)" : "var(--border)"
									}
									strokeWidth={activeId === "style" ? 1.5 : 1}
								/>
							)}

							{/* Cutout area indicator */}
							{activeId === "cutout" ? (
								<rect
									x={(width - Math.min(cutoutWidth, width)) / 2}
									y="0"
									width={Math.min(cutoutWidth, width)}
									height={COLLAPSED.height - 6}
									rx="10"
									fill="var(--foreground)"
									fillOpacity="0.12"
									stroke="var(--foreground)"
									strokeOpacity="0.6"
									strokeWidth="1.5"
								/>
							) : null}

							{/* Top reserve indicator */}
							{activeId === "reserve" && t > 0.4 ? (
								<rect
									x={topR + 8}
									y="4"
									width={width - 2 * (topR + 8)}
									height={COLLAPSED.height - 4}
									rx="8"
									fill="var(--foreground)"
									fillOpacity="0.12"
									stroke="var(--foreground)"
									strokeOpacity="0.6"
									strokeWidth="1.5"
								/>
							) : null}
						</g>
					</svg>

					{/* Collapsed content inside island */}
					<div
						className="pointer-events-none absolute top-0 left-1/2 flex -translate-x-1/2 items-center px-1"
						style={{
							width: COLLAPSED.width,
							height: COLLAPSED.height,
							opacity: collapsedOpacity,
						}}
					>
						<div className="flex flex-1 items-center justify-center px-2">
							<span className="flex items-center gap-1" aria-hidden>
								{[0, 1, 2].map((i) => (
									<span
										key={i}
										className={cn(
											"w-0.5 rounded-full bg-white",
											activeId === "bars" ? "animate-eq" : "",
										)}
										style={{
											height: activeId === "bars" ? 14 : 10,
											animationDelay: `${i * 0.15}s`,
										}}
									/>
								))}
							</span>
						</div>
						<div
							className="flex items-center justify-center rounded-b-xl bg-black"
							style={{
								width: Math.min(cutoutWidth, COLLAPSED.width - 64),
								height: COLLAPSED.height - 6,
							}}
						>
							<span className="h-2 w-2 rounded-full bg-neutral-800 ring-1 ring-neutral-700/60" />
						</div>
						<div className="flex flex-1 items-center justify-center px-2">
							<span className="font-mono text-xs font-semibold text-white">
								3
							</span>
						</div>
					</div>

					{/* Expanded panel content preview */}
					{t > 0.05 ? (
						<div
							className="pointer-events-none absolute top-0 left-1/2 flex -translate-x-1/2 flex-col justify-between px-9 pb-[30px] pt-[58px] text-white"
							style={{
								width,
								height,
								opacity: contentOpacity,
							}}
						>
							{/* Top header row inside panel */}
							<div className="flex items-center gap-3">
								<div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/10 backdrop-blur-xs ring-1 ring-white/15">
									<span className="flex items-center gap-0.5">
										{[0, 1, 2].map((i) => (
											<span
												key={i}
												className="h-3.5 w-0.5 animate-eq rounded-full bg-white"
												style={{ animationDelay: `${i * 0.15}s` }}
											/>
										))}
									</span>
								</div>
								<div className="min-w-0 flex-1">
									<p className="truncate text-xs font-semibold text-white">
										Live Morph Surface
									</p>
									<p className="truncate text-[11px] text-white/70">
										Single-surface continuous geometry
									</p>
								</div>
								<span className="shrink-0 rounded-full border border-white/20 bg-white/10 px-2 py-0.5 font-mono text-[10px] text-white/90">
									{open ? "Expanded" : "Morphing"}
								</span>
							</div>

							{/* Scrubber & transport controls at bottom */}
							<div className="space-y-2">
								<div className="h-1 w-full overflow-hidden rounded-full bg-white/20">
									<div className="h-full w-2/3 rounded-full bg-white" />
								</div>
								<div className="flex items-center justify-between text-[10px] text-white/70 font-mono">
									<div className="flex gap-1">
										<span className="rounded-md border border-white/15 bg-white/10 px-1.5 py-0.5">
											Prev
										</span>
										<span className="rounded-md border border-white/15 bg-white/10 px-1.5 py-0.5">
											Pause
										</span>
										<span className="rounded-md border border-white/15 bg-white/10 px-1.5 py-0.5">
											Next
										</span>
									</div>
									<span className="opacity-80">2:41</span>
								</div>
							</div>
						</div>
					) : null}
				</div>

				{/* Live metrics strip below notch */}
				<div className="mt-6 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 font-mono text-xs text-muted-foreground">
					<span>
						w <span className="text-foreground">{Math.round(width)}</span>
					</span>
					<span>
						h <span className="text-foreground">{Math.round(height)}</span>
					</span>
					<span>
						topR <span className="text-foreground">{topR.toFixed(1)}</span>
					</span>
					<span>
						bottomR{" "}
						<span className="text-foreground">{bottomR.toFixed(1)}</span>
					</span>
				</div>
			</div>

			{/* Wrapped element selector pills - placed directly below the canvas box */}
			<div className="flex flex-wrap items-center justify-center gap-2">
				{ELEMENTS.map((elem) => {
					const isActive = elem.id === activeId;
					return (
						<button
							key={elem.id}
							type="button"
							onClick={() => setActiveId(elem.id)}
							onMouseEnter={() => setActiveId(elem.id)}
							className={cn(
								"flex cursor-pointer items-center gap-2 rounded-full px-3.5 py-1.5 font-mono text-xs transition-all",
								isActive
									? "bg-foreground font-medium text-background shadow-xs"
									: "bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground",
							)}
						>
							<span className="font-semibold">{elem.monogram}</span>
							<span>{elem.name}</span>
						</button>
					);
				})}
			</div>
		</div>
	);
}
