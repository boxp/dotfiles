# xai-web-search

xAI Grok APIを使ってWeb検索を行うOpenClaw Skill

## 説明

このスキルは、xAI GrokのWeb検索機能を使用してインターネット上の情報を検索します。
`grok-4-1-fast-reasoning`モデルと`web_search`ツールを使用して、最新のWeb情報を取得できます。

## 使用例

```bash
# Web上で情報を検索
/xai-web-search "最新のAI技術動向"

# 技術ドキュメントを検索
/xai-web-search "React hooks best practices"

# ニュースや記事を検索
/xai-web-search "量子コンピュータの最新研究"
```

## 環境変数

- `XAI_API_KEY`: xAI APIキー（必須）

## 依存関係

- curl
- jq

## 技術仕様

- エンドポイント: https://api.x.ai/v1/responses
- モデル: grok-4-1-fast-reasoning
- ツール: web_search
- 認証: Bearer token (XAI_API_KEY)
