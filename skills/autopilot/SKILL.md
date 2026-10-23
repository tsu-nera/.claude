---
name: autopilot
description: 対話なしで完結する仕事を iiyama（このPC）で回すか自宅の worker（mouse / vaio）に任せるかを決め、任せるなら `autopilot` CLI のキューに積んで流す。ready Issue の /issue-to-pr・/issue-to-merge、autopilot・urgent ラベルの Issue の消化、「vaioで」「mouseで」「投げて」「今夜流しておいて」と言われた時、iiyama の負荷を逃がしたい時に使う。
---

# autopilot

振り分けは2段。1段目はここ（iiyama）で、iiyama でやるか worker に任せるかを決める。2段目は vaio の loop が、ジョブ1本ごとに空きのある worker のうち busy の少ない方（同数なら `workers.conf` の順 = mouse → vaio）を選ぶ。1つの loop は既定で2本まで並行して走らせるので、mouse と vaio に1本ずつ載る。寝ている mouse は vaio が WoL で起こし、loop が起こしたものは何も残らなくなったら寝かせ直す。2段目はスクリプトで、ここでは判断しない。
`autopilot` CLI（`~/.claude/bin/autopilot`）は vaio 上で動き、iiyama から叩くと ssh で vaio に転送される。
起動はユーザーが流したい時だけ（常駐 cron は持たない。週の rate limit を毎晩使わないため）。

## 振り分け（1段目）

**worker**: 対話なしで最後まで終わる仕事（ready Issue の実装、`autopilot` ラベルの消化、単発の docs 更新）
**iiyama**: 判断を挟む仕事、送金・deploy・本番サーバ操作、main 作業ツリーや submodule・`resources/` キャッシュに依存する作業、
全走テストの計測を含む仕事（実行先が mouse か vaio か選べないため）

ユーザーが「iiyama で」と言えばそれに従う。「mouse で」「vaio で」は実行先を選べないので、worker に積む。行き先（iiyama か worker か。worker なら `ls`・`[start]` 通知に出る実行先）は積んだ後に1行で報告する。

対話セッションから積んだら、`autopilot watch <repo>` を `run_in_background` で張る。ジョブが blocked / needs-answer / failed になるか、loop が理由を問わず止まると抜けるので、呼び戻されたらすぐ報告・対処できる。watch は iiyama から30秒ごとに vaio を見に行き、受け取った止まり目に ack を付ける。ack の付いた止まり目は #hitl に送られず、2分以内に誰も受け取らなかったものだけが #hitl に行く（iiyama のスリープ・セッション終了も同じ扱い）。抜けた後も loop が続いているなら張り直す（張っていない間の止まり目は #hitl に行く）。

blocked の質問が委任の範囲内（merge-gate の機械的な上限など）なら、自分で答えてから `autopilot start` し直す。範囲外なら `hitl ask "<repo>#<番号> <題>" "<調べた結果>" "<選択肢と推奨>"` で #hitl に上げる（答える場所は既定で vaio-ops。ユーザーは外出先から答える前提で、文面だけで判断できるように書く）。

## キュー

repo ごとに、`add` で積んだ自由プロンプト → `autopilot`+`urgent` → 残りの `autopilot` の順で流れる。
Issue は起動のたびに GitHub から取り直すので、ラベルの付け外しがそのまま追加・取消になる。linked PR のある Issue は飛ばす。

```bash
autopilot ls                                   # 実行中と、これから流れる順
autopilot add xchain-arb 3820 [--urgent]       # ラベルを付ける
autopilot add xchain-arb "/task-to-merge ..."  # 自由プロンプトを積む
autopilot rm xchain-arb 3820                   # ラベルを外す / 積んだプロンプトを消す
autopilot start all --urgent                   # 帰宅後: 急ぎだけ（all = projects.conf の全プロジェクト）
autopilot start xchain-arb --until 07:00       # 木金の深夜: 期限後は新規起動しない
autopilot start all --5h-max 60                # 5h 枠を 60% で止め、残りを対話用に残す（reset 後は再開）
autopilot start xchain-arb --parallel 1        # 1本ずつ直列（既定は2本並行）
autopilot stop xchain-arb                      # loop を止める（起動済みは走り続ける。start し直すと実行中のジョブを枠に数えて判定してから続ける）
autopilot pause all / resume all              # loop を生かしたまま新規起動だけ止める / 再開する
autopilot watch xchain-arb                     # 止まり目まで待つ（run_in_background 用）
autopilot projects                             # 定義済みプロジェクトと各 worker の準備状況（寝ている worker は見ない）
autopilot status / clean / res
```

ラベルの Issue は常に `/issue-to-merge` で merge まで進む。merge 前に人の判断が要るもの（merge 後に deploy して観察する等）はラベルを付けず、`autopilot add <repo> "/issue-to-pr <番号>"` で積む。モデルは settings.json の既定（opus[1m]）で、`--model sonnet` で loop ごとに変えられる。ログは vaio の `~/.local/state/autopilot/<repo>/log`、ジョブごとの結果は同じ場所の `history`、loop が止まった理由は `last-exit`（`ls` にも出る）。

