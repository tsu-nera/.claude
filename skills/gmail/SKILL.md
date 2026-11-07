---
name: gmail
description: 自分の Gmail を読む・探す・振り分ける・配信停止するときの落とし穴と、~/repo/gtd/scripts/gmail/ の自前スクリプトの使い分け。Gmail の画面 URL（mail.google.com/...#inbox/FMfcgz...）が貼られた時、メールの一覧・本文 grep、フィルタの追加・変更、メルマガの棚卸しや解除を頼まれた時に、MCP の Gmail ツールを呼ぶ前にどのリポジトリにいても使う。
---

# Gmail

スクリプトはすべて `cd ~/repo/gtd && uv run scripts/gmail/<name>.py ...` で動かす。認証トークンは gws（Google Workspace CLI）から受け取る。スコープエラーが出たら `docs/gmail-api-setup.md` の `gws auth login --scopes ...` をユーザーに頼む。

## 画面 URL からメールを開く

画面 URL の末尾 `FMfcgz...` は API の threadId ではない。MCP に渡すと「見つからない」と返る。Google は変換を公式にサポートしていない（googleworkspace/cli #790）。

1. `show.py '<URL>'` で変換して表示する。MCP で読みたい場合は、出力の hex ID を `get_thread` に渡す
2. 変換はリバースエンジニアリングで、値がずれた報告もある。件名・差出人・日付が会話の文脈と合うか確かめる
3. 変換に失敗するか中身が合わなければ、差出人・件名・日付で検索して見つける

`#inbox/` の後ろが16桁の hex なら、それ自体が threadId。

## 一覧・本文の検索

一覧を見るなら `search.py '<Gmail 検索式>'` を使う。MCP の `search_threads` は1回で数千 tokens 返す。本文を正規表現で絞るときは `--body '<regex>'` を付ける。

## フィルタ

正本は `scripts/gmail/gmailctl/config.jsonnet`。編集したら gmailctl で diff を確かめてから apply する（`--config scripts/gmail/gmailctl`）。Gmail の画面や API で直接作ったフィルタは、次の apply で消える。

- `labels:` 節を足してはいけない。足すと、列挙していないラベルを gmailctl が消しにいく
- 受信箱に残っている既存メールにも同じ処理を当てたいときは `create_filter.py`（既定は dry-run、`--execute` で実行）。これで作ったフィルタは config.jsonnet にも書き足しておく

## 配信停止

1. `unsubscribe_audit.py` で棚卸しする（解除はしない）
2. 解除する送信元をユーザーに選んでもらう
3. `unsubscribe_exec.py --audit FILE --sender ADDR` で1件ずつ実行する（既定は dry-run）。まとめて全部解除しない。送信は取り消せない
