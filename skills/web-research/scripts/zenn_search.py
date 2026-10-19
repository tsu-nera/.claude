#!/usr/bin/env python3
"""Zenn 記事一覧 adapter. トピック/並びを受けて正規化 JSONL を stdout に吐くだけ。

判断（トピック選定・足切り・要約）は呼び出し側に残す。ここは transport のみ。
Zenn の内部エンドポイント（非公式・非ドキュメント）を叩く。本文は返らない。
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://zenn.dev/api/articles"
UA = "claude-code-research-adapter/1.0"
ORDERS = ("latest", "daily", "weekly", "monthly", "alltime")


def fetch(params: dict, page: int) -> dict:
    q = {k: v for k, v in params.items() if v is not None}
    q["page"] = page
    url = f"{API}?{urllib.parse.urlencode(q)}"
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            ctype = res.headers.get("Content-Type", "")
            raw = res.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300]
        sys.exit(f"zenn: HTTP {e.code}: {body}")
    except urllib.error.URLError as e:
        sys.exit(f"zenn: 接続失敗: {e.reason}")
    # 非JSONが返ったら黙って0件にせず落とす（内部APIの仕様変更検知）
    if "application/json" not in ctype:
        sys.exit(f"zenn: 予期しない Content-Type: {ctype}: {raw[:200]}")
    return json.loads(raw)


def normalize(item: dict) -> dict:
    path = item.get("path", "")
    return {
        "source": "zenn",
        "title": item.get("title", ""),
        "url": f"https://zenn.dev{path}" if path else "",
        "author": (item.get("user") or {}).get("username", ""),
        "published_at": item.get("published_at", ""),
        "engagement": item.get("liked_count", 0),
        "bookmarks": item.get("bookmarked_count", 0),
        "letters": item.get("body_letters_count", 0),
        # API は本文を返さない。眺める段は url を WebFetch する
        "snippet": "",
    }


def main() -> None:
    p = argparse.ArgumentParser(description="Zenn 記事一覧 → JSONL")
    p.add_argument("--topic", help="トピック名 (例: 投資 / トレード)。省略で全体")
    p.add_argument("--username", help="投稿者で絞る (username)")
    p.add_argument("--order", default="latest", choices=ORDERS, help="並び (default: latest。alltime でいいね降順)")
    p.add_argument("--limit", type=int, default=20, help="取得件数 (default: 20)")
    p.add_argument("--min-likes", type=int, default=0, help="いいね数の足切り (クライアント側)")
    p.add_argument("--max-pages", type=int, default=5, help="走査するページ数の上限 (default: 5)")
    args = p.parse_args()

    params = {
        "topicname": args.topic,
        "username": args.username,
        "order": args.order,
        "count": min(100, args.limit) if not args.min_likes else 100,
    }
    hits = 0
    page: int | None = 1
    for _ in range(args.max_pages):
        if page is None:
            break
        data = fetch(params, page)
        batch = data.get("articles") or []
        if not batch:
            break
        for item in batch:
            rec = normalize(item)
            if rec["engagement"] < args.min_likes:
                continue
            sys.stdout.write(json.dumps(rec, ensure_ascii=False) + "\n")
            hits += 1
            if hits >= args.limit:
                return
        page = data.get("next_page")
    if hits == 0:
        print(f"zenn: 0件 (topic={args.topic!r} order={args.order})", file=sys.stderr)


if __name__ == "__main__":
    main()
