# Zenn adapter

日本のエンジニア層。Qiita より個人開発・検証記事・書籍紹介の色が濃い。
「作ってみた／検証してみた」の在庫が厚く、株・投資系は定量検証ネタが拾える。

```bash
python3 ~/.claude/skills/research/scripts/zenn_search.py --topic 投資 --order alltime --limit 20
```

出力は JSONL（`source/title/url/author/published_at/engagement/bookmarks/letters/snippet`）。
`engagement` はいいね数、`bookmarks` はブックマーク数、`letters` は本文文字数。
`snippet` は常に空（API が本文を返さない）。0件なら stderr に警告（stdout 空、exit 0）。

## 引数

| 引数 | 意味 |
|---|---|
| `--topic` | トピック名（例 `投資` `トレード` `Python`）。省略で全体の新着 |
| `--username` | 投稿者で絞る |
| `--order` | `latest`(既定) / `daily` / `weekly` / `monthly` / `alltime` |
| `--limit` | 取得件数（既定 20） |
| `--min-likes` | いいね足切り（クライアント側） |
| `--max-pages` | 走査ページ上限（既定 5） |

## 落とし穴

- **非公式・非ドキュメント API**（`zenn.dev/api/articles`。Zenn フロントエンドの内部エンドポイント）。
  Qiita 公式 v2 と違い保証は無く、仕様変更で落ちうる。非JSONが返ったらスクリプトは黙って0件にせず exit する。
- **フリーワード全文検索は無い**。このエンドポイントはトピック絞り込みのみ。横断で漁るなら
  `トレード` `株式投資` `投資` `Python` `機械学習` 等のトピックを複数回叩いて url で dedup する。
- **本文は返らない**。眺める段は各 `url` を WebFetch する2段構え。
- 認証不要。レート制限は明文なし → 大量走査は `--max-pages` で抑える。

## order の使い分け（Qiita との最大の差）

Qiita は新着順固定で品質ソート不可だが、**Zenn は `--order alltime` でいいね降順が効く**。
定番記事だけ見たいなら `alltime`。トレンド追跡は `daily`/`weekly`。網羅は `latest` + `--min-likes`。
`alltime` を使えばクライアント側走査が要らないぶん Qiita の `stocks:>N` より素直。
