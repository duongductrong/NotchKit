import type { ReactNode } from "react";
import { cn } from "#/lib/cn";

const KEYWORDS = new Set([
	"import",
	"struct",
	"class",
	"enum",
	"case",
	"let",
	"var",
	"func",
	"return",
	"if",
	"else",
	"guard",
	"for",
	"in",
	"public",
	"private",
	"static",
	"self",
	"nil",
	"true",
	"false",
	"some",
	"init",
	"extension",
	"final",
	"where",
	"switch",
	"default",
	"internal",
	"async",
	"await",
	"try",
	"throws",
	"rethrows",
	"associatedtype",
	"protocol",
	"typealias",
]);

const TOKEN_RE =
	/(\/\/[^\n]*)|("(?:[^"\\]|\\.)*")|(\b\d[\d_]*(?:\.\d+)?\b)|(\b[A-Z][A-Za-z0-9_]*\b)|(\b[a-z_][A-Za-z0-9_]*\b)|([\s\S])/g;

function highlightSwift(code: string): ReactNode[] {
	const nodes: ReactNode[] = [];
	let key = 0;
	for (const match of code.matchAll(TOKEN_RE)) {
		const [text, comment, str, num, typeIdent, ident] = match;
		key += 1;
		if (comment) {
			nodes.push(
				<span key={key} className="text-code-comment">
					{text}
				</span>,
			);
		} else if (str) {
			nodes.push(
				<span key={key} className="text-code-string">
					{text}
				</span>,
			);
		} else if (num) {
			nodes.push(
				<span key={key} className="text-code-number">
					{text}
				</span>,
			);
		} else if (typeIdent) {
			nodes.push(
				<span key={key} className="text-code-type">
					{text}
				</span>,
			);
		} else if (ident) {
			nodes.push(
				<span
					key={key}
					className={
						KEYWORDS.has(ident) ? "text-code-keyword" : "text-code-token"
					}
				>
					{text}
				</span>,
			);
		} else {
			nodes.push(<span key={key}>{text}</span>);
		}
	}
	return nodes;
}

type CodeBlockProps = {
	code: string;
	language?: "swift" | "text";
	filename?: string;
	className?: string;
};

export function CodeBlock({
	code,
	language = "swift",
	filename,
	className,
}: CodeBlockProps) {
	return (
		<div
			className={cn(
				"overflow-hidden rounded-xl border border-border bg-card",
				className,
			)}
		>
			{filename ? (
				<div className="border-b border-border px-4 py-2 font-mono text-xs text-muted-foreground">
					{filename}
				</div>
			) : null}
			<pre className="overflow-x-auto p-4 text-xs leading-relaxed text-foreground">
				<code>{language === "swift" ? highlightSwift(code) : code}</code>
			</pre>
		</div>
	);
}