## 落とし穴

- 受け入れの上限（busy 本数・空きメモリ）は worker ごとに `workers.conf` にある。mouse の値（3本・3GB）は未計測の仮置き。1つの loop が同時に走らせるのは `--parallel`（既定2）本までで、worker の枠は全 repo の loop で共有する。
- 並行時の順序は GitHub の blocked-by だけが守る。open な blocker が残る Issue は `plan` が skip する（`ls` に `skip issue N blocked by` と出る）。連番で依存する子 Issue は blocked-by を張って積む（split-issue / create-subissue の手順にある）。張らずに積んだシリーズは `--parallel 1` で流す。`add` で積んだ prompt は依存を表せないので、prompt 同士は1本ずつ（Issue は追い越してよい）
  重いのは agent でなく tsc/vitest で、repo 側の lock（xchain-arb は `prepush-checks.lock`）が直列化する前提
- プロジェクトは `projects.conf` に定義する。追加したら各 worker に clone・`~/.claude.json` で trust・`autopilot`/`urgent` ラベル作成が要る（`autopilot projects` で点検。準備の無い worker は飛ばされ、vaio が未 trust なら `start` が止まる）
- worker は `workers.conf` に定義する。起こし方の `wake-mouse` は vaio の `~/.local/bin`（MAC・IP 入りなので public の `~/.claude` に入れない）。loop が起こした worker は、loop が終わった時に生きたセッションが残っていなければ寝かせ直す（5秒後の suspend 予約。他の loop は止めない理由にならない＝要る時にまた起こす。blocked が残る間は起きたまま。`clean` の後にも見直す）。起きていたものは寝かせない。寝起きをまたいでも bg セッションは続きから動く（2026-10-21 確認）
- 寝ている worker は起こせても `WAKE_WAIT`（90秒）以内に ssh が通らなければ10分間飛ばされ、その間は vaio だけで回る
- busy の数え方・待ち方・判定はどれも `claude agents --json` を読む。形は公開された約束ではなく版で違う（id・status の有無）うえ、worker ごとに勝手に自動更新される。`start` と毎回の起動前に `_w-check` で点検し、知らない形なら HALTED で止まる（その時は `cmd_w_check` と読む側を新しい形に合わせる）
- ジョブの実行中に worker へ15分届かない（電源・Wi-Fi・スリープ）と HALTED で #hitl に上がる。新規起動は止まるが、他の worker のジョブは最後まで待って判定する。届かないジョブは向こうで生きている可能性があるので `jobs/` に残し、起こして `start` すると前のジョブを待って判定してから続ける
- memory は同期せず、worker は auto memory を切って起動する（`--settings`。bg daemon は呼び出し側の環境変数を渡さない）。worker は Issue 本文と repo の規約だけで動く（ready Issue は自己完結の粒度で書く）。残す知見は PR 本文に書かせ、iiyama 側で拾う
- skill や CLI の改訂は `~/.claude` を push してから届く（`start` が vaio で、ジョブの起動時に他の worker で pull する）
- 人の対応が要る通知は Discord の #hitl（`~/.claude/bin/hitl`）。`needs-answer` が付いた Issue / PR は `hitl-scan.timer` が5分ごとに拾って送り、`[blocked]`・`[HALTED]` は loop が直接送る。どれも「何が起きた／決めること／答える場所（Remote Control の URL、既定は vaio 常駐の vaio-ops = `claude-rc-ops.service`。xchain-arb の障害対応用は別の xchain-ops）」の型（`hitl ask`）。下の autopilot 用 webhook はログとして流すだけ
- Discord 通知はジョブの開始・完了（HALTED 含む）だけ。vaio の `~/.config/autopilot/discord-webhook`（git 外・chmod 600）に URL があれば送る。無ければ何もしない
- 成功したセッション（done か Issue が PR で close 済み）は loop が `claude stop` する。blocked / HALTED は答えるために残る（1本 約300MB）。答え終えたものや loop の外で起動したものは `clean`
- 起動前に statusline の使用率（`~/.cache/claude-rate-limits.json`）を見る。5h が90%以上なら reset まで待ち、週が98%以上なら止める（週は使い切る方針。余らせても reset で消える）
- 最後の発言が API エラー（transcript の `isApiErrorMessage`）で終わったジョブは質問扱いせず、積み直して 10分→30分待って再起動する（回数は loop 単位で連続を数える。障害は全ジョブに同時に出るため）。3回目、または `model_not_found` のような待っても直らない種類なら HALTED
- loop は、セッションが `done` 以外で止まるか3分未満で終わると HALTED を出して止まる（5時間枠の上限・エラーは次を起動しても同じ壁に当たるため）。`ls` の最終行か #hitl で気づき、通知の Remote Control の URL（その worker の端末なら `claude attach <id>`。どの worker かはログと通知に出る）で答えてから `start` し直す。`add` で積む短いプロンプトもこれに掛かる。例外: Issue が PR で close 済みなら state・経過時間に関わらず done 扱い、`blocked`（質問待ち）はその1本を飛ばして続ける（`[blocked]` 通知。答えた後の再実行は `autopilot add`）
