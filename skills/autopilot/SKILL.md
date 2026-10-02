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
autopilot stop xchain-arb                      # 以後の起動を止める（起動済みは走り続ける）
autopilot projects                             # 定義済みプロジェクトと vaio 側の準備状況
autopilot status / clean / res
```

既定 skill は `/issue-to-merge`（`--skill /issue-to-pr` で変更）。ログは vaio の `~/.local/state/autopilot/<repo>/log`。

## 落とし穴

- 受け入れは vaio 全体で busy 2本・空きメモリ 2.5GB 以上。1つの loop は自分の1本が idle になるまで次を起動しないので、2 repo の loop が並走できる。
  重いのは agent でなく tsc/vitest で、repo 側の lock（xchain-arb は `prepush-checks.lock`）が直列化する前提
- プロジェクトは `projects.conf` に定義する。追加したら vaio に clone・`~/.claude.json` で trust・`autopilot`/`urgent` ラベル作成が要る（`autopilot projects` で点検。未 trust だと background セッションが起動を拒否する）
- memory は同期しない。worker は Issue 本文と repo の規約だけで動く（ready Issue は自己完結の粒度で書く）。残す知見は PR 本文に書かせ、mouse 側で拾う
- skill や CLI の改訂は `~/.claude` を push してから届く（`start` が vaio で pull する）
- 終わったセッションも idle で残り1本 約300MB を持つ。PR を確認したら `clean`
- 起動前に statusline の使用率（`~/.cache/claude-rate-limits.json`）を見る。5h が90%以上なら reset まで待ち、週が98%以上なら止める（週は使い切る方針。余らせても reset で消える）
- loop は、セッションが `done` 以外で止まるか3分未満で終わると HALTED を出して止まる（5時間枠の上限・エラー・質問待ちで、次を起動しても同じ壁に当たるため）。`ls` の最終行で気づき、`claude attach <id>` で答えてから `start` し直す。`add` で積む短いプロンプトもこれに掛かる
