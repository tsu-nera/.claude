---
skill: x-research
description: X/Twitterの投稿を検索・取得するリサーチスキル。障害調査、技術トレンド、サービス状況確認等に使用
user-invocable: true
allowed-tools: mcp__chrome-gui__navigate_page, mcp__chrome-gui__take_snapshot, mcp__chrome-gui__take_screenshot, WebSearch
---

# X/Twitter Research Skill

X/Twitterの投稿を検索・取得する。障害調査、技術情報収集、サービス状況確認などに利用。

## 制約

Claude CodeからX/Twitterを直接取得する方法は限定的:

| 方法 | 結果 |
|------|------|
| WebFetch (x.com) | 402エラー（ブロック） |
| WebFetch (nitter) | 403エラー or 空ページ |
| WebSearch | URL+スニペットは取れるが本文は不完全 |
| **Chrome GUI + nitter.net** | **動作する（推奨）** |

ヘッドレスモード（chrome-devtools）ではnitter.netが空ページを返すため、**GUIモード必須**。

## 手順

### Step 1: キーワード検索

```
mcp__chrome-gui__navigate_page(type="url", url="https://nitter.net/search?f=tweets&q=検索ワード")
```

複数ワードはスペースで連結（URLでは `+` に変換）:
- `https://nitter.net/search?f=tweets&q=conoha+vps`
- `https://nitter.net/search?f=tweets&q=solana+障害`

### Step 2: スナップショット取得

```
mcp__chrome-gui__take_snapshot()
```

投稿者名、日時、本文が全てテキストで取得できる。

### Step 3: 特定ユーザーの投稿を見る

```
mcp__chrome-gui__navigate_page(type="url", url="https://nitter.net/ユーザー名")
```

### Step 4: 特定投稿を見る

X URLからnitter URLに変換:
- `https://x.com/ConoHaPR/status/12345` → `https://nitter.net/ConoHaPR/status/12345`

```
mcp__chrome-gui__navigate_page(type="url", url="https://nitter.net/ユーザー名/status/投稿ID")
```

## 検索のコツ

- 日本語の障害情報: `サービス名 障害`
- 特定期間: nitter検索画面のTime rangeフィルタを使う
- 公式アカウント: 先に `nitter.net/公式アカウント名` で直接確認

## nitter.netが使えない場合のフォールバック

1. **WebSearch** で `site:x.com 検索ワード` — Googleインデックス経由でURLとスニペットは取れる
2. ユーザーに手動確認を依頼し、本文を貼ってもらう

## 注意事項

- nitter.netは非公式サービスのため、将来利用不可になる可能性がある
- GUIモードはWSLgが動作している環境が前提（`DISPLAY=:0`）
