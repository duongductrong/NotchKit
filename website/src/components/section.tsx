import type { ReactNode } from "react";
import { cn } from "#/lib/cn";

type SectionProps = {
	id?: string;
	eyebrow?: string;
	title: string;
	description?: ReactNode;
	children: ReactNode;
	className?: string;
};

export function Section({
	id,
	eyebrow,
	title,
	description,
	children,
	className,
}: SectionProps) {
	return (
		<section
			id={id}
			className={cn("mx-auto w-full max-w-5xl px-6 py-24", className)}
		>
			{eyebrow ? (
				<p className="mb-3 font-mono text-xs uppercase tracking-widest text-muted-foreground">
					{eyebrow}
				</p>
			) : null}
			<h2 className="text-3xl font-semibold tracking-tight text-foreground">
				{title}
			</h2>
			{description ? (
				<div className="mt-4 max-w-2xl text-base leading-relaxed text-muted-foreground">
					{description}
				</div>
			) : null}
			<div className="mt-12">{children}</div>
		</section>
	);
}

type CardProps = {
	children: ReactNode;
	className?: string;
};

export function Card({ children, className }: CardProps) {
	return (
		<div
			className={cn(
				"rounded-2xl border border-border bg-card p-6 shadow-lg shadow-background",
				className,
			)}
		>
			{children}
		</div>
	);
}
