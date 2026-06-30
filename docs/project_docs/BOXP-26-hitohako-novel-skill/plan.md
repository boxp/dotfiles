# BOXP-26 Hitohako Novel Writer Skill

## Goal

Create a Pi Agent-only skill for writing novels based on the Obsidian hitohako-san universe notes.

## Plan

1. Add `.pi/agent/skills/hitohako-novel-writer/SKILL.md`.
2. Define the workflow requested in BOXP-26:
   - ask for the story request
   - draft and persist a plot
   - ask for plot approval with yes/no choices
   - revise until approved
   - draft chapters one by one
   - ask for chapter approval with yes/no choices
   - revise each chapter until approved
   - output the complete novel
   - ask for SFW/NSFW and save to the appropriate Obsidian folder
3. Point the skill at the existing Obsidian source notes and output folders.
4. Add `agents/openai.yaml` metadata matching the existing Pi Agent skill layout.
5. Validate frontmatter, file paths, and git diff.
