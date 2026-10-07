---
name: autopilot
description: 対話なしで完結する仕事を自宅サーバ vaio で自走させるか mouse（このPC）で回すかを決め、vaio なら `autopilot` CLI のキューに積んで流す。ready Issue の /issue-to-pr・/issue-to-merge、autopilot・urgent ラベルの Issue の消化、「vaioで」「vaioに投げて」「今夜流しておいて」と言われた時、mouse の負荷を逃がしたい時に使う。
---

# autopilot

vaio が worker。`autopilot` CLI（`~/.claude/bin/autopilot`）は vaio 上で動き、mouse から叩くと ssh で vaio に転送される。
起動はユーザーが流したい時だけ（常駐 cron は持たない。週の rate limit を毎晩使わないため）。

## 振り分け

**vaio**: 対話なしで最後まで終わる仕事（ready Issue の実装、`autopilot` ラベルの消化、単発の docs 更新）
**mouse**: 判断を挟む仕事、送金・deploy・本番サーバ操作、main 作業ツリーや submodule・`resources/` キャッシュに依存する作業、
全走テストの計測を含む仕事（vaio は 4 スレッド）

ユーザーが「mouse で」「vaio で」と言えばそれに従う。行き先は積んだ後に1行で報告する。

対話セッションから積んだら、`autopilot watch <repo>` を `run_in_background` で張る。ジョブが blocked / needs-answer / failed になるか、loop が理由を問わず止まると抜けるので、呼び戻されたらすぐ報告・対処できる。watch は mouse から30秒ごとに vaio を見に行き、受け取った止まり目に ack を付ける。ack の付いた止まり目は #hitl に送られず、2分以内に誰も受け取らなかったものだけが #hitl に行く（mouse のスリープ・セッション終了も同じ扱い）。抜けた後も loop が続いているなら張り直す（張っていない間の止まり目は #hitl に行く）。

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
autopilot stop xchain-arb                      # loop を止める（起動済みは走り続ける。start し直すと実行中の1本を待ってから続ける）
autopilot pause all / resume all              # loop を生かしたまま新規起動だけ止める / 再開する
autopilot watch xchain-arb                     # 止まり目まで待つ（run_in_background 用）
autopilot projects                             # 定義済みプロジェクトと vaio 側の準備状況
autopilot status / clean / res
```

ラベルの Issue は常に `/issue-to-merge` で merge まで進む。merge 前に人の判断が要るもの（merge 後に deploy して観察する等）はラベルを付けず、`autopilot add <repo> "/issue-to-pr <番号>"` で積む。モデルは settings.json の既定（opus[1m]）で、`--model sonnet` で loop ごとに変えられる。ログは vaio の `~/.local/state/autopilot/<repo>/log`、ジョブごとの結果は同じ場所の `history`、loop が止まった理由は `last-exit`（`ls` にも出る）。

## 落とし穴

- 受け入れは vaio 全体で busy 2本・空きメモリ 2.5GB 以上。1つの loop は自分の1本が idle になるまで次を起動しないので、2 repo の loop が並走できる。
  重いのは agent でなく tsc/vitest で、repo 側の lock（xchain-arb は `prepush-checks.lock`）が直列化する前提
- プロジェクトは `projects.conf` に定義する。追加したら vaio に clone・`~/.claude.json` で trust・`autopilot`/`urgent` ラベル作成が要る（`autopilot projects` で点検。未 trust だと background セッションが起動を拒否する）
- memory は同期せず、worker は auto memory を切って起動する（`--settings`。bg daemon は呼び出し側の環境変数を渡さない）。worker は Issue 本文と repo の規約だけで動く（ready Issue は自己完結の粒度で書く）。残す知見は PR 本文に書かせ、mouse 側で拾う
- skill や CLI の改訂は `~/.claude` を push してから届く（`start` が vaio で pull する）
- 人の対応が要る通知は Discord の #hitl（`~/.claude/bin/hitl`）。`needs-answer` が付いた Issue / PR は `hitl-scan.timer` が5分ごとに拾って送り、`[blocked]`・`[HALTED]` は loop が直接送る。どれも「何が起きた／決めること／答える場所（Remote Control の URL、既定は vaio 常駐の vaio-ops = `claude-rc-ops.service`。xchain-arb の障害対応用は別の xchain-ops）」の型（`hitl ask`）。下の autopilot 用 webhook はログとして流すだけ
- Discord 通知はジョブの開始・完了（HALTED 含む）だけ。vaio の `~/.config/autopilot/discord-webhook`（git 外・chmod 600）に URL があれば送る。無ければ何もしない
- 成功したセッション（done か Issue が PR で close 済み）は loop が `claude stop` する。blocked / HALTED は答えるために残る（1本 約300MB）。答え終えたものや loop の外で起動したものは `clean`
- 起動前に statusline の使用率（`~/.cache/claude-rate-limits.json`）を見る。5h が90%以上なら reset まで待ち、週が98%以上なら止める（週は使い切る方針。余らせても reset で消える）
- 最後の発言が API エラー（transcript の `isApiErrorMessage`）で終わったジョブは質問扱いせず、積み直して 10分→30分待って再起動する（回数は loop 単位で連続を数える。障害は全ジョブに同時に出るため）。3回目、または `model_not_found` のような待っても直らない種類なら HALTED
- loop は、セッションが `done` 以外で止まるか3分未満で終わると HALTED を出して止まる（5時間枠の上限・エラーは次を起動しても同じ壁に当たるため）。`ls` の最終行か #hitl で気づき、通知の Remote Control の URL（vaio の端末なら `claude attach <id>`）で答えてから `start` し直す。`add` で積む短いプロンプトもこれに掛かる。例外: Issue が PR で close 済みなら state・経過時間に関わらず done 扱い、`blocked`（質問待ち）はその1本を飛ばして続ける（`[blocked]` 通知。答えた後の再実行は `autopilot add`）
