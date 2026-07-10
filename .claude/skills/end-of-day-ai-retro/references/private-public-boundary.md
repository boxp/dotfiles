# プライベート情報と公開dotfiles の分離規則

## 公開してよいもの（boxp/dotfiles）

- 汎用スクリプト（secret値を含まない）
- セッションファイルのパスパターン（`~/.codex/sessions/`, `~/.claude/projects/` など）
- fixtureテスト用サンプルJSONL（実セッションの生内容を含まない）
- 改善提案のテンプレート
- チェックリスト

## 公開してはいけないもの

- 実セッションの生プロンプト・応答内容
- APIキー・認証トークン・secret
- クラスタ固有のIPアドレス・ホスト名
- 個人情報（メールアドレス等）
- lolice固有の運用設定・スケジュール
- 改善提案の根拠となるraw session内容

## 判定フロー

1. 設定変更の提案か、raw session内容か？
   - raw session内容 → private vault のみ
   - 設定変更の提案 → 手順2へ
2. secretや個人情報を含むか？
   - 含む → private vault のみ
   - 含まない → dotfiles可
3. lolice/クラスタ固有の値か？
   - 固有値あり → lolice repo か private vault
   - 汎用 → dotfiles可

## 根拠の書き方

改善提案に根拠を記録する際は、raw sessionの内容ではなく識別子と秘匿済み要約を使う:

```
観察根拠: session ~/.claude/projects/.../abc123.jsonl (2026-07-10 14:30)
観察内容: codex-execへの委譲で同じパラメータを3回繰り返し指定した（内容は非公開）
```
