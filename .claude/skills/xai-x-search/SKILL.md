# xai-x-search

xAI Grok APIを使ってX（旧Twitter）を検索するOpenClaw Skill

## 説明

このスキルは、xAI GrokのX検索機能を使用してX（旧Twitter）上の投稿を検索します。
`grok-4-1-fast-reasoning`モデルと`x_search`ツールを使用して、リアルタイムなX上の情報を取得できます。

## 使用例

```bash
# X上でトレンドを検索
/xai-x-search "AI技術のトレンド"

# 特定のトピックに関する投稿を検索
/xai-x-search "Claude Code 使い方"

# 最新ニュースを検索
/xai-x-search "日本のテクノロジーニュース"
```

## 環境変数

- `XAI_API_KEY`: xAI APIキー（必須）

## 依存関係

- curl
- jq

## 技術仕様

- エンドポイント: https://api.x.ai/v1/responses
- モデル: grok-4-1-fast-reasoning
- ツール: x_search
- 認証: Bearer token (XAI_API_KEY)
