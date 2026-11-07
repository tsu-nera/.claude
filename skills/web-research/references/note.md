# note adapter

技術者に限らない個人の実践記録・体験談・有料ノウハウ。Qiita/Zenn に無い「やってみた生活・商売・投資」の在庫が厚い反面、
宣伝・AI 生成の総論記事も多い。

```bash
python3 ~/.claude/skills/web-research/scripts/note_search.py 'Frigate ホームアシスタント' --limit 20
python3 ~/.claude/skills/web-research/scripts/note_search.py --key n10341b0ac32a   # 本文をテキストで
```

検索の出力は JSONL（`source/title/url/key/author/published_at/engagement/price/snippet`）。
`engagement` はスキ数、`price` は 0 なら無料。`snippet` は記事の description（空のことが多い）。
0件なら stderr に警告（stdout 空、exit 0）。

## 引数

| 引数 | 意味 |
|---|---|
| `query` | 検索語（全文検索。スペース区切りで AND に近い） |
| `--key` | 記事ID。URL `note.com/<user>/n/<key>` の `<key>`。本文を出す |
| `--sort` | `relevance`(既定) / `like`（スキ順） / `new` / `popular` |
| `--limit` / `--min-likes` / `--max-pages` | 件数・スキ足切り・走査ページ上限（1ページ20件） |

## 落とし穴

- **非公式・非ドキュメント API**（`note.com/api/v3/searches`・`/notes/<key>`）。非JSONなら exit する。
- **表記ゆれを広く拾う。** 「Frigate」で艦艇の「フリゲート」が混ざる。`--sort like` はこの混入が上位を占めやすい。
  まず `relevance` で引き、必要なら語を足して絞る
- **`--sort new` は検索語の効きが弱く**、ほぼ無関係の新着が混ざる。新しさが欲しければ `relevance` の結果を `published_at` で絞る
- **有料記事（`price` > 0）の本文は無料部分まで。** 結論が有料部分にある前提で、読めた範囲だけを根拠にする
- スキ数は少数で揺れる（数十あれば多い方）。品質の足切りに Zenn ほど効かない
