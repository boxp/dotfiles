# T-20260301-011: xai-x-search skill 不調の原因切り分けと修正

## Root Cause Analysis

### 問題1: ハードコードされたホームディレクトリパス
- **場所**: `xai-x-search/SKILL.md` line 19, `xai-web-search/SKILL.md` line 19
- **原因**: パスが `/home/boxp/.claude/skills/...` とハードコードされていた
- **影響**: OpenClaw環境（`/home/node`）では該当パスが存在せず、スクリプトが見つからない
- **修正**: `$HOME/.claude/skills/...` に変更し、実行環境のHOMEに依存するように修正

### 問題2: 存在しないsubagent_type
- **場所**: 両SKILL.mdの実行方法セクション
- **原因**: `subagent_type: Bash` が指定されていたが、Task toolに `Bash` タイプは存在しない
- **有効なsubagent_type**: `general-purpose`, `Explore`, `Plan`, `statusline-setup`
- **修正**: `subagent_type: general-purpose` に変更

### 問題3: XAI_API_KEY の伝播
- **状況**: 環境変数自体はPodに定義されている
- **影響**: 上記2つの問題が解決されれば、環境変数は正しくTask subagentに伝播される

## 修正内容

### 変更ファイル
1. `.claude/skills/xai-x-search/SKILL.md`
2. `.claude/skills/xai-web-search/SKILL.md`

### 変更点（両ファイル共通）
1. `subagent_type: Bash` → `subagent_type: general-purpose`
2. `/home/boxp/` → `$HOME/`
3. 「結果をそのまま返してください。」を追加（subagentが結果を正しく返すための指示）
4. 環境変数の説明を明確化

## 検証方法
1. 修正後のSKILL.mdが正しい形式であることを確認
2. `$HOME/.claude/skills/xai-x-search/scripts/search.sh` が実行可能であることを確認
3. 実際にX検索を実行して成功することを確認

## 運用メモ
- `XAI_API_KEY` はPodの環境変数として設定されている必要がある
- `$HOME` は実行ユーザーのホームディレクトリに自動解決される
- skillファイルは `dotfiles` リポジトリで管理され、symlinkで `~/.claude/skills/` に配置される
