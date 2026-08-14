---
name: xai-x-search
description: xAI Grok APIでX（旧Twitter）を検索。「Xで検索」「Xで調べて」「ツイートを検索」「X上の投稿を探して」「Twitterで検索」時に使用
argument-hint: <検索クエリ>
---

# X（旧Twitter）検索スキル

xAI GrokのX検索機能を使用してX上の投稿を検索します。

## 実行方法

**このスキルはメインコンテキストを消費しないよう、必ずTaskツール（subagent_type=general-purpose）で実行すること。**

```
Task tool:
  subagent_type: general-purpose
  prompt: |
    bash $HOME/.claude/skills/xai-x-search/scripts/search.sh $ARGUMENTS
    結果をそのまま返してください。
```

Taskの結果を受け取ったら、内容を日本語で要約してユーザーに提示する。

## 環境変数

- `XAI_API_KEY`: xAI APIキー（必須、実行環境で事前にexportされていること）
