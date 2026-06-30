---
name: hitohako-novel-writer
description: Pi Agent-only workflow for writing novels based on the Obsidian hitohako-san universe. Use when the user wants to draft, revise, or save a novel using notes under the hitohako-san universe vault, with plot approval, chapter-by-chapter approval, and SFW/NSFW output routing.
---

# Hitohako Novel Writer

Use this skill only in Pi Agent. Write Japanese prose unless the user explicitly requests another language.

## Source Material

Use the Obsidian vault as the source of truth:

- Universe root: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース`
- Character notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/キャラ設定`
- World notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/世界観設定`
- Item notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/アイテム設定`
- SFW output: `/home/boxp/Documents/obsidian-headless/BOXP/小説草案/AI執筆`
- NSFW output: `/home/boxp/Documents/obsidian-headless/BOXP/NSFW/小説/AI執筆`

Before creating a plot, inspect the relevant notes with targeted searches and reads. Do not invent setting details that contradict the notes. If the requested subject is broad, read at least:

- `キャラ設定/ひとはこ.md`
- `世界観設定/README.md` if present
- any character, organization, creature, or item notes named or clearly implied by the user

## Draft Files

Persist intermediate work so the session can be resumed:

```text
/home/boxp/Documents/obsidian-headless/BOXP/draft/plot-{slug}.md
/home/boxp/Documents/obsidian-headless/BOXP/draft/paragraph/{slug}-{chapter-number}.md
```

Use a slug based on `YYYY-MM-DD-HH-MM_title`. Create directories when needed. Keep the plot file and chapter files updated after every accepted or rewritten draft.

## Interactive Workflow

If Pi Agent has a choice-selection UI, use it for yes/no and SFW/NSFW prompts. Otherwise ask plainly in chat and wait for the user.

1. Ask the user: `プロットを作成するので書きたい内容を入力してください。`
2. After receiving the request, inspect relevant Obsidian notes and create a plot.
3. Save the plot to `draft/plot-{slug}.md`.
4. Ask: `このプロットで問題ありませんか？` with choices `はい` and `いいえ`.
5. If `いいえ`, ask for追加指示, revise the plot, save it again, and return to step 4.
6. If `はい`, write the lowest-numbered chapter that has not been accepted yet.
7. Save the chapter draft to `draft/paragraph/{slug}-{n}.md`.
8. Ask: `この内容でいいですか？` with choices `はい` and `いいえ`.
9. If `いいえ`, ask for追加指示, rewrite the same chapter, save it again, and return to step 8.
10. If `はい`, mark that chapter accepted and repeat from step 6 until the final chapter is accepted.
11. After the final chapter is accepted, output the full novel body in chat.
12. Ask the user to choose `SFW` or `NSFW`.
13. Save the full novel:
    - `SFW`: `/home/boxp/Documents/obsidian-headless/BOXP/小説草案/AI執筆/{slug}.md`
    - `NSFW`: `/home/boxp/Documents/obsidian-headless/BOXP/NSFW/小説/AI執筆/{slug}.md`

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
- Do not silently skip the approval prompts. The user must approve the plot and each chapter.
- If the user requests sexual content, first ensure the content can be written safely and legally; if it cannot, refuse that part and offer a safe alternative.
