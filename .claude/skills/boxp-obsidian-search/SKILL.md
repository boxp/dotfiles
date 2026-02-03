---
name: boxp-obsidian-search
description: BOXP・lolice k8s cluster・ひとはこ・ひとはこさんに関するナレッジをObsidian Vaultから検索・参照。「BOXPについて調べて」「lolice clusterの構成を確認」「ひとはこの設定を見て」時に使用
argument-hint: <検索キーワード>
allowed-tools: Read, Grep, Glob, Bash
---

# BOXP Obsidian Vault 検索

BOXP個人のObsidian Vaultからナレッジを検索・参照します。
MCPサーバーは不要で、Claude Codeの標準ツールのみで動作します。

## 対象トピック
このskillは以下のトピックに関する情報を検索する場合にのみ使用:
- **BOXP** - 個人プロジェクト・設定・メモ全般
- **lolice k8s cluster** - Kubernetesクラスター構成・運用
- **ひとはこ / ひとはこさん** - 関連プロジェクト・設定

## Vaultパス
環境変数 `$OBSIDIAN_ROOT` で定義（`~/.pri_zshrc` でexport済み）。
まずBashで `echo $OBSIDIAN_ROOT` を実行してパスを取得すること。

## 手順

1. Vaultパスを取得:
   ```bash
   echo $OBSIDIAN_ROOT
   ```

2. Vault構造を確認（必要な場合）:
   - Glob で `$OBSIDIAN_ROOT/**/*.md` を検索してファイル一覧を取得
   - または Bash で `find "$OBSIDIAN_ROOT" -name "*.md" -not -path "*/.obsidian/*" -not -path "*/attachments/*"` を実行

3. キーワードでファイルを検索:
   - Grep で `$ARGUMENTS` をパス `$OBSIDIAN_ROOT` 配下から検索
   - Bash で `grep -rl "$ARGUMENTS" "$OBSIDIAN_ROOT" --include="*.md"` も併用可

4. ファイル内容を読み取り:
   - Read で該当ファイルの内容を取得

5. 検索結果を要約してユーザーに日本語で提示

## 注意事項
- `attachments/` や `.obsidian/` は検索対象から除外すること
