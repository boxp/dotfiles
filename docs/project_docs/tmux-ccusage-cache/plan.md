# tmux ステータスラインの ccusage 呼び出しをキャッシュ化する

## 背景 — WSL がホストのリソースを食い潰していた

WSL2 上で Claude Code を動かしているだけでホスト側 (Windows) のリソースが枯渇し、
ゲームプロセスが kill される事象が発生していた。調査の結果、原因は Claude Code 本体
ではなく **tmux のステータスライン**だった。

`.tmux.conf` の構成:

- `status-interval 1` — ステータスラインを毎秒再描画
- `status-right` に `#{ccusage_month_cost}` / `#{ccusage_today_cost}` /
  `#{ccusage_today_tokens}` の 3 セグメント + `ai-budget-today.sh`

`yanskun/tmux-ccusage` プラグインは `#{ccusage_*}` を `#(スクリプト)` に置換する実装で、
かつ `scripts/helpers.sh` には**キャッシュが一切ない**。さらに `find_ccusage()` が毎回
`npx ccusage --version` で存在確認してから本番実行するため、1 セグメントにつき Node が
2 回起動する。

### 実測値 (修正前)

| 項目 | 実測 |
| --- | --- |
| ccusage セグメント 1 つの実行時間 | 3.38 秒 (CPU 時間 3.1 秒) |
| ピーク RSS | 195 MB |
| ステータス更新間隔 | 1 秒 |
| 10 秒間に生成された node 系プロセス | 38 個 (秒間約 4) |
| WSL 起動 1 分時点の load average | 15.91 (16 コアが飽和) |

3.4 秒かかる処理を毎秒 4 本起動しているため、常時 3〜4 世代がオーバーラップして積み上がり、
CPU 10 コア相当・メモリ 2 GB 前後を恒常的に占有していた。ccusage は毎回
`~/.claude/projects` (149 MB / 20 jsonl) を全パースするのでディスク I/O も常時発生する。

WSL2 のメモリはピークで確保された分が Windows 側へ返らないため、これがホストの
メモリ枯渇に直結していた。

## 方針

ccusage の実行頻度を「ステータス再描画ごと」から「TTL ごと」へ切り離す。
ステータスラインの読み取り側はキャッシュファイルを `cat` するだけにする。

## 変更内容

### 1. `scripts/ccusage-status.sh` (新規)

全 ccusage セグメントを 1 本のキャッシュ済み文字列に集約する。

- **読み取りモード** (既定): キャッシュが TTL 内なら即座に出力して終了。
  古い / 無い場合はバックグラウンドで更新をキックし、手持ちの値をそのまま返す
  (ノンブロッキング)。多重起動は `flock -n` で防ぐ。
- **`--refresh`**: `ccusage daily` と `ccusage monthly` を 1 回ずつ実行し、
  セグメント文字列を組み立ててキャッシュへアトミックに書き込む (`mv`)。
- ccusage の探索は `command -v` と既知パスのみ。`npx ccusage --version` による
  二重起動は行わない。
- 取得に失敗した場合は既存キャッシュを上書きしない。
- TTL は `TMUX_CCUSAGE_TTL` で上書き可能 (既定 120 秒)。

### 2. `scripts/ai-budget-today.sh` (改修)

`AI_BUDGET_MONTHLY_COST` 環境変数が与えられた場合はそれを当月コストとして使い、
ccusage の再実行を省く。これにより `ccusage-status.sh` の更新 1 回あたりの
ccusage 実行は monthly / daily 各 1 回で済む (budget 用の 3 回目が不要になる)。

値が数値でない場合は従来どおり ccusage へフォールバックする。既存の呼び出し経路と
テストの挙動は変えない。

### 3. `.tmux.conf` (改修)

- `set -g @plugin 'yanskun/tmux-ccusage'` を削除
- `status-interval` を `1` → `5`
- `status-right` の ccusage 系 3 セグメントと `ai-budget-today.sh` 呼び出しを
  `#(...\/scripts\/ccusage-status.sh)` 1 本に置き換え

### 4. `scripts/test-ccusage-status.sh` (新規)

既存の `test-ai-budget-today.sh` と同じスタイルで、モック `ccusage` を使って検証する。

- キャッシュが新しい場合に ccusage を起動しないこと
- `--refresh` がセグメント文字列を正しく組み立てること
- ccusage 失敗時に既存キャッシュを破壊しないこと
- コスト / トークンの整形 (`$X.XX`, `K` / `M` サフィックス) が従来表示と一致すること

## 期待効果

ccusage の起動回数は毎秒 4 回 → 120 秒に 2 回となり、約 240 分の 1 になる。
ステータス再描画のコストはキャッシュファイル 1 回の読み取りのみ。

## 検証

1. `scripts/test-ai-budget-today.sh` と `scripts/test-ccusage-status.sh` が通ること
2. `tmux source-file ~/.tmux.conf` 後、ステータスラインの表示が従来と同一であること
3. 修正前後で `10 秒間に生成された node 系プロセス数` と load average を比較すること
