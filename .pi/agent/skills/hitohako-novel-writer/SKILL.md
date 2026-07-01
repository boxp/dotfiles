---
name: hitohako-novel-writer
description: Pi Agent-only workflow for writing novels based on the Obsidian hitohako-san universe. Use when the user wants to draft, revise, or save a novel using notes under the hitohako-san universe vault, with plot approval, chapter-by-chapter approval, and SFW/NSFW output routing.
---

# Hitohako Novel Writer

Use this skill only in Pi Agent. This workflow is backed by the `hitohako-novel-harness.ts` Pi Agent extension.

Start with:

```text
/hitohako-novel start
```

If the user already gave the writing request, pass it directly:

```text
/hitohako-novel start {writing request}
```

Do not run the old manual save flow. The extension owns session state, file paths, plot/chapter/final saving, approval transitions, and SFW/NSFW output routing. The model's job is to write or revise the plot and prose, then call the harness tools.

When the harness is waiting for plot or chapter review, user replies are handled by the extension input hook:

- `はい` advances the harness to the next phase.
- Any other non-empty review reply is treated as an additional prompt for revising the current plot or chapter.

Do not start the next chapter from a review response unless the harness state has advanced to `chapter_drafting`.

## Source Material

The extension collects the hitohako-san universe notes from the Obsidian vault and injects them into the agent context at the start of the workflow:

- Universe root: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース`
- Character notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/キャラ設定`
- World notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/世界観設定`
- Item notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/アイテム設定`
- SFW output: `/home/boxp/Documents/obsidian-headless/BOXP/小説草案/AI執筆`
- NSFW output: `/home/boxp/Documents/obsidian-headless/BOXP/NSFW/小説/AI執筆`

## Harness Commands

```text
/hitohako-novel start [request]
/hitohako-novel resume
/hitohako-novel status
/hitohako-novel cancel
```

## Harness Tools

- `get_hitohako_novel_state`: inspect current phase, slug, paths, and chapter state.
- `set_hitohako_novel_request`: record the user's writing request and move to plot drafting.
- `save_hitohako_plot`: save the current plot and move to plot review.
- `revise_hitohako_plot`: record the user's additional prompt and request a plot rewrite.
- `accept_hitohako_plot`: accept the saved plot and move to chapter drafting.
- `save_hitohako_chapter`: save a chapter draft and move to chapter review.
- `revise_hitohako_chapter`: record the user's additional prompt and request a same-chapter rewrite.
- `accept_hitohako_chapter`: accept the current chapter and move to the next chapter or final review.
- `save_hitohako_final`: save the final novel to the SFW or NSFW output directory.

## Interactive Flow

1. Ask the user: `プロットを作成するので書きたい内容を入力してください。`
2. If the workflow was started without an inline request, call `set_hitohako_novel_request` after the user answers.
3. Draft a plot from the injected universe context and user request.
4. Call `save_hitohako_plot`.
5. Ask the user to choose `はい` or enter `追加プロンプト`.
6. Wait for the extension to process the user's review response and inject the next harness state.
7. If the harness returns to `plot_revision`, rewrite the plot, call `save_hitohako_plot`, and ask again.
8. Draft the current chapter requested by harness state.
9. Call `save_hitohako_chapter`.
10. Ask the user to choose `はい` or enter `追加プロンプト`.
11. Wait for the extension to process the user's review response and inject the next harness state.
12. If the harness returns to `chapter_revision`, rewrite the same chapter, call `save_hitohako_chapter`, and ask again.
13. Repeat chapter drafting until the harness moves to final review.
14. Output the complete novel body in chat.
15. Ask the user to choose `SFW` or `NSFW`.
16. Call `save_hitohako_final`.

## Plot Format

Keep the plot concise but operational:

```markdown
# {title}

## User Request

{original request}

## Reference Notes

- {path}: {why it matters}

## Tone and Rating Target

{tone, intensity, SFW/NSFW uncertainty if not yet chosen}

## Chapter Plan

1. {chapter title}: {scene goal, conflict, ending beat}
2. ...

## Continuity Notes

- {important constraints from the vault}
```

## Chapter Format

Each chapter draft should contain only that chapter's title and prose, not process notes:

```markdown
## 第{n}章 {chapter title}

{prose}
```

When the user asks for a short piece, use one chapter. For multi-part requests, choose a chapter count that fits the requested scope and make each chapter complete enough to review independently.

## Final File Format

Use this structure for the saved full novel:

```markdown
---
created: {YYYY-MM-DD}
source: pi-agent
skill: hitohako-novel-writer
rating: SFW|NSFW
draft_plot: ../../draft/plot-{slug}.md
---

# {title}

{full novel body}
```

Adjust the `draft_plot` relative path if the output directory depth requires it.

## Writing Rules

- Preserve characterization, setting logic, terminology, and constraints from the vault.
- Prefer specific sensory and emotional detail over summary, but keep each review unit manageable.
- Keep continuity notes out of the prose unless they naturally belong in the scene.
- Do not silently skip the review prompts. The user must choose `はい` for the plot and each chapter, or provide `追加プロンプト`.
- Do not say files were saved unless the corresponding harness tool succeeded.
- If the user requests sexual content, first ensure the content can be written safely and legally; if it cannot, refuse that part and offer a safe alternative.
