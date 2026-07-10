# BOXP-87: 日次AI振り返り自動化 設計計画

## 参照資料と調査日

- Claude Code Hooks: https://code.claude.com/docs/en/hooks （参照: 2026-07-10）
- Codex Automations: https://developers.openai.com/codex/app/automations （参照: 2026-07-10）
- Codex Skills: https://developers.openai.com/codex/concepts/customization#skills （参照: 2026-07-10）
- Hermes Agent Skills: https://hermes-agent.nousresearch.com/docs/user-guide/features/skills/ （参照: 2026-07-10）
- OpenClaw Memory: https://docs.openclaw.ai/concepts/memory （参照: 2026-07-10）
- OpenClaw Skills: https://docs.openclaw.ai/skills （参照: 2026-07-10）

## ツール比較表

| 軸 | Claude Code | Codex | Hermes Agent | OpenClaw |
|---|---|---|---|---|
| **Trigger** | slash command, hook (PreToolUse/PostToolUse/Stop/Notification) | skill, automation, cron | skill, natural language | skill, scheduled task |
| **入力** | ローカルセッションJSONL, hook stdin, ファイル | ローカルセッションJSONL, skills, tool calls | session context, memory | markdown memory, session |
| **Memory/Skill** | CLAUDE.md, skills/, rules/, hooks (設定ファイル) | config.toml, rules/*.rules, skills/ (設定ファイル) | memory system (JSON/vector), skill cards | markdown memory files, skill定義 |
| **提案生成** | 手動 (skill実行時) | 手動 (skill実行時) | 自動 (memory更新) | 自動 (memory更新) |
| **承認フロー** | 人間が手動でPR/チケット化 | 人間が手動でPR/チケット化 | エージェント自己更新 (承認不要) | エージェント自己更新 (要設定) |
| **検証/Rollback** | git diff, PR review | git diff, PR review | バージョン管理なし | バージョン管理なし |
| **Security** | sandbox, permissionシステム | sandbox, approval | 不明確 | 不明確 |
| **Observability** | JSONL session, hook log | JSONL session, runs/ | memory log | run artifact |

## 採用・不採用理由

### 採用: Claude Code + Codex の既存設定ファイルアプローチ

- **理由**: git管理下の設定ファイルに変更が残り、レビュー・ロールバックが容易
- **根拠**: CLAUDE.md/rules/*.rules/skills/ はすべてバージョン管理対象
- **適用**: 改善提案は設定ファイルのdiffとしてPR化し、人間がレビューしてmerge

### 不採用: Hermes Agent の自己更新メモリ

- **理由**: エージェントが無承認でmemoryを更新する仕組みは、公開dotfilesへの誤記録リスクが高い
- **根拠**: Hermes AgentはNousResearch独自のmemory API経由で自律更新する。ロールバック手段が不明確
- **MVP方針**: MVPではエージェントがリポジトリ/設定/skillを無審査で自己書換えしない

### 不採用: OpenClaw の定期memory更新

- **理由**: OpenClawのmarkdown memoryは単一ファイルへの自動書き込みを前提にしており、lolice固有情報をdotfilesに混在させるリスクがある
- **根拠**: OpenClaw公式ドキュメントではprivate vault連携の境界設計が曖昧
- **MVP方針**: レポートはprivate Obsidian vaultに保存し、dotfilesに生セッション・secretを含むものは書かない

### 採用: codex-cron-scheduler の既存スケジューラ活用

- **理由**: loliceクラスタにresident schedulerがすでに存在し、新しい並行インフラが不要
- **根拠**: `boxp/lolice/argoproj/codex-workspace/cron.md` に設計と運用手順が記録されている
- **適用**: `jobs.edn` に `end-of-day-retro` ジョブを追加する（private vaultのみ変更、dotfilesは変更なし）

## MVPの安全境界

1. **自動変更禁止**: 日次実行はレポートと提案の生成・保存のみ。リポジトリ、~/.claude、~/.codex、クラスタを自動変更しない
2. **承認フロー**: 採用する変更は人間の承認後にTask Boardチケット → worktree → PR → mergeフローを通す
3. **Private情報の境界**:
   - `boxp/dotfiles`: 汎用skill、チェックリスト、secretを含まない補助処理
   - `boxp/lolice` / private vault: スケジュール、保存先、権限、運用設定、raw session参照

## 公開/非公開の配置方針

| 種別 | 配置先 | 理由 |
|---|---|---|
| 汎用振り返りskill | boxp/dotfiles | 複数環境で再利用可能 |
| セッションフィルタスクリプト | boxp/dotfiles | secretを含まない |
| 秘匿チェックスクリプト | boxp/dotfiles | パターンマッチのみ、secret値なし |
| Fixtureテスト | boxp/dotfiles | サンプルデータのみ |
| Cron jobスケジュール | private vault | lolice固有設定 |
| 日次レポート | private vault | 生セッション参照を含む可能性 |
| Run artifact | private vault | 実行ログ、欠損理由を含む |
| クラスタ固有設定 | boxp/lolice | インフラ設定 |
