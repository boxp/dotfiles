import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

type NovelPhase =
	| "awaiting_request"
	| "plot_drafting"
	| "plot_review"
	| "plot_revision"
	| "chapter_drafting"
	| "chapter_review"
	| "chapter_revision"
	| "final_review"
	| "final_saved"
	| "cancelled";

type NovelRating = "SFW" | "NSFW";

interface HitohakoNovelState {
	schemaVersion: 1;
	sessionId: string;
	branchRootId?: string;
	slug: string;
	title: string;
	phase: NovelPhase;
	createdAt: number;
	updatedAt: number;
	userRequest?: string;
	plotPath: string;
	chapterDir: string;
	chapterPaths: Record<string, string>;
	acceptedChapters: number[];
	currentChapter: number;
	plannedChapterCount?: number;
	finalPath?: string;
	rating?: NovelRating;
	revisionPrompts: {
		plot: string[];
		chapters: Record<string, string[]>;
	};
	universeContextSummary: {
		files: string[];
		totalChars: number;
		truncated: boolean;
	};
}

const VAULT_ROOT = "/home/boxp/Documents/obsidian-headless/BOXP";
const UNIVERSE_ROOT = join(VAULT_ROOT, "ひとはこさんバース");
const DRAFT_ROOT = join(VAULT_ROOT, "draft");
const CHAPTER_DRAFT_ROOT = join(DRAFT_ROOT, "paragraph");
const SFW_OUTPUT_ROOT = join(VAULT_ROOT, "小説草案", "AI執筆");
const NSFW_OUTPUT_ROOT = join(VAULT_ROOT, "NSFW", "小説", "AI執筆");

const STATE_ENTRY = "hitohako-novel-harness-state";
const CONTEXT_ENTRY = "hitohako-novel-harness-context";
const MAX_UNIVERSE_CONTEXT_CHARS = 140_000;

const EMPTY_PARAMS = Type.Object({});

const SET_REQUEST_PARAMS = Type.Object({
	userRequest: Type.String({ description: "User's writing request for this novel." }),
});

const SAVE_PLOT_PARAMS = Type.Object({
	title: Type.String({ description: "Novel title." }),
	plotMarkdown: Type.String({ description: "Complete plot markdown." }),
	chapterCount: Type.Optional(Type.Number({ description: "Planned chapter count. If omitted, inferred from plot." })),
});

const REVISE_PLOT_PARAMS = Type.Object({
	additionalPrompt: Type.String({ description: "User's additional prompt for revising the plot." }),
});

const SAVE_CHAPTER_PARAMS = Type.Object({
	chapterNumber: Type.Number({ description: "Chapter number to save." }),
	chapterMarkdown: Type.String({ description: "Complete chapter markdown." }),
});

const REVISE_CHAPTER_PARAMS = Type.Object({
	chapterNumber: Type.Optional(Type.Number({ description: "Chapter number to revise. Defaults to current chapter." })),
	additionalPrompt: Type.String({ description: "User's additional prompt for revising the chapter." }),
});

const ACCEPT_CHAPTER_PARAMS = Type.Object({
	chapterNumber: Type.Optional(Type.Number({ description: "Chapter number to accept. Defaults to current chapter." })),
});

const SAVE_FINAL_PARAMS = Type.Object({
	rating: Type.Union([Type.Literal("SFW"), Type.Literal("NSFW")]),
	finalMarkdown: Type.String({ description: "The complete final novel body or markdown." }),
});

function nowSeconds(): number {
	return Math.floor(Date.now() / 1000);
}

function timestampSlugPrefix(): string {
	const date = new Date();
	const pad = (value: number) => String(value).padStart(2, "0");
	return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}-${pad(date.getHours())}-${pad(date.getMinutes())}`;
}

function sanitizeSlugPart(input: string): string {
	const slug = input
		.trim()
		.replace(/[\\/:*?"<>|#%{}[\]^~`]+/g, "")
		.replace(/\s+/g, "-")
		.slice(0, 48);
	return slug || "hitohako-novel";
}

