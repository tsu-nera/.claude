---
name: long-run
description: 30分を超えて回し続ける処理（計測スクリプト、clip ladder 等の時系列サンプリング、deploy 後の数時間監視、ログの定点観測）を始める前に必ず使う。mouse（このPC）は夕方に電源を落とすので、run_in_background や nohup で mouse に置くと途中で死ぬ。行き先を決め、vaio なら同梱スクリプトで Claude なしに常駐させ、結果を既存の PR / Issue へ定期コメントして needs-answer で止める。「N時間計測して」「しばらく様子を見て」「deploy 後に監視」「24h 回して」「残りは vaio で」と言われた時、自分で長時間ジョブを起動しようとした時に使う。
---

# long-run

`long-run.sh`（このディレクトリ）は vaio 上で動き、mouse から叩くと ssh で転送される。ジョブは `systemd-run --user` で常駐するので、ssh を切っても mouse を落としても続く。途中は Claude を使わない（待つだけのセッションはトークンを焼き、落ちれば読み手も消える）。

## 振り分け

- **計測（判定は後でよい）**: 時間帯に関係なく vaio。mouse から起動するので手間は変わらない
- **deploy 直後の監視（異常時にすぐ手を打つ）**: ユーザーがいる間は mouse のセッションで見る（その場で調べて止められるのが価値）。ユーザーが離れる・PC を落とすと言ったら、残りを vaio に渡す。vaio 側は検知して書くだけで、対応は人が戻ってから
- 30分以内に終わる、または Claude の判断を途中で何度も挟む調査は対象外（mouse のセッションでそのままやる）

## 結果の置き場

`--to` は、その機能の PR か元の Issue。監視のために Issue を新しく立てない（PR も Issue も無い直コミットの時だけ立てる）。
判定基準は起動前にその PR / Issue に書いておく。終わった時に、mouse でも vaio（Remote Control）でも同じ結論になる情報を Issue に書き切るのが引き継ぎの全て（memory は両機で同期しない）。

## 起動

```bash
~/.claude/skills/long-run/long-run.sh start xchain-arb --to 4139 --for 24h --every 3h \
  --sync scripts/scratch/foo.ts --sync scripts/scratch/foo-summary.sh \
  --summary 'scripts/scratch/foo-summary.sh tmp/foo.jsonl' \
  -- pnpm exec ts-node scripts/scratch/foo.ts --out tmp/foo.jsonl
long-run.sh ls / log <unit> / stop <unit>
```

- `--summary` の出力（markdown）がそのままコメント本文になる。計測側は追記型ファイル（jsonl 等）に書き、集計は読むだけにする。集計を後から直しても、次のコメントから反映される
- `--for` を過ぎるとジョブを止めて最終コメントを書き、`needs-answer` を付ける。ジョブが先に終われば、その時点で最終コメント
- 起動したら、unit 名と「いつ・どこにコメントが来るか」を1行で報告し、`--to` にも開始のコメントを書く

## 落とし穴

- project は `~/.claude/skills/autopilot/projects.conf` の名前。コマンドは vaio のその checkout を cwd に、login shell で走る（素の `ssh vaio 'cmd'` は PATH に asdf が入らず、Node が古い `/usr/local/bin/node` v20 になる）
- `scripts/scratch/` などの gitignore 下のファイルは git では届かない。`--sync` で mouse の checkout から同じ相対パスへコピーする。commit 済みのファイルは vaio の checkout が古いと届いていないので、必要なら先に vaio で pull する
- このスクリプト自体は `~/.claude` を push しないと vaio に届かない（転送時に vaio で `git pull --ff-only` する）
- 実弾（署名して送る操作・deploy・本番サーバの変更）は無人ジョブに入れない。repo の規約が優先
- 試すときは `--dry` を付ける（コメントを `~/.local/state/long-run/<unit>/comments.md` に書き出し、ラベルも付けない）。環境変数は ssh 転送で落ちるので使えない。テストでも `--to` には自分の Issue を使う
