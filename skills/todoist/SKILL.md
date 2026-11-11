---
name: todoist
description: Todoist のタスクを td CLI で足す・移す・探す・完了する。「タスクにして」「タスク立てて」「Todoist に入れて」「Inbox を整理/振り分け」「〜のタスクある?」と言われた時、Issue や会話の宿題を Todoist に積む時に、どのリポジトリにいても使う。MCP（mcp__plugin_todoist_todoist__*）は使わない。
---

# Todoist（td CLI）

置き場所の決まりと、いつも使う書き方だけ置く。ここに無い操作は `td <cmd> --help` で引く（全コマンドの説明を読み込まない）。

## 構成

プロジェクト・セクション・ラベルは今後も変わる。名前をここや memory から決め打ちせず、置き先を決める前に引く:

```bash
td project list --json | jq -r '(.results // .)[] | .name'
td section list <プロジェクト名> --json | jq -r '(.results // .)[] | .name'
td label list --json | jq -r '(.results // .)[] | .name'
```

- プロジェクト = 領域（タスクは必ずどれか1つ）。新しいプロジェクトは本人が作る
- 同名セクションが別プロジェクトにありうるので、`--section` は必ず `--project` と組で指定する
- GTD のプロジェクトは親タスク＋サブタスク（`--parent`）。Todoist のプロジェクトにしない
- 習慣: セクション＝ルーチン、項目はセクション直下の毎日の繰り返しタスク（親タスク方式は却下済み）
- ラベルは2軸: 状態（例 `next`・`someday`・`waiting`）／場所（例 `自宅`・`外出`・`PC`、なし＝どこでも）。親に付け、サブタスクは場所が親と違うときだけ
- 買い物リストは Todoist ではなく Google Tasks（`gws tasks`）

## タスクを足す

1. 重複を見る。agent 経由だと別の会話で同じタスクを立てやすい:
   ```bash
   td task list --all --json | jq -r '(.results // .)[] | select(.content|test("語1|語2";"i")) | [.id,.content,(.sectionId//""),(.labels|join(","))] | @tsv'
   ```
2. Inbox に入れず、プロジェクト・セクション・ラベルまで決めて入れる（確認は取らない。事後に置き先を1行で伝える）。迷うものだけ Inbox に入れて理由を一言。前提になる既存タスクがあればその子にする:
   ```bash
   printf '%s\n' "$URL" "目的を1行" | td task add "名前" --project <プロジェクト名> --section <セクション名> --labels <ラベル> --stdin --json | jq -c '{id,content,sectionId,labels}'
   ```
   description は stdin で渡す（引数に複数行を詰めない）。チェックボックスはタスクにならないので普通の箇条書き。

## 移す・まとめて変える

```bash
td inbox --json --all | jq -r '.results[] | [.id,.content] | @tsv'
td task move id:<id> --project <プロジェクト名> --section <セクション名>   # --dry-run は名前解決を検証しない
td task view id:<id> --json | jq -c '{projectId,sectionId,labels}'   # 移動の確認はこちら（move --json は projectId が null で返る）
```

- 複数件はループで回し、終わったら一覧を取り直して数を確かめる
- `td task update --labels` は置き換え。足すときは今のラベルも並べる
- 書き換え前にタスクを読む。description は「今の状態と参照情報」で上書きしてよい。経過は日付つきコメント（`td comment add id:<id> --content ...`）で積み、完了時もコメントしてから `td task complete`
- 削除・アーカイブは ask 設定。本人の指示があるときだけ
- 検索は式を直接渡す: `td task list --filter '#<プロジェクト> & @<ラベル>' --json`
