import { useCallback, useEffect, useRef, useState } from "react";
import { cn } from "#/lib/cn";

// Collapsed geometry mirrors NotchGeometry.simulatedNotch* and
// NotchConfiguration.collapsedWidth = .wrapCutout(reserve: 44).
const COLLAPSED = {
	width: 278,
	height: 38,
	cutout: 190,
	// NotchConfiguration.collapsedTopCornerRadius — a slight flare into the bezel,
	// a fraction of the expanded curl.
	topRadius: 6,
	bottomRadius: 19,
};
const EXPANDED = { width: 440, height: 210, topRadius: 22, bottomRadius: 22 };

const OPEN_SPRING = { stiffness: 190, damping: 22 };
const CLOSE_SPRING = { stiffness: 260, damping: 34 };

type SpringConfig = { stiffness: number; damping: number };

export function useSpringValue(target: number, config: SpringConfig) {
	const [value, setValue] = useState(target);
	const state = useRef({ x: target, v: 0 });
	const configRef = useRef(config);
	configRef.current = config;

	useEffect(() => {
		let raf = 0;
		let last = performance.now();
		const loop = (now: number) => {
			const dt = Math.min((now - last) / 1000, 0.032);
			last = now;
			const s = state.current;
			const { stiffness, damping } = configRef.current;
			const force = -stiffness * (s.x - target) - damping * s.v;
			s.v += force * dt;
			s.x += s.v * dt;
			setValue(s.x);
			if (Math.abs(s.x - target) > 0.0005 || Math.abs(s.v) > 0.0005) {
				raf = requestAnimationFrame(loop);
			} else {
				s.x = target;
				s.v = 0;
				setValue(target);
			}
		};
		raf = requestAnimationFrame(loop);
		return () => cancelAnimationFrame(raf);
	}, [target]);

	return value;
}

function lerp(a: number, b: number, t: number) {
	return a + (b - a) * t;
}

// Port of NotchShape.path(in:) — same corner-fillet recipe, concave top,
// convex bottom, same radius clamping.
export function notchPath(
	width: number,
	height: number,
	top: number,
	bottom: number,
) {
	const r = Math.max(0, Math.min(top, width / 4, height / 4));
	const b = Math.max(0, Math.min(bottom, (width - 2 * r) / 2, height - r));
	return [
		`M 0 0`,
		`Q ${r} 0 ${r} ${r}`,
		`L ${r} ${height - b}`,
		`Q ${r} ${height} ${r + b} ${height}`,
		`L ${width - r - b} ${height}`,
		`Q ${width - r} ${height} ${width - r} ${height - b}`,
		`L ${width - r} ${r}`,
		`Q ${width - r} 0 ${width} 0`,
		`Z`,
	].join(" ");
}

function EqualizerBars({ className }: { className?: string }) {
	return (
		<span className={cn("flex items-center gap-1", className)} aria-hidden>
			{[0, 1, 2].map((i) => (
				<span
					key={i}
					className="w-0.5 animate-eq rounded-full bg-foreground"
					style={{ height: 14, animationDelay: `${i * 0.15}s` }}
				/>
			))}
		</span>
	);
}

function ExpandedPanelContent({ opacity }: { opacity: number }) {
	return (
		<div
			className="flex h-full flex-col justify-between px-9 pb-[30px] pt-[58px]"
			style={{ opacity }}
		>
			<div className="flex items-center gap-4">
				<div className="flex h-12 w-12 items-center justify-center rounded-lg bg-muted">
					<EqualizerBars />
				</div>
				<div className="min-w-0 flex-1">
					<p className="truncate text-sm font-medium text-foreground">
						Midnight Run
					</p>
					<p className="truncate text-xs text-muted-foreground">
						The Night Tapes — Afterglow
					</p>
				</div>
				<span className="font-mono text-xs text-muted-foreground">2:41</span>
			</div>
			<div className="h-1 overflow-hidden rounded-full bg-muted">
				<div className="h-full w-2/3 rounded-full bg-foreground" />
			</div>
			<div className="flex items-center justify-between">
				<div className="flex gap-2">
					{["Prev", "Pause", "Next"].map((label) => (
						<span
							key={label}
							className="rounded-full border border-border px-3 py-1 text-xs text-muted-foreground"
						>
							{label}
						</span>
					))}
				</div>
				<span className="text-xs text-muted-foreground">
					hover to open · click to pin
				</span>
			</div>
		</div>
	);
}

