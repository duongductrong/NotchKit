import { cn } from "#/lib/cn";

export type Arg = {
	name: string;
	type: string;
	defaultValue?: string;
	description: string;
};

export function ArgTable({
	args,
	className,
}: {
	args: Arg[];
	className?: string;
}) {
	return (
		<div
			className={cn(
				"overflow-x-auto rounded-xl border border-border",
				className,
			)}
		>
			<table className="w-full table-fixed border-collapse text-left text-sm">
				<colgroup>
					<col className="w-1/4" />
					<col className="w-1/5" />
					<col className="w-1/5" />
					<col />
				</colgroup>
				<thead>
					<tr className="border-b border-border bg-muted">
						<th className="px-4 py-2.5 font-medium text-muted-foreground">
							Parameter
						</th>
						<th className="px-4 py-2.5 font-medium text-muted-foreground">
							Type
						</th>
						<th className="px-4 py-2.5 font-medium text-muted-foreground">
							Default
						</th>
						<th className="px-4 py-2.5 font-medium text-muted-foreground">
							Description
						</th>
					</tr>
				</thead>
				<tbody>
					{args.map((arg) => (
						<tr
							key={arg.name}
							className="border-b border-border last:border-b-0"
						>
							<td className="px-4 py-2.5 align-top font-mono text-xs break-words text-foreground">
								{arg.name}
							</td>
							<td className="px-4 py-2.5 align-top font-mono text-xs break-words text-code-type">
								{arg.type}
							</td>
							<td className="px-4 py-2.5 align-top font-mono text-xs break-words text-muted-foreground">
								{arg.defaultValue ?? "—"}
							</td>
							<td className="px-4 py-2.5 align-top text-muted-foreground">
								{arg.description}
							</td>
						</tr>
					))}
				</tbody>
			</table>
		</div>
	);
}
