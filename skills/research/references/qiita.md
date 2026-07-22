# Qiita adapter

日本の業務エンジニア層。実装手順・エラー解決・「詰まりどころ」の在庫が厚い。
評価や比較検討には向かない（宣伝記事・LLM生成記事が混ざる）。

```bash
python3 ~/.claude/skills/research/scripts/qiita_search.py --query '<query>' --limit 20
```

出力は JSONL（`source/title/url/author/published_at/engagement/stocks/tags/snippet`）。
`engagement` は LGTM 数。0件なら stderr に警告を出す（stdout は空、exit 0）。

## クエリ構文

スペース区切りは AND。`-` 前置で除外。

| 記法 | 例 |
|---|---|
| タグ | `tag:Polars` （複数は `tag:Python tag:polars`） |
| 本文・タイトル | `body:polars` / `title:polars` |
| 投稿者 | `user:kitao` |
| 期間 | `created:>2025-01-01` `created:<2026-01-01` |
| ストック数 | `stocks:>50` |
| 除外 | `-tag:初心者` |

## 落とし穴

- **結果は新着順固定。LGTM 順ソートはできない。** 品質で絞るなら必ずクエリ側に `stocks:>N` を入れる（サーバ側フィルタ）。`--min-likes` はクライアント側で新着から走査するだけなので、新しい記事ほど LGTM が育っておらず 0 件になりやすい。
- LGTM 数での検索絞り込みは API に無い。ストック数で代用する。
- 未認証は **60 req/h**。`QIITA_TOKEN` を環境変数に置くと 1000 req/h（Qiita の設定画面で read_qiita スコープの personal access token を発行）。403 が出たらまずこれを疑う。
- ページングは `page` 上限 100・`per_page` 上限 100。スクリプトは `--max-pages`（既定 5）で打ち切る。深掘りが要るならクエリを絞る方が先。

## 目安

`stocks:>10` で宣伝記事がかなり落ちる。定番記事だけ見たいなら `stocks:>100`。
新しい話題（1年以内）は母数が小さいので `stocks:>3` 程度まで下げる。
