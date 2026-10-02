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
autopilot start all --urgent                   # 帰宅後: 急ぎだけ（all = REPOS の全 repo）
autopilot start xchain-arb --until 07:00       # 木金の深夜: 期限後は新規起動しない
autopilot stop xchain-arb                      # 以後の起動を止める（起動済みは走り続ける）
autopilot status / clean / res
```

既定 skill は `/issue-to-merge`（`--skill /issue-to-pr` で変更）。ログは vaio の `~/.local/state/autopilot/<repo>/log`。

## 落とし穴

- 受け入れは vaio 全体で busy 2本・空きメモリ 2.5GB 以上。1つの loop は自分の1本が idle になるまで次を起動しないので、2 repo の loop が並走できる。
  重いのは agent でなく tsc/vitest で、repo 側の lock（xchain-arb は `prepush-checks.lock`）が直列化する前提
- background セッションは未 trust のディレクトリで起動を拒否する（新しい repo は vaio の `~/.claude.json` で承認）
- memory は同期しない。worker は Issue 本文と repo の規約だけで動く（ready Issue は自己完結の粒度で書く）。残す知見は PR 本文に書かせ、mouse 側で拾う
- skill や CLI の改訂は `~/.claude` を push してから届く（`start` が vaio で pull する）
- 終わったセッションも idle で残り1本 約300MB を持つ。PR を確認したら `clean`
- 5時間枠の上限に当たったセッションは「続けて」と答えるまで止まる。朝に `status` で確認する
