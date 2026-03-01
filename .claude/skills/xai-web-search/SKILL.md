---
name: xai-web-search
description: xAI Grok APIでWeb検索。「Grokで検索」「Grokで調べて」「xAIで検索」「Grok web search」時に使用
argument-hint: <検索クエリ>
---

# Web検索スキル（xAI Grok）

xAI GrokのWeb検索機能を使用してインターネット上の情報を検索します。

## 実行方法

**このスキルはメインコンテキストを消費しないよう、必ずTaskツール（subagent_type=general-purpose）で実行すること。**

```
Task tool:
  subagent_type: general-purpose
  prompt: |
    bash $HOME/.claude/skills/xai-web-search/scripts/search.sh $ARGUMENTS
    結果をそのまま返してください。
```

Taskの結果を受け取ったら、内容を日本語で要約してユーザーに提示する。

## 環境変数

- `XAI_API_KEY`: xAI APIキー（必須、実行環境で事前にexportされていること）
