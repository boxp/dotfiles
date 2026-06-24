# Langfuse trace を使った振り返り

Langfuse は「今日はなんとなく遅かった」を、trace 単位の観察に落とせる。終業時の振り返りでは、感想ではなく trace を根拠に改善案を作る。

## 何を見るか

- `input`: 何をやらせようとしたか
- `output`: どこまで返ってきたか、どこで止まったか
- 長い latency を持つ trace
- token 使用量が大きい trace
- 同じ name / sessionId / tag で繰り返す失敗
- observation 数が多すぎる trace
- error / warning を含む trace

## おすすめの進め方

1. `retro --limit 20 --top 3` で今日の一覧と上位 3 件を取る
2. 上位 3 件は `input` / `output` を先に確認し、そのあと `get <trace-id>` で詳細を確認する
3. 名前・時刻・sessionId・tags から、どの作業文脈だったかを結びつける
4. 本当に重かった理由を 1 行で言う
5. 改善案を「どこに恒久化するか」まで落とす

## list 出力の見方

- `timestamp`: いつ起きたか
- `name`: どの処理か
- `userId`: 誰の trace か
- `sessionId`: 会話や一連の操作単位
- `latency(s)`: 重さの目安
- `totalTokens`: token 使用量
- `cost(USD)`: コストの目安
- `observations`: trace 内の処理数
- `tags`: 分類ラベル

## retro に変換する問い

- `input` が広すぎて、探索が暴走していないか
- `output` が曖昧で、次の手を決めにくくなっていないか
- `output` が長すぎて、同じ説明や再探索を誘発していないか
- latency が長いのは、プロンプト、ツール選択、外部 API、再試行のどれか
- token が多いのは、文脈の渡しすぎ、要約不足、同じ説明の繰り返しか
- 同じ name の trace が何度も失敗するなら、手順化や rules 化の候補か
- 特定 sessionId だけ悪いなら、一時要因か恒久要因か

## 改善案の例

- token が毎回大きい:
  - 長い前提説明を skill / rule に昇格する
- retry が多い:
  - 外部依存の事前確認コマンドを skill に追加する
- latency が特定 workflow に偏る:
  - worktree / tmux / delegate の手順を定型化する
- error trace が同じ操作で繰り返す:
  - AGENTS.md や skill 本文に事前条件を明記する

## 注意

- trace 1 件だけで結論を出さない
- 日次振り返りでは「再発しそうか」を重視する
- 入出力本文が不要なら `io` field は取得しない
