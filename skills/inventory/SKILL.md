---
name: inventory
description: 持ち物の台帳（dailybuild-private の items.csv）に物を足す・手放した印を付ける・持っているか引く。「〜を買った」「所持品に登録して」「これ持ってたっけ」「〜を売った/捨てた」と言われた時、Binary Eye の共有文面（markusfisch.de の URL と JAN）が貼られた時に、どのリポジトリにいても使う。買う前の下調べは gtd の shopping。
---

# inventory

台帳は `~/repo/dailybuild-private/data/inventory/items.csv`（`key,name,category,subcategory,status,location,acquired_on,disposed_on,note`）。書いたら dailybuild-private に commit して push する。日次の自動 commit と競るので、push が弾かれたら `git pull --rebase` してから push。

## 何を記録するか

全部は入れない（本人が手間と感じる）。入れるのは、機器とつながる物・睡眠や体など計測データに効く物・毎日身につけて持ち歩く物。文房具・収納用品・消耗品は入れない。迷ったら本人に1行で聞く。

持っているか確かめていない購入履歴を `owned` で一括投入しない。台帳に無い物は「所持不明」で、`unknown` は作らない。

## キー

- Amazon: `amazon:<order_id>:<ASIN>`。開示データより新しい注文は先に `uv run --project ~/repo/dailybuild scripts/purchases.py fetch` で追いつかせ、`data/purchases/gmail.csv` の `asin` 列からキーを作る。`manual:N` で入れると開示データ取り込み後に二重になる。`amazon.csv` に無い行は join 先が無いので `name` を埋める
- メルカリ: `mercari:<item_id>`
- 店頭購入など: `manual:N`（既存の最大番号の次）。`note` に店名・価格・JAN

## 店頭購入の JAN

本人は Android の Binary Eye で読み、共有文面ごと貼る。ダイソー品は一般の Web 検索や在庫アプリでは名前が出ないので、文面をそのまま渡して引く:

```bash
uv run ~/repo/gtd/scripts/shopping/daiso.py '<共有文面か JAN>'
```

見つからなければパッケージの写真の名前で入れる。購入日は本人に聞く（深夜は「本日」が前日を指すことがある）。

## 列の語彙

- `status`: `owned` / `disposed` の2値。手放したら `disposed_on` と、手放し方を note に一言。売値は `mercari.csv` 等にあるので写さない。過去に売った物を遡って入れない
- 服・靴・小物の `subcategory`: Google 商品カテゴリ日本語版の名前（トップス / アウター / パンツ・ズボン / ショートパンツ / 下着・靴下 / スポーツウェア / 靴 / ハンドバッグ・財布 / ファッション小物）。例外として `メガネ` だけ自前。自転車のグローブはファッション小物、ジャージはスポーツウェア。サイズ・色は `uniqlo.csv` 等から join し写さない
