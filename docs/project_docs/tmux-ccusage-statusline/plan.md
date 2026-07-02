# tmux statusline で ccusage と他の表示を共存させる修正計画

## 背景

tmux の statusline で `tmux-ccusage` を表示したいが、実際には何も出ていない。また、既存の battery 表示や tmux-continuum による `status-right` フックと `status-right` の定義が競合しており、後勝ちで上書きされる状態になっている。

## 原因

1. `.tmux.conf` で `status-right` を 2 回 `set -g` しており、後半の ccusage 用設定が battery 表示を上書きしている
2. `run '~/.tmux/plugins/tpm/tpm'` が `status-right` 設定より前にあり、TPM 配下の `tmux-battery` / `tmux-ccusage` / `tmux-continuum` が補間対象の最終値を見られていない
3. その結果、`#{ccusage_today_cost}` などのプレースホルダがプラグインの `#(...)` 実行へ変換されず、tmux 上では空文字になる
4. battery 側の色用変数は `#{battery_status_bg}` ではなく `#{battery_color_status_bg}` 系であり、既存指定では正しく展開されない

## 修正方針

1. `status-right` を 1 箇所に統合し、battery・ccusage・日時を同時表示する
2. ccusage は当日分に加えて当月累計 (`#{ccusage_month_cost}`) も表示する
3. TPM 初期化行を `.tmux.conf` の最下部へ移し、各プラグインが最終的な `status-right` に対して補間できるようにする
4. battery の色変数を実装に合わせて修正し、表示長も増やして切れにくくする
5. `tmux source-file ~/.tmux.conf` 後の `status-right` を確認し、`#(...)` へ展開されていることを検証する

## 対象ファイル

- `.tmux.conf`
- `docs/project_docs/tmux-ccusage-statusline/plan.md`

## 検証項目

1. `tmux source-file ~/.tmux.conf`
2. `tmux show-options -g status-right` で battery/ccusage 由来の `#(...)` が含まれること
3. tmux の status bar 上で battery・月額 ccusage・当日 ccusage・日時が同時に見えること
