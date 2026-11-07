---
name: youtube-research
description: YouTube の動画・チャンネルを調べる。キーワードで動画を検索する、チャンネルの概要・登録者数・動画一覧を見る、動画の字幕（文字起こし）を取って中身を読む・要約する。YouTube の URL が貼られて「この人は誰」「何を話している」「要約して」と聞かれたとき、「YouTube で〜を探して」「〜について話している動画」と言われたときに、WebFetch や生 HTML の grep より先に使う。
---

# YouTube を調べる

`uvx yt-dlp@latest` で引く。インストール不要・API キー不要。`@latest` は YouTube 側の変更で
古い版がすぐ壊れるため。

## コマンド

```
Y='uvx yt-dlp@latest --extractor-args youtube:lang=ja'

# 検索（上位 N 件）
$Y 'ytsearch20:キーワード' --flat-playlist -j 2>/dev/null | jq -r '[.id,.channel,(.duration|tostring),.title]|@tsv'

# 動画のメタ情報（チャンネル・登録者数・投稿日・再生数・概要欄）
$Y -j --skip-download URL 2>/dev/null | jq '{channel,channel_url,uploader_id,channel_follower_count,upload_date,view_count,description}'

# チャンネルの新しい順の動画一覧
$Y 'https://www.youtube.com/@handle/videos' --flat-playlist -I 1:30 -j 2>/dev/null | jq -r '[.id,(.view_count|tostring),.title]|@tsv'

# 字幕の本文（整形済み。英語動画は第2引数 en）
~/.claude/skills/youtube-research/scripts/yt-subs.sh URL [lang]
```

## 落とし穴

- `lang=ja` を付けないとタイトルが英語の自動翻訳で返る
- 自動字幕は固有名詞が崩れる（例: 「KitTwin」が「ヒットツイン／キットツイン」）。
  名前・数字は概要欄と突き合わせてから書く
- 字幕は1本 10 分で数千字。複数本を読むときは1本ずつ要点を抜いてから次へ
- 新着順の検索 `ytsearchdate:` は結果が空になる。新しさが要るなら検索結果をメタ情報の `upload_date` で絞る
- 字幕が無い動画は `yt-subs.sh` が exit 2。音声からの文字起こしは未整備
- 短時間に大量に引くとボット判定されうる。数本〜数十本の単位で使う
