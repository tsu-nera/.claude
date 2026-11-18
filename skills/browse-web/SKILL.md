---
name: browse-web
description: Web ページを読む・操作するときの手段の選び方と、安い順の読み方。WebFetch が空・骨組みだけ・「JS で描画されていて取れない」を返したとき、SPA や動画/SNS/EC ページの説明文・本文・数値を取りたいとき、ログイン後の画面を読む・操作する（削除・アップロード・フォーム）とき、ブラウザ（Playwright / Chrome DevTools MCP / Claude in Chrome）を立ち上げる前に必ず参照すること。
---

# Web ページを読む・操作する

## 手段の選び方（上から順に当てはめ、最初に合ったものを使う）

| 優先 | 条件 | 手段 |
|---|---|---|
| 1 | 公式 API・export がある | それを使う。ブラウザを開かない |
| 2 | ログイン不要で、読むだけ | 下の「読む手順」（curl → 埋め込み JSON → Jina → agent-browser） |
| 3 | 同じ取得を定期的に無人で回す | リポジトリに Playwright のスクリプトを書き、セッションをファイルに保存する |
| 4 | ログイン後の画面を、本人がそばにいるときに読む・操作する | Claude in Chrome（`mcp__claude-in-chrome__*`） |
| 5 | ログイン後の画面を、本人不在で一回だけ読む・操作する | chrome-gui（`chrome-devtools-mcp` スキル、`~/.cache/chrome-agent`）。ログインは本人が先に済ませておく |
| 6 | コンソール・通信・性能を見る（自分のアプリの調査） | chrome-devtools-mcp |
| 7 | ブラウザの外のアプリ | `linux-gui` スキル |

- 4 と 5 の違いは隔離。Claude in Chrome は本人の普段のプロファイルなので全ログインに手が届き、
  chrome-gui の「銀行・取引所にログインしない」が効かない。本人不在で 4 を使わない。最後の確定ボタンは本人に確かめてから押す
- 4 か 5 を2回やったら 3（スクリプト）にできないか考える

## 読む手順

安い手段から順に試し、取れた時点で止める。いきなりブラウザ MCP を使うと、1ページの
スナップショットだけで数万字を消費する。

1. **WebFetch か `curl -sL -A 'Mozilla/5.0' URL` で生 HTML を取る。** 本文が出ればここで終わり
2. **出ない → 生 HTML の中の埋め込みデータを grep する。** JS 描画のサイトでも、初期データを
   HTML に同梱していることが多い。探す場所: `<script id="__NEXT_DATA__">`、`window.__NUXT__`、
   `application/ld+json`、`<meta property="og:*">`、サイト独自の `<meta name="...">` に入った JSON。
   WebFetch は要約モデルを通すので見落とす。grep するなら `curl` の出力に対して行う。
   `og:description` は途中で `...` に切られていることが多い。全文は JSON 側から取る
3. **無い → `curl -s https://r.jina.ai/URL`（Jina Reader）。** 描画済みページを Markdown で返す。
   URL が外部サービスに渡るので、私的・社内・ログイン後の URL には使わない
4. **それでも足りない（折りたたみの中、クリック後に出る、無限スクロール）→ agent-browser。**
   bot 検出で空になるなら `--headed`

## Claude in Chrome の落とし穴

- 全サイトが `This site is blocked by your site permissions` になる原因は、claude.ai → Settings →
  Browser extension のサイト設定（拡張機能の approved sites や chrome://extensions ではない）。
  変えた後は Chrome の再起動まで効かない。iiyama は起動時に前のタブを復元しない設定なので、
  `--restore-last-session` を付けて起動し直す。拡張機能がつながり直すまで30秒ほどかかる
- `computer type` で日本語が入らない。`form_input` で値を入れ、`javascript_tool` で読み返す
- `confirm()` が出ると拡張機能が止まる。押す前に `window.confirm = () => true` で上書きする
- `file_upload` は scratchpad のファイルも渡せる

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
