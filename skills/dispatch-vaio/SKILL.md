---
name: dispatch-vaio
description: 対話なしで完結する仕事を自宅サーバ vaio に投げるか mouse（このPC）で回すかを決め、投げる場合は claude -p で vaio に投入する。ready Issue の /issue-to-pr・/issue-to-merge、autopilot の金曜バッチ、「vaioで」「vaioに投げて」と言われた時、mouse の負荷を逃がしたい時に使う。
---

# dispatch-vaio

mouse が唯一の対話・memory 書き込み拠点で、vaio は投げられた仕事を `claude -p` で黙って処理する worker。

## 振り分け

**vaio**: 対話なしで最後まで終わる仕事
- ready Issue の `/issue-to-pr` / `/issue-to-merge`、`autopilot` の消化
- 単発の起票・docs 更新

**mouse**: 判断を挟む仕事と、お金・サーバに触る仕事
- 調査・設計相談・daily-screen の optimize 以降
- 実弾送金・`with-nonce-tunnel.sh` 経由の ops・deploy・conoha 操作（実行場所を1台に絞り事故を追跡しやすくする）
- ledger 系（`resources/ledger` submodule と main 作業ツリーが前提）

vaio は同時1本（4スレッド・RAM 7.6GB で tsc が 1.8GB 食う）。埋まっていれば急ぎなら mouse、でなければ空くまで待つ。
ユーザーが「mouse で」「vaio で」と言えばそれに従う。行き先は投げた後に1行で報告する。

## 空き確認

`dispatch.sh res` で両機の load / 空きメモリ / swap / claude 本数 / tsc・vitest 本数を1行ずつ出す。
見るべきは本数ではなく重いジョブ: agent 本体は1本 約300MB・CPU 約5% だが、tsc は peak 1.8GB（vaio で40秒）、vitest は全コアを使う。
mouse は外では power-saver（turbo off）なので、CPU は数字ほど余っていない。

## 投入

```bash
~/.claude/skills/dispatch-vaio/scripts/dispatch.sh run ~/repo/xchain-arb "/issue-to-pr 3981"
~/.claude/skills/dispatch-vaio/scripts/dispatch.sh status
~/.claude/skills/dispatch-vaio/scripts/dispatch.sh res
```

script が memory の一方向同期（mouse→vaio, `--delete`）→ vaio の `~/.claude` と repo の `pull --ff-only` → tmux 内で `claude -p` まで行う。

- vaio で走る skill の改訂は、mouse の `~/.claude` を push してからでないと届かない
- vaio 側の memory 書き込みは次の同期で消える。残す価値のある知見は PR 本文から拾って mouse 側で memory に入れる
- 完了は PR/Issue の更新か `status` で確認する。log は stream-json