function makeUniqueSuffix(): string {
	const cryptoApi = globalThis.crypto as { randomUUID?: () => string } | undefined;
	return cryptoApi?.randomUUID?.().slice(0, 8) ?? `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;
}

function getSessionId(ctx: ExtensionContext): string {
	const manager = ctx.sessionManager as unknown as { id?: string; sessionId?: string; filePath?: string; path?: string };
	return manager.id ?? manager.sessionId ?? manager.filePath ?? manager.path ?? "unknown-session";
}

function getBranchRootId(ctx: ExtensionContext): string | undefined {
	const branch = ctx.sessionManager.getBranch();
	return branch[0]?.id;
}

function isNovelState(value: unknown): value is HitohakoNovelState {
	const state = value as Partial<HitohakoNovelState> | undefined;
	return state?.schemaVersion === 1 && typeof state.slug === "string" && typeof state.phase === "string";
}

function loadStateFromBranch(ctx: ExtensionContext): HitohakoNovelState | undefined {
	let state: HitohakoNovelState | undefined;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== STATE_ENTRY) continue;
		if (isNovelState(entry.data)) state = entry.data;
	}
	return state;
}

function ensureDirectories() {
	mkdirSync(DRAFT_ROOT, { recursive: true });
	mkdirSync(CHAPTER_DRAFT_ROOT, { recursive: true });
	mkdirSync(SFW_OUTPUT_ROOT, { recursive: true });
	mkdirSync(NSFW_OUTPUT_ROOT, { recursive: true });
}

function collectMarkdownFiles(root: string): string[] {
	if (!existsSync(root)) return [];
	const result: string[] = [];
	for (const name of readdirSync(root)) {
		const path = join(root, name);
		const stat = statSync(path);
		if (stat.isDirectory()) {
			if (name === "attachments") continue;
			result.push(...collectMarkdownFiles(path));
		} else if (stat.isFile() && name.endsWith(".md")) {
			result.push(path);
		}
	}
	return result.sort();
}

function readUniverseContext() {
	const files = collectMarkdownFiles(UNIVERSE_ROOT);
	const chunks: string[] = [];
	let totalChars = 0;
	let truncated = false;

	for (const file of files) {
		const relPath = relative(VAULT_ROOT, file);
		const content = readFileSync(file, "utf8");
		const chunk = `\n\n## ${relPath}\n\n${content.trim()}\n`;
		if (totalChars + chunk.length > MAX_UNIVERSE_CONTEXT_CHARS) {
			const remaining = MAX_UNIVERSE_CONTEXT_CHARS - totalChars;
			if (remaining > 0) chunks.push(chunk.slice(0, remaining));
			truncated = true;
			totalChars = MAX_UNIVERSE_CONTEXT_CHARS;
			break;
		}
		chunks.push(chunk);
		totalChars += chunk.length;
	}

	return {
		content: chunks.join("").trim(),
		summary: { files: files.map((file) => relative(VAULT_ROOT, file)), totalChars, truncated },
	};
}

