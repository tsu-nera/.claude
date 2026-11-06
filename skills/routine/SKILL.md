---
name: routine
description: vaio に常駐する routine runner（`~/repo/scripts/routine`）へ定期タスクを会話から足す・直す・止める・様子を見る。「毎朝〜して」「1日1回〜まとめて」「定期的に〜を見張って」「〜になったら通知して」「routine を足して/止めて」「routine のログ・使用量を見せて」と言われた時に使う。cron や systemd timer を個別に足す前、/schedule（クラウド）や /loop・CronCreate（セッション内）を選ぶ前にも必ずこれを読む。
---

# routine

タスクの書式（frontmatter・check の exit code・dedup）は `~/repo/scripts/routine` の docstring が正典。ここには落とし穴だけを書く。

## 足す

- タスク 1 本 = `.md` 1 枚。その仕事が属する repo に置く（xchain-arb なら `scripts/ops/routines/`）。新しい置き場を作ったら vaio の `~/.config/routine/dirs` に1行足す（git 外）
- runner が毎回 `git pull --ff-only` するので push だけで次の tick（5分以内）に反映される。新しい置き場を `dirs` に足した時だけ vaio に clone があるか確かめる。vaio の clone が汚れていて pull に失敗すると `[routine:pull]` が DM に来て、古い checkout のまま回る
- 変化を見るだけのタスクは check script だけで書き、本文（prompt）を空にする。Claude が起動せず token は 0
- prompt は1回で約3.3万 token の基礎量がかかる（CLAUDE.md・memory の読み込み）。check で「変化あり」の時だけ走らせ、軽いものは `model: haiku`、間隔は必要以上に短くしない
- 無人実行なので、署名・送信・deploy をするタスクは作らない。prompt に `Bash` を `tools:` で渡さない。売買などはコマンドを通知に載せて人が打つ
- 期限があるものは `until:` を付ける

## 確かめる

- 作ったら `ssh vaio "~/.local/bin/routine test <name>"`（予定と dedup を無視して1回走らせ、送らずに表示）
- 非対話の ssh では `~/.local/bin` が PATH に無いのでフルパスで呼ぶ
- `ssh vaio "~/.local/bin/routine ls"` で予定・最終実行・エラー・直近7日の prompt 回数と token
- `ssh vaio "~/.local/bin/routine log [name] [N]"` で実行ごとの結果（idle / sent / unchanged / check-error / failed と所要秒）、`routine show <name>` で最後に送った全文
- timer 自体の失敗は `ssh vaio journalctl --user -u routine.service`

## 止める・直す

- 止める: ファイルを消して push → vaio で pull。一時停止なら `until:` を過去日にする
- 通知が増えてきたら、即時は急ぎ（人が今動くもの）だけに絞り、残りは1日1回のまとめタスクに寄せる

## 位置づけ

Claude 公式の常駐型が出るまでのつなぎ。runner は作り込まない。チャットでタスクと対話したい・タスク間で文脈を共有したい・数十本超で並列が要る、となったら runner を育てず openclaw か公式製品への移行を提案する。タスクを prompt と check script だけで書いておくのは、移行先へそのまま持っていくため。
