# BOXP-96: 構造化失敗を再発単位へ分ける分類設計

## 目的と現状差分

`end-of-day-ai-retro` collectorが観測した構造化失敗を、同じ対処方法を共有できる原因単位で数える。異なる秘匿済みsession識別子が2件以上ある分類だけを `structured-failure-review` 候補にし、単発事故や1session内の反復を恒久化根拠にしない。

`d26b4c0` 時点では、per-sessionの `sort -u`、2session閾値、最大3候補は実装済みである。一方、非0終了をすべて `nonzero-exit` にまとめるため原因の異なるcommand失敗を再発扱いでき、未知recordのhashはrecord全体に依存するためtimestamp、record ID、一時pathだけの違いで別分類になり得る。また、複数分類が閾値を満たしても先頭1分類しか候補にしない。

BOXP-87から、同日artifactの置換、欠損sourceと壊れたJSONLの部分縮退、最大3候補、人間承認後の別ticket/PR、public/private境界を引き継ぐ。CLIと4artifact（`report.md`、`run-summary.edn`、`missing-sources.tsv`、`input-inventory.tsv`）の契約は変更しない。

## 分類対象となる構造化失敗

対象は当日へfilter済みのJSONL recordのうち、次のいずれかを満たすものとする。

- `type` または `payload.type` が `error`
- `status` または `payload.status` が `failed`
- recordまたはpayloadの `is_error` が `true`
- message content内の `tool_result` が `is_error: true`
- tool output recordが直接またはJSON化されたoutput内に、正の整数であるJSON numberまたは10進数文字列の `exit_code` を持つ。小数値は終了コードとして扱わない

user/assistantの通常message、完了event、raw prompt/responseは分類入力にしない。失敗recordから `error`、`message`、`content`、`output`、`stderr`、`reason`、`detail(s)` の既知fieldだけを原因本文として抽出し、record全体や同sessionの別messageをfingerprintへ混ぜない。

## 分類キーの構成と判定順序

分類キーは `<原因family>:<対処単位>:signature-<12hex>` とする。semantic prefixで対処先を示し、揮発値を除いた原因signatureで広いkeyword bucket内の異なる原因を分離する。表の上から先に一致した規則を採用し、複数のfamilyへ重複分類しない。

| 順序 | family | 対処単位の例 | 主な対処 |
|---|---|---|---|
| 1 | `authentication` | `missing-credential`、`invalid-credential`、`unauthorized` | credential供給・更新、認証設定 |
| 2 | `rate-limit` | `quota`、`requests` | quota・retry/backoff |
| 3 | `permission` | `sandbox`、`filesystem`、`forbidden` | approval/policyまたはfilesystem権限 |
| 4 | `timeout` | `deadline`、`network`、`operation` | deadline、network、処理timeout |
| 5 | `network` | `dns`、`connection-refused`、`tls`、`host-unreachable`、`connection` | 名前解決、接続先、証明書、経路 |
| 6 | `not-found` / `dependency` | `command`、`file`、`http-resource`、`dependency:missing` | executable、path/resource、依存導入 |
| 7 | nonzero fallback | `nonzero-exit:code-N:signature-<12hex>` | 同じexit codeと正規化原因本文の調査 |
| 8 | unknown fallback | `unknown:signature-<12hex>` | 同じ正規化構造化errorの調査 |

`permission` と `authentication`、`timeout` と `network` のように語が併存する場合は、上記順序で対処先を一意にする。既知familyにもsignatureを付けるため、同じ `timeout:operation` や `dependency:missing` に見えても正規化原因が異なる失敗は別分類になる。広すぎる `nonzero-exit`、`permission`、`timeout` の単独キーは使わない。

### 揮発値の正規化

既知規則の判定とfallback fingerprintの前に、原因本文を小文字化して次をplaceholderへ置換し、空白を畳む。

- ISO 8601 timestamp
- UUID、長いhex値、memory address
- `request_id` / `record_id` / `session_id` / `trace_id` / `call_id` 等の識別子値
- `/tmp/...` とmacOSの `/var/folders/...` 配下の一時path
- PID等になり得る長い数値、duration値

同一原因ならこれらが違っても同じfallback keyになる。exit codeや原因を表す通常の語は残すため、原因本文の異なる非0終了は別のsignatureになる。

### 未知失敗のfallback

既知規則に一致しない正のexit codeは、exit codeと正規化原因本文の短縮SHA-256から `nonzero-exit:code-N:signature-<12hex>` を作る。その他の未知の構造化失敗は `unknown:signature-<12hex>` とする。raw原因本文やcommand全文をkey・report・run artifactへ保存しない。fallbackは未知recordを一律の `unknown` にまとめず、完全なrecord IDやtimestampにも依存しない。