// Self-toggling morph used in the "one shape morphs" section — the same spring
// and silhouette as the hero island, looping collapsed ↔ expanded.
export function MorphLoop() {
	const [open, setOpen] = useState(false);
	useEffect(() => {
		const id = window.setInterval(() => setOpen((o) => !o), 2400);
		return () => window.clearInterval(id);
	}, []);
	const t = useSpringValue(open ? 1 : 0, open ? OPEN_SPRING : CLOSE_SPRING);

	const width = lerp(180, 340, t);
	const height = lerp(28, 130, t);
	// Scaled to this illustration's 28pt pill, same ratio the library uses at 38.
	const topRadius = lerp(4, 22, t);
	const bottomRadius = lerp(14, 22, t);

	return (
		<svg
			width={360}
			height={150}
			viewBox={"0 0 360 150"}
			className="block"
			role="img"
			aria-label="Notch island morphing between collapsed and expanded"
		>
			<title>Island morph</title>
			<line
				x1="0"
				y1="0.5"
				x2="360"
				y2="0.5"
				stroke="var(--border)"
				strokeWidth="1"
			/>
			<path
				d={notchPath(width, height, topRadius, bottomRadius)}
				transform={`translate(${(360 - width) / 2} 4)`}
				fill="var(--muted)"
				stroke="var(--muted-foreground)"
				strokeWidth="1.5"
			/>
		</svg>
	);
}

export function NotchSimulator() {
	const [phase, setPhase] = useState<"collapsed" | "expanded">("collapsed");
	const [reason, setReason] = useState<"hover" | "click" | null>(null);
	const [peekKey, setPeekKey] = useState(0);
	const hoverTimer = useRef<number | null>(null);

	const open = phase === "expanded";
	const t = useSpringValue(open ? 1 : 0, open ? OPEN_SPRING : CLOSE_SPRING);

	const width = lerp(COLLAPSED.width, EXPANDED.width, t);
	const height = lerp(COLLAPSED.height, EXPANDED.height, t);
	const topRadius = lerp(COLLAPSED.topRadius, EXPANDED.topRadius, t);
	const bottomRadius = lerp(COLLAPSED.bottomRadius, EXPANDED.bottomRadius, t);
	const contentOpacity = Math.max(0, (t - 0.35) / 0.65);
	const collapsedOpacity = Math.max(0, 1 - t * 3);

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

	useEffect(() => {
		if (!open || reason !== "click") return;
		const onDown = (event: MouseEvent) => {
			if (
				!(event.target instanceof Element) ||
				!event.target.closest("[data-notch-island]")
			) {
				collapse();
			}
		};
		document.addEventListener("mousedown", onDown);
		return () => document.removeEventListener("mousedown", onDown);
	}, [open, reason, collapse]);

	const peek = () => {
		if (open) return;
		setPeekKey((k) => k + 1);
	};

	return (
		<>
			<div className="fixed inset-x-0 top-0 z-50 flex justify-center pointer-events-none">
				{/* biome-ignore lint/a11y/useSemanticElements: a fixed overlay island cannot be a <button>; it contains block content */}
				<div
					data-notch-island
					className="pointer-events-auto relative cursor-pointer focus:outline-none flex flex-col items-center"
					style={{ width, height }}
					onPointerEnter={onPointerEnter}
					onPointerLeave={onPointerLeave}
					onClick={onClick}
					onKeyDown={(e) => e.key === "Enter" && onClick()}
					role="button"
					tabIndex={-1}
					aria-label="NotchKit island demo"
				>
					<div
						key={peekKey}
						className={peekKey > 0 ? "animate-peek" : undefined}
					>
						{/* biome-ignore lint/a11y/noSvgWithoutTitle: decorative island silhouette; the wrapper carries the label */}
						<svg
							width={width}
							height={height}
							viewBox={`0 0 ${width} ${height}`}
							className="block drop-shadow-xl"
							aria-hidden
						>
							<path
								d={notchPath(width, height, topRadius, bottomRadius)}
								fill="var(--notch-ink)"
							/>
							<path
								d={notchPath(
									width - 1.5,
									height - 1.5,
									topRadius,
									bottomRadius,
								)}
								transform="translate(0.75 0.75)"
								fill="none"
								stroke="var(--border)"
								strokeWidth="1"
							/>
						</svg>
					</div>

					{/* Collapsed content: leading / cutout / trailing, like NotchCutoutLayout */}
					<div
						className="pointer-events-none absolute top-0 left-1/2 -translate-x-1/2 flex items-center"
						style={{
							width: COLLAPSED.width,
							height: COLLAPSED.height,
							opacity: collapsedOpacity,
						}}
					>
						<div className="flex flex-1 items-center justify-end pr-2">
							<EqualizerBars />
						</div>
						<div
							className="flex items-center justify-center rounded-b-xl bg-card"
							style={{ width: COLLAPSED.cutout, height: COLLAPSED.height - 6 }}
						>
							<span className="h-2 w-2 rounded-full bg-muted ring-1 ring-border" />
						</div>
						<div className="flex flex-1 items-center pl-2">
							<span className="font-mono text-xs text-foreground">3</span>
						</div>
					</div>

					{/* Expanded content */}
					{t > 0.05 ? (
						<div
							className="pointer-events-none absolute top-0 left-0"
							style={{ width, height }}
						>
							<ExpandedPanelContent opacity={contentOpacity} />
						</div>
					) : null}
				</div>
			</div>

			<button
				type="button"
				onClick={peek}
				className="rounded-full border border-border bg-card px-4 py-1.5 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
			>
				Trigger a peek
			</button>
		</>
	);
}
