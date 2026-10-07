---
name: read-web
description: Web ページの中身を読む手順。WebFetch が空・骨組みだけ・「JS で描画されていて取れない」を返したとき、SPA や動画/SNS/EC ページの説明文・本文・数値を取りたいとき、ブラウザ（Playwright / Chrome DevTools MCP）を立ち上げる前に必ず参照すること。生 HTML の埋め込み JSON、Jina Reader、agent-browser CLI + eval の順に安い手段から試し、トークンを一桁節約する。
---

# Web ページを読む

安い手段から順に試し、取れた時点で止める。いきなりブラウザ MCP を使うと、1ページの
スナップショットだけで数万字を消費する。

## 手順

1. **WebFetch か `curl -sL -A 'Mozilla/5.0' URL` で生 HTML を取る。** 本文が出ればここで終わり
2. **出ない → 生 HTML の中の埋め込みデータを grep する。** JS 描画のサイトでも、初期データを
   HTML に同梱していることが多い。探す場所: `<script id="__NEXT_DATA__">`、`window.__NUXT__`、
   `application/ld+json`、`<meta property="og:*">`、サイト独自の `<meta name="...">` に入った JSON。
   WebFetch は要約モデルを通すので見落とす。grep するなら `curl` の出力に対して行う。
   `og:description` は途中で `...` に切られていることが多い。全文は JSON 側から取る
3. **無い → `curl -s https://r.jina.ai/URL`（Jina Reader）。** 描画済みページを Markdown で返す。
   URL が外部サービスに渡るので、私的・社内・ログイン後の URL には使わず 4 へ進む
4. **それでも足りない（折りたたみの中、クリック後に出る、無限スクロール）→ agent-browser**
5. **ログインが要るページ** は agent-browser の `--auto-connect`（起動中の Chrome の認証を流用）か
   `--profile Default`。bot 検出で空になるなら `--headed`

## agent-browser の流れ

```
agent-browser open URL
agent-browser snapshot -i -c          # 操作できる要素だけ。ref (@e12) を探す
agent-browser click @e12              # 返り値は "✓ Done" だけ。差分は出ない
agent-browser get text main           # 本文はここで読む
agent-browser eval 'JS式'             # 欲しい値だけを返す。最小コスト
agent-browser close
```

- **本文を `snapshot` で読まない。** `-c` は展開後も paragraph の中身を落とす。全体 snapshot は
  本文が載っても量が多い。snapshot は ref を探すため、文字は `get text` / `eval` で読む
- **`eval` が一番安い抽出手段。** ページ内の JSON（`JSON.parse(document.querySelector(...).content)`）、
  `fetch('/api/...')`（ログイン中の Cookie がそのまま乗る）を1行で返せる。セレクタは使い捨て
- **内部 API を割り出したいとき** は `agent-browser skills get derive-client`（通信を記録して API を逆算する同梱スキル）
- ブラウザはセッションとして常駐する。終わったら `close` する

## 残さないもの

このリポジトリは public。アクセスしたサイト名・URL・サイト別の取り方をこのスキルや
references に追記しない。ユーザーに明示的に頼まれたときだけ、`.gitignore` 済みの
ローカルファイルに書く。
