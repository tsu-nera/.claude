#!/usr/bin/env python3
"""note 記事 adapter. 検索結果を正規化 JSONL で、--key なら本文をテキストで stdout に吐く。

判断（クエリ選定・足切り・要約）は呼び出し側に残す。ここは transport のみ。
note の内部エンドポイント（非公式・非ドキュメント）を叩く。
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://note.com/api/v3"
UA = "Mozilla/5.0 (claude-code-research-adapter/1.0)"
SORTS = ("relevance", "new", "like", "popular")
PAGE = 20


def fetch(path: str, params: dict | None = None) -> dict:
    url = f"{BASE}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            ctype = res.headers.get("Content-Type", "")
            raw = res.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300]
        sys.exit(f"note: HTTP {e.code}: {body}")
    except urllib.error.URLError as e:
        sys.exit(f"note: 接続失敗: {e.reason}")
    # 非JSONが返ったら黙って0件にせず落とす（内部APIの仕様変更検知）
    if "application/json" not in ctype:
        sys.exit(f"note: 予期しない Content-Type: {ctype}: {raw[:200]}")
    return json.loads(raw)


def normalize(item: dict) -> dict:
    user = (item.get("user") or {}).get("urlname", "")
    key = item.get("key", "")
    return {
        "source": "note",
        "title": item.get("name", ""),
        "url": f"https://note.com/{user}/n/{key}" if user and key else "",
        "key": key,
        "author": user,
        "published_at": item.get("publish_at", ""),
        "engagement": item.get("like_count", 0),
        "price": item.get("price", 0),
        "snippet": (item.get("description") or "")[:200],
    }


def html_to_text(body: str) -> str:
    body = re.sub(r"<br\s*/?>", "\n", body)
    body = re.sub(r"</(p|h[1-6]|li|pre|blockquote|figure)>", "\n", body)
    body = re.sub(r"<[^>]+>", "", body)
    return re.sub(r"\n{3,}", "\n\n", html.unescape(body)).strip()


def show(key: str) -> None:
    d = fetch(f"/notes/{key}").get("data") or {}
    user = d.get("user") or {}
    print(f"# {d.get('name', '')}")
    print(f"author: {user.get('nickname', '')} (@{user.get('urlname', '')})")
    print(f"published_at: {d.get('publish_at', '')}  likes: {d.get('like_count', 0)}  price: {d.get('price', 0)}")
    if d.get("price"):
        print("※ 有料記事。本文は無料部分まで")
    print()
    print(html_to_text(d.get("body") or ""))


def search(args: argparse.Namespace) -> None:
    hits = 0
    for start in range(0, args.max_pages * PAGE, PAGE):
        params = {"context": "note", "q": args.query, "size": PAGE, "start": start}
        if args.sort != "relevance":
            params["sort"] = args.sort
        notes = (fetch("/searches", params).get("data") or {}).get("notes") or {}
        batch = notes.get("contents") or []
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
        if notes.get("is_last_page"):
            break
    if hits == 0:
        print(f"note: 0件 (q={args.query!r} sort={args.sort})", file=sys.stderr)


def main() -> None:
    p = argparse.ArgumentParser(description="note 検索 → JSONL / 本文 → テキスト")
    p.add_argument("query", nargs="?", help="検索語")
    p.add_argument("--key", help="記事ID (URL の /n/ の後ろ)。指定すると本文を出す")
    p.add_argument("--sort", default="relevance", choices=SORTS, help="並び (default: relevance)")
    p.add_argument("--limit", type=int, default=20, help="取得件数 (default: 20)")
    p.add_argument("--min-likes", type=int, default=0, help="スキ数の足切り (クライアント側)")
    p.add_argument("--max-pages", type=int, default=5, help="走査するページ数の上限 (default: 5)")
    args = p.parse_args()

    if args.key:
        show(args.key)
    elif args.query:
        search(args)
    else:
        p.error("検索語か --key が要る")


if __name__ == "__main__":
    main()
