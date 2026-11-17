---
name: gmail
description: 自分の Gmail を読む・探す・振り分ける・配信停止するときの落とし穴と、~/repo/gtd/scripts/gmail/ の自前スクリプトの使い分け。Gmail の画面 URL（mail.google.com/...#inbox/FMfcgz...）が貼られた時、メールの一覧・本文 grep、受信箱の整理、フィルタの追加・変更、メルマガの棚卸しや解除を頼まれた時に、MCP の Gmail ツールを呼ぶ前にどのリポジトリにいても使う。
---

# Gmail

スクリプトはすべて `cd ~/repo/gtd && uv run scripts/gmail/<name>.py ...` で動かす。認証トークンは gws（Google Workspace CLI）から受け取る。スコープエラーが出たら `docs/gmail-api-setup.md` の `gws auth login --scopes ...` をユーザーに頼む。

## 画面 URL からメールを開く

画面 URL の末尾 `FMfcgz...` は API の threadId ではない。MCP に渡すと「見つからない」と返る。Google は変換を公式にサポートしていない（googleworkspace/cli #790）。

1. `show.py '<URL>'` で変換して表示する。MCP で読みたい場合は、出力の hex ID を `get_thread` に渡す
2. 変換はリバースエンジニアリングで、値がずれた報告もある。件名・差出人・日付が会話の文脈と合うか確かめる
3. 変換に失敗するか中身が合わなければ、差出人・件名・日付で検索して見つける

`#inbox/` の後ろが16桁の hex なら、それ自体が threadId。

URL が指すのはメール1通ではなくスレッド全体。`show.py` が出すのは全メールのヘッダと snippet だけで、本文は出ない。「これ見て」と言われたら、受信箱に残っている最新の受信メールを、出力の `id:`（message ID）で `get_message` に渡して全文を読む。それより前のメールは snippet で流れを掴む。threadId はスレッド内のどの message ID とも一致しないことがあるので、threadId を message ID として使わない。

## 一覧・本文の検索

一覧を見るなら `search.py '<Gmail 検索式>'` を使う。MCP の `search_threads` は1回で数千 tokens 返す。本文を正規表現で絞るときは `--body '<regex>'` を付ける。

## ラベル・アーカイブ・ゴミ箱

Gmail MCP の書き込み系（`update_message_labels`・`label_*`・`unlabel_*`・`trash_thread`）はスコープ不足で失敗する。

- ラベル・アーカイブ・既読: `gws gmail users threads modify --params '{"userId":"me","id":"<thread ID>"}' --json '{"addLabelIds":[...],"removeLabelIds":["INBOX","UNREAD"]}'`。ユーザーラベルの ID（`Label_63` 等）は MCP の `list_labels` で引く
- ゴミ箱: `trash.py <thread ID>...`
- thread ID は search.py の2列目。MCP の `get_thread` が「見つからない」と返すスレッドは `gws gmail users messages get` で読める

## 受信箱整理

仕分けの基準は `~/.claude/projects/-home-tsu-nera-repo-gtd/memory/gmail-triage-rules.md`（予約・イベントは同じ memory の `schedule-google-calendar.md`）。

1. `search.py 'in:inbox'` で一覧し、1通ずつ「要対応で残す／アーカイブ／カレンダーに入れてアーカイブ／配信停止候補／フィルタ候補」に分けて表で見せる。自分が返信済みで先方待ちのスレッドはアーカイブ（返信が来れば受信箱に戻る）
2. フィルタ候補は既存フィルタへの追記を先に考え、`search.py '<条件>'` で過去の一致を見て巻き込みを確かめる
3. 承認後にフィルタを反映し、受信箱の分は gws の modify で処理する

## フィルタ

正本は `scripts/gmail/gmailctl/config.jsonnet`（`~/.config/gmailctl/` から symlink）。編集したら `~/go/bin/gmailctl diff` で確かめてから `apply --yes`。`--config scripts/gmail/gmailctl` は credentials が無く失敗する。Gmail の画面や API で直接作ったフィルタは、次の apply で消える。

- `labels:` 節を足してはいけない。足すと、列挙していないラベルを gmailctl が消しにいく
- gmailctl は既存メールに処理を当てない。当てるなら search.py で対象を出して gws の modify。`create_filter.py --execute` は Gmail 側にフィルタを直接作り config と二重になるので使わない（dry-run の一致件数だけ見る用途に残す）

## 配信停止

1. `unsubscribe_audit.py` で棚卸しする（解除はしない）
2. 解除する送信元をユーザーに選んでもらう
3. `unsubscribe_exec.py --audit FILE --sender ADDR` で1件ずつ実行する（既定は dry-run）。まとめて全部解除しない。送信は取り消せない
