# BOXP-30 Hitohako Novel Harness

## Goal

Move the Pi Agent hitohako novel writing workflow from a manual skill-only procedure into an extension harness so low-cost local LLMs cannot skip phase state updates or file saves.

## Plan

1. Add `.pi/agent/extensions/hitohako-novel-harness.ts`.
2. Register `hitohako-novel-harness.ts` in `setup.sh` so it symlinks into `~/.pi/agent/extensions/`.
3. Keep `hitohako-novel-writer` as a thin Pi Agent skill that tells the model to start `/hitohako-novel`.
4. Implement harness commands:
   - `/hitohako-novel start [request]`
   - `/hitohako-novel resume`
   - `/hitohako-novel status`
   - `/hitohako-novel cancel`
5. Implement harness tools for request capture, plot save/revise/accept, chapter save/revise/accept, final save, and state inspection.
6. Collect hitohako-san universe markdown notes at workflow start and inject them as hidden context.
7. Use `はい` / `追加プロンプト` as the plot and chapter review flow.
8. Handle plot/chapter review replies in the extension `input` hook so the model cannot skip approval transition tools.

## Verification

- `sh -n setup.sh`
- TypeScript syntax/type sanity check for the new extension
- `git diff --check`
- Confirm the new extension is listed in `ENABLED_PI_AGENT_EXTENSIONS`
- Confirm the extension loads through `pi -e`
