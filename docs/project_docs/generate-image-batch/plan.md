# generate-image バッチ生成対応計画

## 目的
- `generate-image` スキルをバッチ生成に対応させる
- `generate-pixelart` のコスト削減を実現（50%削減目標）
- バッチ生成による生成時間への影響を測定

## ユースケース
- **複数画像の同時生成**: 複数のピクセルアートを一度にまとめて生成
- **単一生成のコスト削減**: 1枚ずつでも非同期Batch APIでコストを下げる
- **許容待ち時間**: 数分〜数十分程度（ポーリングで完了待機）

## 現状分析

### generate-image.bb
- **ファイル**: `.claude/skills/generate-image/generate-image.bb`
- **実装**: Babashka (Clojure)
- **API**: `generativelanguage.googleapis.com` の `generateContent` エンドポイント
- **認証**: `GEMINI_API_KEY` 環境変数
- **処理方式**: 単一リクエスト（同期）

### generate-pixelart
- **処理フロー**: Step1 (イラスト生成) → Step2 (ドット絵変換) → Step2.5 (ImageMagick) → Step3 (ppa)
- **API呼び出し**: 2回（Step1, Step2）
- **依存関係**: Step2はStep1の出力を参照画像として使用
- **必須モデル**: `gemini-3-pro-image-preview` (Nano Banana Pro)

## バッチAPI選択

**採用**: Google AI Studio Batch API

| 観点 | 内容 |
|------|------|
| コスト削減率 | 50% |
| 実装複雑度 | 低（REST API直接） |
| 認証 | 既存の GEMINI_API_KEY を流用 |
| レイテンシ | 通常数分〜数十分（最大24h） |

## 実装方針

### 新規ファイル作成
```
.claude/skills/generate-image/
├── generate-image.bb           # 既存（変更なし）
├── generate-image-batch.bb     # 新規：バッチ処理
└── benchmark-batch.bb          # 新規：ベンチマーク
```

### generate-image-batch.bb の設計

**CLIオプション**:
```
-i, --input FILE      入力JSONファイル（リクエスト定義）
-o, --output DIR      出力ディレクトリ
-m, --model MODEL     モデル名（default: gemini-2.5-flash-image）
-p, --poll-interval   ポーリング間隔秒（default: 30）
-t, --timeout         タイムアウト秒（default: 3600）
--status ID           既存バッチジョブのステータス確認
```

**入力JSONフォーマット**:
```json
{
  "requests": [
    {
      "key": "pixelart-1-step1",
      "prompt": "高品質イラスト...",
      "aspect_ratio": "3:2",
      "images": []
    }
  ]
}
```

**処理フロー**:
1. 入力JSON読み込み
2. BatchGenerateContent APIリクエスト構築
3. バッチジョブ送信
4. ポーリングループ（ステータス確認、30秒間隔）
5. 完了時：結果取得・画像デコード・保存
6. 出力ファイルパス一覧をJSONで出力

### generate-pixelartへの適用

**単一ピクセルアート（バッチモード）**:
- Step1をバッチ送信 → 完了待ち → Step2をバッチ送信 → 完了待ち → Step2.5/3実行
- 各Stepの待ち時間は発生するが、コストは50%削減

**複数ピクセルアート同時生成**:
```
Phase 1 Batch: 全ピクセルアートのStep1を一括実行
Phase 2 Batch: Phase 1完了後、全ピクセルアートのStep2を一括実行
Sequential: Step2.5/3は各出力に対して順次実行（CPU処理）
```

## ベンチマーク計画

### テストケース
| # | ケース | 測定対象 |
|---|--------|----------|
| 1 | 単一画像生成（現行・同期） | ベースライン時間 |
| 2 | 単一画像生成（バッチ） | バッチ待ち時間 |
| 3 | 3画像逐次生成（現行×3） | 比較用累積時間 |
| 4 | 3画像バッチ生成 | バッチ処理時間 |
| 5 | 10画像バッチ生成 | スケール性能 |

### 測定項目
- 総処理時間（ジョブ投入〜全結果取得）
- キュー待ち時間（ジョブ投入〜処理開始）
- 実処理時間（処理開始〜完了）

## 実装フェーズ

### Phase 1: Batch API検証
- `batchGenerateContent` APIが画像生成モデルで利用可能か確認
- APIリクエスト/レスポンス形式の確認

### Phase 2: generate-image-batch.bb 基本実装
- バッチジョブ作成・送信
- ポーリング・ステータス確認
- 結果取得・画像保存

### Phase 3: エラーハンドリング
- リトライ機構（exponential backoff）
- タイムアウト処理
- 個別リクエスト失敗時の部分成功対応

### Phase 4: ベンチマーク
- benchmark-batch.bb 作成
- テストケース実行・結果CSV出力

### Phase 5: ドキュメント更新
- SKILL.md にバッチ使用方法追記

## 修正対象ファイル

| ファイル | 変更内容 |
|----------|----------|
| `.claude/skills/generate-image/generate-image-batch.bb` | 新規作成 |
| `.claude/skills/generate-image/benchmark-batch.bb` | 新規作成 |
| `.claude/skills/generate-image/SKILL.md` | バッチ使用方法追記 |

## 検証方法

1. Batch APIが画像生成モデルで動作することを確認（Phase 1）
2. `generate-image-batch.bb` で3画像のバッチ生成が成功することを確認
3. ベンチマークスクリプトで単一生成 vs バッチ生成の時間を比較
4. 生成された画像の品質が単一生成と同等であることを目視確認

## リスク・要確認事項

- **API対応状況**: Google AI Studio の `batchGenerateContent` APIが画像生成モデル（Nano Banana/Nano Banana Pro）で利用可能かは実際に試す必要あり
- **最大リクエスト数**: バッチ処理の最大リクエスト数制限の確認
- **Fallback**: Batch APIが画像生成非対応の場合、Vertex AI経由を検討
