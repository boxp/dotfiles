# BOXP-50 Remove Hitohako Novel Harness

## Goal

Remove the BOXP-30 `hitohako-novel-harness` Pi Agent extension and keep only a small Pi Agent skill for searching and reading hitohako-san universe setting notes.

## Plan

1. Inspect `setup.sh`, `.pi/agent/extensions/`, and `.pi/agent/skills/hitohako-novel-writer/` for harness registration and usage.
2. Delete `.pi/agent/extensions/hitohako-novel-harness.ts`.
3. Remove `hitohako-novel-harness.ts` from `ENABLED_PI_AGENT_EXTENSIONS` so `setup.sh` will not symlink it into `~/.pi/agent/extensions/`.
4. Shrink `.pi/agent/skills/hitohako-novel-writer/SKILL.md` to a reference-only skill that points at:
   - `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/キャラ設定`
   - `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/世界観設定`
   - `/home/boxp/Documents/obsidian-headless/BOXP/ひとはこさんバース/アイテム設定`
5. Remove harness-dependent instructions from the skill, including plot approval loops, chapter saving, SFW/NSFW output routing, and extension tool assumptions.
6. Validate with `sh -n setup.sh`, `git diff --check`, and a setup dry run or direct symlink cleanup check where possible.
