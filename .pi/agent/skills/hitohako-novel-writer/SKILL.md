---
name: hitohako-novel-writer
description: Pi Agent-only helper for finding and reading hitohako-san universe setting notes in the Obsidian vault. Use when the user needs character, world, or item canon from the hitohako-san universe before writing or revising prose.
---

# Hitohako Novel Reference

Use this skill only in Pi Agent. This skill is a lightweight entry point for locating and reading hitohako-san universe setting notes. It does not manage writing workflow state, review cycles, saves, output routing, or tool calls.

Treat the existing setting notes as the source of truth. When a user asks to write, revise, brainstorm, or check continuity for hitohako-san universe material, first search and read the relevant notes, then base the answer on those notes. If the notes are missing, ambiguous, or contradictory, say so instead of inventing canon.

## Source Material

The source notes are under the Obsidian vault:

- Universe root: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース`
- Character notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/キャラ設定`
- World notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/世界観設定`
- Item notes: `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/アイテム設定`

## How To Use

1. Identify likely keywords from the user's request, including character names, places, organizations, objects, and relationship terms.
2. Search the three setting directories with `rg` or the available file search tool.
3. Read the matching notes before answering. Prefer narrow reads of directly relevant files over loading the whole vault.
4. When writing or revising prose, preserve characterization, setting logic, terminology, and constraints from the notes.
5. Cite or summarize which notes informed the answer when it helps the user inspect the basis for a continuity decision.

## Boundaries

- Do not call or assume custom commands or extension tools.
- Do not run review loops or automatic save/routing flows.
- Do not claim that files were saved unless the user explicitly asks you to save a file through normal agent work.
- Do not treat generated text, drafts, or memory as canon when it conflicts with the existing setting notes.
