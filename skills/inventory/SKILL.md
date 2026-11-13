---
name: inventory
description: 持ち物の台帳（正本は vaio の Homebox、写しは dailybuild-private の items.csv）に物を足す・手放した印を付ける・持っているか引く。「〜を買った」「所持品に登録して」「これ持ってたっけ」「〜を売った/捨てた」「〜を補充した」「前いつ買った」と言われた時、Binary Eye の共有文面（markusfisch.de の URL と JAN）や Homebox の物の URL（`:3100/item/<uuid>`）が貼られた時に、どのリポジトリにいても使う。買う前の下調べは gtd の shopping。
---

# inventory

正本は vaio の Homebox（`http://100.93.3.10:3100`。本人は UI で直接直す）。`data/inventory/items.csv` は Homebox から書き出す生成物なので**直接書かない**。書き込みは dailybuild の CLI 経由:

```bash
cd ~/repo/dailybuild
uv run scripts/homebox.py add <key> --category <カテゴリ> [--subcategory ..] [--name ..] [--acquired-on YYYY-MM-DD] [--note ..]
uv run scripts/homebox.py add manual --name '<品名>' --category <カテゴリ> --acquired-on <日付> --price <円> --from '<店名>' [--note '<JAN 等>']
uv run scripts/homebox.py market <key> <円> --source 'メルカリ SOLD（直近90日 N件）中央値'   # 任意。最新値を custom field、履歴をメモ末尾へ
uv run scripts/homebox.py dispose <key> --date YYYY-MM-DD --how '<粗大ごみ等>'
uv run scripts/homebox.py dispose <key> --mercari <item_id>   # メルカリで売った物。日付・売値は mercari.csv から（無ければ先に purchases.py fetch-mercari）
uv run scripts/homebox.py plan <key> 売却|破棄   # 手放すと決めた印（メンテナンス記録、予定日＝決めた日）。dispose が完了日で閉じる
uv run scripts/homebox.py move <key> <場所>   # 末端の名前（靴箱）か経路（玄関・キッチン / 靴箱）
uv run scripts/homebox.py find [語] [--location ..] [--tag ..] [--all]   # Homebox を直接引く
```

add / dispose / move は最後に items.csv まで書き出す。場所の名前が曖昧・不在なら止まるので、出てきた候補から選ぶ（場所を勝手に作らない。増やすのは本人）。書き出した items.csv は dailybuild-private に commit して push する（日次の自動 commit と競るので、弾かれたら `git pull --rebase`）。品名・購入日・価格・購入先と商品ページのリンク（Amazon・楽天・メルカリ。開けるときだけ）は key から `data/purchases/` を引いて埋まる。ユニクロ・店頭の商品ページは分かれば `--url` で渡す。写真は本人が UI で付ける。

Homebox の URL（`.../item/<uuid>`）が貼られたら、その uuid を `src/lib/clients/homebox_client.py` の `get_entity` / `entity_path` で引く（`find` は id を受けない。旧 `/api/v1/items` は 404）。

## 何を記録するか

全部は入れない（本人が手間と感じる）。入れるのは、機器とつながる物・睡眠や体など計測データに効く物・毎日身につけて持ち歩く物。文房具・収納用品・消耗品は入れない。迷ったら本人に1行で聞く。

## 消耗品・購入履歴

- 消耗品（補充する物）は Homebox に入れず `dailybuild-private/data/inventory/consumables.csv` 側。設計は試行中なので、書く前に dailybuild `docs/inventory.md` を読む。品目を足すのは `ssh vaio 'cd ~/repo/dailybuild && uv run scripts/consumables.py add <key> --name .. --category .. --unit ..'` の1回（pull・追記・画面の CSV 作り直し・commit・push まで）。Grafana は vaio の CSV を読むので、手元で書いても画面に出ない
- 週1の棚卸し（本人がチャットで言った残量）は vaio で1回叩く。量は品目の `unit`（kg の品目は重さに換算）、その日の終わりの量。CLI はまだ作らない（器が試行中）:
  ```bash
  ssh vaio 'cd ~/repo/dailybuild-private && git pull -q && printf "%s\n" "YYYY-MM-DD,<key>,<量>,<メモ>" "YYYY-MM-DD,<key>,<量>," >> data/inventory/stocktake.csv && cd ~/repo/dailybuild && uv run scripts/dashboard.py build --only consumables && cd ~/repo/dailybuild-private && git commit -qm "stocktake: YYYY-MM-DD" data/inventory/stocktake.csv && git push -q'
  ```
  メモにカンマを入れない（列がずれる）
- 何を買ったかは `dailybuild-private/data/purchases/<店>.csv` を引く（Gmail を探さない）

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
- 中古相場は実験中（2026-11-12〜）の任意項目。全部には入れず、本人が頼んだ物と手放す候補だけ `market` で入れる（相場は gtd の `scripts/shopping/price.py '<型番>' --min <下限>` の SOLD 中央値）。メンテナンス記録は「売却」「破棄」の予定（plan）だけに使う。期日は Todoist が持ち、売値は費用欄でなく dispose が売却欄へ入れる
