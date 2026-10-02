---
name: dispatch-vaio
description: 対話なしで完結する仕事を自宅サーバ vaio に投げるか mouse（このPC）で回すかを決め、投げる場合は vaio の background セッション（Remote Control 付き）に投入する。ready Issue の /issue-to-pr・/issue-to-merge、autopilot の金曜バッチ、「vaioで」「vaioに投げて」と言われた時、mouse の負荷を逃がしたい時に使う。
---

# dispatch-vaio

mouse が唯一の対話・memory 書き込み拠点で、vaio は投げられた仕事を background セッションで処理する worker。詰まったらスマホや claude.ai/code から答えられる。

## 振り分け

**vaio**: 対話なしで最後まで終わる仕事
- ready Issue の `/issue-to-pr` / `/issue-to-merge`、`autopilot` の消化
- 単発の起票・docs 更新

**mouse**: 判断を挟む仕事と、お金・サーバに触る仕事
- 調査・設計相談
- 送金・deploy・本番サーバ操作（実行場所を1台に絞り事故を追跡しやすくする）
- submodule や main 作業ツリーの状態に依存する作業

vaio の受け入れは busy 2本まで かつ 空きメモリ 2.5GB 以上（tsc peak 1.8GB + agent 分）。重いのは agent でなく tsc/vitest で、
これは repo 側の lock（xchain-arb は `prepush-checks.lock`）が直列化する前提。lock の無い repo を並べると tsc が重なり得る。
判定と起動は vaio 上の1つの lock の中で行い、新セッションが busy に見えるまで（最大120秒）lock を離さない。
`run` は空きが無ければ断る（急ぎなら mouse）。`queue` は空くまで60秒おきに待つので、複数 queue を積んでも上限は守られる。
ユーザーが「mouse で」「vaio で」と言えばそれに従う。行き先は投げた後に1行で報告する。

## 空き確認

`dispatch.sh res` で両機の load / 空きメモリ / swap / claude 本数 / tsc・vitest 本数を1行ずつ出す。
見るべきは本数ではなく重いジョブ: agent 本体は1本 約300MB・CPU 約5% だが、tsc は peak 1.8GB（vaio で40秒）、vitest は全コアを使う。
mouse は外では power-saver（turbo off）なので、CPU は数字ほど余っていない。

## 投入

```bash
S=~/.claude/skills/dispatch-vaio/scripts/dispatch.sh
$S run ~/repo/<repo> "/issue-to-pr 3981"            # 1本。vaio に空きが無ければ断る
$S queue ~/repo/<repo> "/issue-to-pr 3980" "/issue-to-pr 3981"   # 空き次第順に（最大2本並走）。出発前に積む用
$S status    # セッション一覧と Remote Control の URL
$S clean     # idle の background セッションを止める
$S res
```

投入前に memory の一方向同期（mouse→vaio, `--delete`）と vaio の `~/.claude`・repo の `pull --ff-only` を行い、
`claude --bg --remote-control` で起動する。`-p` ではなく対話セッションなので、判断待ちで止まったら
`status` の URL（claude.ai/code・スマホアプリ）か vaio で `claude attach <id>` から答えて続けられる。

- 終わったセッションも idle で残り1本 約300MB を持つ。PR を確認したら `clean`
- background セッションは未 trust のディレクトリで起動を拒否する（新しい repo は vaio で一度 `claude` を開いて承認）
- vaio で走る skill の改訂は、mouse の `~/.claude` を push してからでないと届かない
- vaio 側の memory 書き込みは次の同期で消える。残す価値のある知見は PR 本文から拾って mouse 側で memory に入れる