## 再発の計数と候補選択

1. 1session file内で同じ分類キーが複数recordに現れても `sort -u` し、最大1件とする。
2. 集計時にも `(分類キー, 秘匿済みsession識別子)` を重複排除し、distinct session件数を数える。
3. distinct session件数が2件以上の分類だけを `structured-failure-review` 候補にする。単一session内の反復とdistinct 1件の分類は候補にしない。
4. 閾値を満たす分類を件数降順、同数なら分類キー昇順で並べる。各分類を独立した候補にし、その後に既存の `broken-jsonl`、`missing-source` を続け、全体の先頭3件だけを出す。
5. 各structured候補には分類キー、distinct session件数、その分類に該当する全ての秘匿済みsession識別子を出す。

reportには候補外のsingletonも含む「分類別集計」を同じ決定順で載せる。これによりprivate run間で分類別件数を比較できるが、raw本文は載せない。

## 秘匿境界と自動変更禁止

- session path/filenameは `source:<pathの短縮SHA-256>` にし、raw pathをartifactへ保存しない。
- raw prompt/response、command全文、error本文、secret、token、email、private IP、個人情報をreport、run artifact、public fixtureへ保存しない。
- public fixtureは架空の短い原因文字列と架空ID/pathだけを使う。
- 日次runが変更できるのは指定private output rootの対象日artifactだけ。repo、agent設定、skill、rules、live job、Task Board、clusterを自動変更しない。
- 候補は提案で停止し、人間が採否を判断した後だけ別ticket/worktree/review/PRで実装する。

## Fixtureと検証

架空fixtureで次を検証する。

- 同一原因が別sessionで2件なら候補になる。
- 原因の異なる非0終了が各1件なら別signatureになり、候補にならない。
- 同一session内で同じ失敗recordが複数あってもdistinct件数は1で、候補にならない。
- timestamp、record ID、一時pathだけ異なる同一原因は同じ分類になる。
- `error` / `payload.error` がobjectの場合も、JSON化された `request_id` / `call_id` の差を除去できる。
- `payload` / `message` が文字列でもmetrics・tool result探索を停止せず、数値文字列の非0終了を分類する。
- `message` / `payload.message` がobjectの場合は既知の原因fieldを抽出し、異なる原因を同じunknownへ集約しない。
- `exit_code` はtool/function output型のrecordだけで失敗判定し、通常messageやtelemetryの同名fieldは分類しない。
- 直接fieldまたは埋め込みJSONの小数 `exit_code` は整数へ丸めず、失敗分類から除外する。
- 優先timestampがnull・不正でもnested wrapperに有効なtimestampがあれば当日recordとして分類する。
- 既知規則に一致しない失敗はstableな `unknown:signature-*` fallbackになる。
- 複数分類は件数降順・分類キー昇順、最大3候補になる。
- 既存permission/timeout、欠損source、壊れたJSONL、秘匿check、時刻filter、同日置換を回帰させない。

実装後に次を実行する。

```bash
bash .claude/skills/end-of-day-ai-retro/tests/run-tests.sh
bash -n .claude/skills/end-of-day-ai-retro/scripts/generate-report.sh
bash -n .claude/skills/end-of-day-ai-retro/tests/run-tests.sh
shellcheck .claude/skills/end-of-day-ai-retro/scripts/generate-report.sh \
  .claude/skills/end-of-day-ai-retro/tests/run-tests.sh  # 利用可能な場合
```

## 次回3営業日のprivate run確認

次回runから連続する3営業日（現時点の予定は2026-07-13、07-14、07-15。休日・停止日は次の稼働日へ繰り越す）に、private artifactだけを人間が確認する。

1. `report.md` の分類別集計から、分類キー、distinct session件数、秘匿済み識別子を前日と比較する。
2. 2session以上の分類だけが候補になり、singletonと1session内重複が候補外であることを確認する。
3. 複数候補の順序が件数降順・分類キー昇順で、候補総数が3以下であることを確認する。
4. `sanitize-check.sh report.md`、`run-summary.edn` の `:automatic-changes false`、raw本文/path/secret非保存を確認する。
5. 誤集約または分割過多があれば、raw本文をpublic issue/PRへ転載せず、秘匿済み分類キーと件数だけで別ticketに判断を記録する。

private cron promptはcollectorを1回呼ぶ薄いwrapperであり、CLIとartifact構成を変えないため本ticketでは変更しない。live jobや既存run artifactも直接書き換えない。