function inferChapterCount(plotMarkdown: string): number {
	const chapterPlan = plotMarkdown.match(/##\s*Chapter Plan([\s\S]*?)(?:\n##\s|$)|##\s*章構成([\s\S]*?)(?:\n##\s|$)/);
	const target = chapterPlan?.[1] ?? chapterPlan?.[2] ?? plotMarkdown;
	const numbered = target.match(/^\s*(?:\d+\.|第\s*\d+\s*章)/gm);
	return Math.max(1, numbered?.length ?? 1);
}

function createState(ctx: ExtensionContext, userRequest?: string): HitohakoNovelState {
	ensureDirectories();
	const titleSeed = userRequest?.split(/\n/, 1)[0] ?? "hitohako-novel";
	const slug = `${timestampSlugPrefix()}_${sanitizeSlugPart(titleSeed)}-${makeUniqueSuffix()}`;
	const universe = readUniverseContext();
	const ts = nowSeconds();
	return {
		schemaVersion: 1,
		sessionId: getSessionId(ctx),
		branchRootId: getBranchRootId(ctx),
		slug,
		title: "hitohako novel",
		phase: userRequest ? "plot_drafting" : "awaiting_request",
		createdAt: ts,
		updatedAt: ts,
		userRequest,
		plotPath: join(DRAFT_ROOT, `plot-${slug}.md`),
		chapterDir: CHAPTER_DRAFT_ROOT,
		chapterPaths: {},
		acceptedChapters: [],
		currentChapter: 1,
		revisionPrompts: { plot: [], chapters: {} },
		universeContextSummary: universe.summary,
	};
}

function transition(state: HitohakoNovelState, patch: Partial<HitohakoNovelState>): HitohakoNovelState {
	return { ...state, ...patch, updatedAt: nowSeconds() };
}

function textResult(text: string, details?: unknown, isError = false) {
	return {
		content: [{ type: "text" as const, text }],
		details,
		isError,
	};
}

function requirePhase(state: HitohakoNovelState, allowed: NovelPhase[]) {
	if (allowed.includes(state.phase)) return undefined;
	return textResult(`Invalid phase: expected ${allowed.join(" or ")}, got ${state.phase}.`, { state }, true);
}

function requireCurrentChapter(state: HitohakoNovelState, chapterNumber: number) {
	if (chapterNumber === state.currentChapter) return undefined;
	return textResult(`Invalid chapter: expected current chapter ${state.currentChapter}, got ${chapterNumber}.`, { state }, true);
}

function allPlannedChaptersAccepted(state: HitohakoNovelState, acceptedChapters: number[]): boolean {
	if (state.plannedChapterCount === undefined) return false;
	const accepted = new Set(acceptedChapters);
	for (let chapter = 1; chapter <= state.plannedChapterCount; chapter += 1) {
		if (!accepted.has(chapter)) return false;
	}
	return true;
}

function summarizeState(state: HitohakoNovelState | undefined): string {
	if (!state) return "No hitohako novel harness state is recorded in this branch.";
	const lines = [
		`Slug: ${state.slug}`,
		`Title: ${state.title}`,
		`Phase: ${state.phase}`,
		`Plot: ${state.plotPath}`,
		`Current chapter: ${state.currentChapter}`,
		`Accepted chapters: ${state.acceptedChapters.length ? state.acceptedChapters.join(", ") : "none"}`,
		`Planned chapters: ${state.plannedChapterCount ?? "unknown"}`,
	];
	if (state.finalPath) lines.push(`Final: ${state.finalPath}`);
	return lines.join("\n");
}

function buildAgentContext(state: HitohakoNovelState, universeContext?: string): string {
	const common = `You are running the hitohako novel harness.

State:
${JSON.stringify(state, null, 2)}

Hard requirements:
- Write Japanese prose unless the user explicitly asks for another language.
- Use the hitohako-san universe context below as source material. Do not contradict it.
- Do not claim a plot, chapter, or final novel is saved until the matching tool succeeds.
- Review choices are "はい" and "追加プロンプト". If the user provides an additional prompt, call the matching revise tool before rewriting.
- Keep process notes out of chapter prose.`;

	const phaseInstruction = (() => {
		switch (state.phase) {
			case "awaiting_request":
				return "If the latest user message already contains the writing request, call set_hitohako_novel_request. Otherwise ask the user: プロットを作成するので書きたい内容を入力してください。";
			case "plot_drafting":
			case "plot_revision":
				return "Draft or revise the plot, then call save_hitohako_plot with title, plotMarkdown, and chapterCount if known. After the tool succeeds, ask the user to choose はい or 追加プロンプト.";
			case "plot_review":
				return "Wait for the user's response. If はい, call accept_hitohako_plot. If the user gives an additional prompt, call revise_hitohako_plot.";
			case "chapter_drafting":
			case "chapter_revision":
				return `Write chapter ${state.currentChapter}, then call save_hitohako_chapter. After the tool succeeds, ask the user to choose はい or 追加プロンプト.`;
			case "chapter_review":
				return "Wait for the user's response. If はい, call accept_hitohako_chapter. If the user gives an additional prompt, call revise_hitohako_chapter.";
			case "final_review":
				return "Output the complete novel from accepted chapters, ask the user to choose SFW or NSFW, then call save_hitohako_final with the selected rating and final markdown.";
			case "final_saved":
				return "The final novel is saved. Summarize the saved path.";
			case "cancelled":
				return "The harness was cancelled. Do not continue unless the user starts a new run.";
		}
	})();

	const universeBlock = universeContext
		? `\n\n<hitohako_universe_context>\n${universeContext}\n</hitohako_universe_context>`
		: "";

	return `<pi_internal_context source="hitohako-novel">
${common}

Next action:
${phaseInstruction}${universeBlock}
</pi_internal_context>`;
}

function makeContextMessage(state: HitohakoNovelState, universeContext?: string) {
	return {
		customType: CONTEXT_ENTRY,
		content: buildAgentContext(state, universeContext),
		display: false,
		details: {
			schemaVersion: 1,
			slug: state.slug,
			phase: state.phase,
			injectedAt: nowSeconds(),
		},
	};
}

function chapterPath(state: HitohakoNovelState, chapterNumber: number): string {
	return join(state.chapterDir, `${state.slug}-${chapterNumber}.md`);
}

function finalPathFor(state: HitohakoNovelState, rating: NovelRating): string {
	const root = rating === "NSFW" ? NSFW_OUTPUT_ROOT : SFW_OUTPUT_ROOT;
	return join(root, `${state.slug}.md`);
}

function normalizeFinalMarkdown(state: HitohakoNovelState, rating: NovelRating, finalMarkdown: string, finalPath: string): string {
	const body = finalMarkdown.trim();
	if (body.startsWith("---\n")) return `${body}\n`;
	const created = new Date().toISOString().slice(0, 10);
	const draftPlot = relative(dirname(finalPath), state.plotPath);
	return `---
created: ${created}
source: pi-agent
harness: hitohako-novel-harness
rating: ${rating}
draft_plot: ${draftPlot}
---

# ${state.title}

${body}
`;
}

export default function hitohakoNovelHarnessExtension(pi: ExtensionAPI) {
	let currentState: HitohakoNovelState | undefined;

	function restore(ctx: ExtensionContext) {
		currentState = loadStateFromBranch(ctx);
	}

	function save(state: HitohakoNovelState) {
		currentState = state;
		pi.appendEntry<HitohakoNovelState>(STATE_ENTRY, state);
	}

	function inject(state: HitohakoNovelState, triggerTurn: boolean, includeUniverse = false) {
		const universe = includeUniverse ? readUniverseContext().content : undefined;
		pi.sendMessage(makeContextMessage(state, universe), triggerTurn ? { triggerTurn: true } : undefined);
	}

	pi.on("session_start", (_event, ctx) => {
		restore(ctx);
	});

	pi.on("session_tree", (_event, ctx) => {
		restore(ctx);
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		restore(ctx);
		if (!currentState || ["final_saved", "cancelled"].includes(currentState.phase)) return;
		return { message: makeContextMessage(currentState) };
	});

	pi.registerCommand("hitohako-novel", {
		description: "Start, resume, inspect, or cancel the hitohako novel harness",
		getArgumentCompletions: (prefix) => {
			return ["start", "resume", "status", "cancel", "help"]
				.filter((item) => item.startsWith(prefix))
				.map((value) => ({ value, label: value }));
		},
		handler: async (args, ctx) => {
			restore(ctx);
			const input = args.trim();
			const [command, ...rest] = input.split(/\s+/);
			const subcommand = command || "start";

			if (subcommand === "help") {
				ctx.ui.notify("Usage: /hitohako-novel start [request] | resume | status | cancel", "info");
				return;
			}

			if (subcommand === "status") {
				ctx.ui.notify(summarizeState(currentState), currentState ? "info" : "warning");
				return;
			}

			if (subcommand === "resume") {
				if (!currentState || ["final_saved", "cancelled"].includes(currentState.phase)) {
					ctx.ui.notify("No active hitohako novel harness is available in this branch.", "warning");
					return;
				}
				inject(currentState, true, false);
				return;
			}

			if (subcommand === "cancel") {
				if (!currentState || ["final_saved", "cancelled"].includes(currentState.phase)) {
					ctx.ui.notify("No active hitohako novel harness to cancel.", "warning");
					return;
				}
				save(transition(currentState, { phase: "cancelled" }));
				ctx.ui.notify("Hitohako novel harness cancelled.", "info");
				return;
			}

			if (subcommand !== "start") {
				ctx.ui.notify("Unknown subcommand. Usage: /hitohako-novel start [request] | resume | status | cancel", "error");
				return;
			}

			if (currentState && !["final_saved", "cancelled"].includes(currentState.phase)) {
				ctx.ui.notify("A hitohako novel harness is already active. Use /hitohako-novel status, resume, or cancel.", "error");
				return;
			}

			const userRequest = rest.join(" ").trim() || undefined;
			const state = createState(ctx, userRequest);
			save(state);
			pi.setSessionName(`Hitohako novel: ${state.slug.slice(17, 57)}`);
			inject(state, true, true);
		},
	});

	pi.registerTool({
		name: "get_hitohako_novel_state",
		label: "Get Hitohako Novel State",
		description: "Get the current hitohako novel harness state.",
		promptGuidelines: ["Use when phase, file paths, or current chapter are uncertain."],
		parameters: EMPTY_PARAMS,
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			restore(ctx);
			return textResult(JSON.stringify({ state: currentState ?? null }, null, 2), { state: currentState ?? null });
		},
	});

	pi.registerTool({
		name: "set_hitohako_novel_request",
		label: "Set Hitohako Novel Request",
		description: "Record the user's writing request and move the harness to plot drafting.",
		promptGuidelines: ["Call this when the harness is waiting for the user's writing request."],
		parameters: SET_REQUEST_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["awaiting_request"]);
			if (phaseError) return phaseError;
			const userRequest = params.userRequest.trim();
			if (!userRequest) return textResult("userRequest is required.", undefined, true);
			const state = transition(currentState, {
				userRequest,
				phase: "plot_drafting",
			});
			save(state);
			inject(state, true, true);
			return textResult("Recorded writing request and moved to plot drafting.", { state });
		},
	});

	pi.registerTool({
		name: "save_hitohako_plot",
		label: "Save Hitohako Plot",
		description: "Persist the current plot markdown and move the harness to plot review.",
		promptGuidelines: ["Call this after drafting or revising the plot. Do not say the plot is saved before this succeeds."],
		parameters: SAVE_PLOT_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["plot_drafting", "plot_revision"]);
			if (phaseError) return phaseError;
			ensureDirectories();
			const title = params.title.trim() || currentState.title;
			const plotMarkdown = params.plotMarkdown.trim();
			if (!plotMarkdown) return textResult("plotMarkdown is required.", undefined, true);
			writeFileSync(currentState.plotPath, `${plotMarkdown}\n`, "utf8");
			const plannedChapterCount = Math.max(1, Math.floor(params.chapterCount ?? inferChapterCount(plotMarkdown)));
			const state = transition(currentState, { title, plannedChapterCount, phase: "plot_review" });
			save(state);
			return textResult(`Saved plot: ${state.plotPath}`, { state });
		},
	});

	pi.registerTool({
		name: "revise_hitohako_plot",
		label: "Revise Hitohako Plot",
		description: "Record an additional prompt for the plot and request a plot rewrite.",
		promptGuidelines: ["Call this when the user chooses 追加プロンプト for the plot."],
		parameters: REVISE_PLOT_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["plot_review"]);
			if (phaseError) return phaseError;
			const additionalPrompt = params.additionalPrompt.trim();
			if (!additionalPrompt) return textResult("additionalPrompt is required.", undefined, true);
			const state = transition(currentState, {
				phase: "plot_revision",
				revisionPrompts: {
					...currentState.revisionPrompts,
					plot: [...currentState.revisionPrompts.plot, additionalPrompt],
				},
			});
			save(state);
			inject(state, true, false);
			return textResult("Recorded plot revision prompt.", { state });
		},
	});

	pi.registerTool({
		name: "accept_hitohako_plot",
		label: "Accept Hitohako Plot",
		description: "Accept the saved plot and move to chapter drafting.",
		promptGuidelines: ["Call this when the user chooses はい for the plot."],
		parameters: EMPTY_PARAMS,
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["plot_review"]);
			if (phaseError) return phaseError;
			if (!existsSync(currentState.plotPath)) return textResult(`Plot file does not exist: ${currentState.plotPath}`, undefined, true);
			const state = transition(currentState, { phase: "chapter_drafting", currentChapter: 1 });
			save(state);
			inject(state, true, false);
			return textResult("Accepted plot and moved to chapter drafting.", { state });
		},
	});

	pi.registerTool({
		name: "save_hitohako_chapter",
		label: "Save Hitohako Chapter",
		description: "Persist a chapter draft and move the harness to chapter review.",
		promptGuidelines: ["Call this after drafting or revising a chapter. Do not say the chapter is saved before this succeeds."],
		parameters: SAVE_CHAPTER_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["chapter_drafting", "chapter_revision"]);
			if (phaseError) return phaseError;
			ensureDirectories();
			const chapterNumber = Math.max(1, Math.floor(params.chapterNumber));
			const chapterError = requireCurrentChapter(currentState, chapterNumber);
			if (chapterError) return chapterError;
			const chapterMarkdown = params.chapterMarkdown.trim();
			if (!chapterMarkdown) return textResult("chapterMarkdown is required.", undefined, true);
			const path = chapterPath(currentState, chapterNumber);
			writeFileSync(path, `${chapterMarkdown}\n`, "utf8");
			const state = transition(currentState, {
				phase: "chapter_review",
				currentChapter: chapterNumber,
				chapterPaths: { ...currentState.chapterPaths, [String(chapterNumber)]: path },
			});
			save(state);
			return textResult(`Saved chapter ${chapterNumber}: ${path}`, { state });
		},
	});

	pi.registerTool({
		name: "revise_hitohako_chapter",
		label: "Revise Hitohako Chapter",
		description: "Record an additional prompt for the current chapter and request a rewrite.",
		promptGuidelines: ["Call this when the user chooses 追加プロンプト for a chapter."],
		parameters: REVISE_CHAPTER_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["chapter_review"]);
			if (phaseError) return phaseError;
			const chapterNumber = Math.max(1, Math.floor(params.chapterNumber ?? currentState.currentChapter));
			const chapterError = requireCurrentChapter(currentState, chapterNumber);
			if (chapterError) return chapterError;
			const additionalPrompt = params.additionalPrompt.trim();
			if (!additionalPrompt) return textResult("additionalPrompt is required.", undefined, true);
			const key = String(chapterNumber);
			const state = transition(currentState, {
				phase: "chapter_revision",
				currentChapter: chapterNumber,
				revisionPrompts: {
					...currentState.revisionPrompts,
					chapters: {
						...currentState.revisionPrompts.chapters,
						[key]: [...(currentState.revisionPrompts.chapters[key] ?? []), additionalPrompt],
					},
				},
			});
			save(state);
			inject(state, true, false);
			return textResult(`Recorded chapter ${chapterNumber} revision prompt.`, { state });
		},
	});

	pi.registerTool({
		name: "accept_hitohako_chapter",
		label: "Accept Hitohako Chapter",
		description: "Accept the current chapter and move to the next chapter or final review.",
		promptGuidelines: ["Call this when the user chooses はい for a chapter."],
		parameters: ACCEPT_CHAPTER_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["chapter_review"]);
			if (phaseError) return phaseError;
			const chapterNumber = Math.max(1, Math.floor(params.chapterNumber ?? currentState.currentChapter));
			const chapterError = requireCurrentChapter(currentState, chapterNumber);
			if (chapterError) return chapterError;
			const path = currentState.chapterPaths[String(chapterNumber)] ?? chapterPath(currentState, chapterNumber);
			if (!existsSync(path)) return textResult(`Chapter file does not exist: ${path}`, undefined, true);
			const acceptedChapters = Array.from(new Set([...currentState.acceptedChapters, chapterNumber])).sort((a, b) => a - b);
			const plannedChapterCount = currentState.plannedChapterCount ?? chapterNumber;
			const stateWithPlan = transition(currentState, { plannedChapterCount });
			const allAccepted = allPlannedChaptersAccepted(stateWithPlan, acceptedChapters);
			const state = transition(currentState, {
				acceptedChapters,
				plannedChapterCount,
				currentChapter: allAccepted ? chapterNumber : chapterNumber + 1,
				phase: allAccepted ? "final_review" : "chapter_drafting",
			});
			save(state);
			inject(state, true, false);
			return textResult(
				allAccepted ? "Accepted final planned chapter and moved to final review." : `Accepted chapter ${chapterNumber}.`,
				{ state },
			);
		},
	});

	pi.registerTool({
		name: "save_hitohako_final",
		label: "Save Hitohako Final",
		description: "Persist the final novel to the SFW or NSFW output directory.",
		promptGuidelines: ["Call this only after the user selected SFW or NSFW."],
		parameters: SAVE_FINAL_PARAMS,
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			restore(ctx);
			if (!currentState) return textResult("No hitohako novel harness is active.", undefined, true);
			const phaseError = requirePhase(currentState, ["final_review"]);
			if (phaseError) return phaseError;
			ensureDirectories();
			const rating = params.rating;
			const finalPath = finalPathFor(currentState, rating);
			const markdown = normalizeFinalMarkdown(currentState, rating, params.finalMarkdown, finalPath);
			writeFileSync(finalPath, markdown, "utf8");
			const state = transition(currentState, { phase: "final_saved", rating, finalPath });
			save(state);
			return textResult(`Saved final ${rating} novel: ${finalPath}`, { state });
		},
	});
}
