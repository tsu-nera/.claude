---
name: inventory
description: 持ち物の台帳（正本は vaio の Homebox、写しは dailybuild-private の items.csv）に物を足す・手放した印を付ける・持っているか引く。「〜を買った」「所持品に登録して」「これ持ってたっけ」「〜を売った/捨てた」と言われた時、Binary Eye の共有文面（markusfisch.de の URL と JAN）が貼られた時に、どのリポジトリにいても使う。買う前の下調べは gtd の shopping。
---

# inventory

正本は vaio の Homebox（`http://100.93.3.10:3100`。本人は UI で直接直す）。`data/inventory/items.csv` は Homebox から書き出す生成物なので**直接書かない**。書き込みは dailybuild の CLI 経由:

```bash
cd ~/repo/dailybuild
uv run scripts/homebox.py add <key> --category <カテゴリ> [--subcategory ..] [--name ..] [--acquired-on YYYY-MM-DD] [--note ..]
uv run scripts/homebox.py add manual --name '<品名>' --category <カテゴリ> --acquired-on <日付> --note '<店名・価格・JAN>'
uv run scripts/homebox.py dispose <key> --date YYYY-MM-DD --how '<売却・粗大ごみ等>'
uv run scripts/homebox.py export   # 引く前に最新化
```

add / dispose は最後に items.csv まで書き出す。書き出した items.csv は dailybuild-private に commit して push する（日次の自動 commit と競るので、弾かれたら `git pull --rebase`）。品名・購入日・価格・購入先は key から `data/purchases/` を引いて埋まる。場所・写真は本人が UI で付ける。

## 何を記録するか

全部は入れない（本人が手間と感じる）。入れるのは、機器とつながる物・睡眠や体など計測データに効く物・毎日身につけて持ち歩く物。文房具・収納用品・消耗品は入れない。迷ったら本人に1行で聞く。

持っているか確かめていない購入履歴を一括投入しない。台帳に無い物は「所持不明」。

## キー

- Amazon: `amazon:<order_id>:<ASIN>`。開示データより新しい注文は先に `uv run scripts/purchases.py fetch` で追いつかせ、`data/purchases/gmail.csv` の `asin` 列からキーを作る。`manual` で入れると開示データ取り込み後に二重になる
- 楽天: `rakuten:<order_id>:<注文内の行番号>` / ユニクロ: `uniqlo:<購入日>:<商品番号>:<色コード>` / メルカリ: `mercari:<item_id>`
- 店頭購入など: `manual`（CLI が次の番号を振る）
- 本人が UI で足した物は key が無く、items.csv では `homebox:<id>`

## 店頭購入の JAN

本人は Android の Binary Eye で読み、共有文面ごと貼る。ダイソー品は一般の Web 検索や在庫アプリでは名前が出ないので、文面をそのまま渡して引く:

```bash
uv run ~/repo/gtd/scripts/shopping/daiso.py '<共有文面か JAN>'
```

見つからなければパッケージの写真の名前で入れる。購入日は本人に聞く（深夜は「本日」が前日を指すことがある）。

## カテゴリの語彙

- カテゴリは Homebox の親タグ、サブカテゴリはその子タグ。既存の名前を使い、増やすのは本人が決める
- 服・靴・小物のサブカテゴリ: Google 商品カテゴリ日本語版の名前（トップス / アウター / パンツ・ズボン / ショートパンツ / 下着・靴下 / スポーツウェア / 靴 / ハンドバッグ・財布 / ファッション小物）。例外として `メガネ` だけ自前。自転車のグローブはファッション小物、ジャージはスポーツウェア。サイズ・色は `uniqlo.csv` 等から join する
- 手放したら dispose。売値は `mercari.csv` 等にあるので写さない。過去に売った物を遡って入れない
