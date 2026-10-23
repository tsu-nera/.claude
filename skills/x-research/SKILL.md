---
skill: x-research
description: X/Twitterの投稿を検索・取得するリサーチスキル。障害調査、技術トレンド、サービス状況確認等に使用
user-invocable: true
allowed-tools: Bash, WebSearch
---

# X/Twitter Research Skill

## 取得手段（2026-10-23 確認）

| 方法 | 結果 |
|------|------|
| WebFetch (x.com) | 402（ブロック） |
| agent-browser headless (x.com) | 403 |
| nitter.net | **閉鎖**（X 社の削除要請で告知ページのみ） |
| **WebSearch `site:x.com`** | URL+スニペット。検索はこれ |
| **`curl -s https://r.jina.ai/<x.com の投稿URL>`** | 投稿本文・日時・リプライが Markdown で取れる。個別投稿・ユーザーページはこれ |

## 手順

1. WebSearch で `site:x.com 検索ワード`（障害なら `サービス名 障害`、公式なら `site:x.com/公式アカウント名`）
2. 気になる投稿 URL を Jina Reader で読む:
   ```bash
   curl -s https://r.jina.ai/https://x.com/ユーザー名/status/投稿ID | head -60
   ```
3. どちらでも足りなければユーザーに本文を貼ってもらう
