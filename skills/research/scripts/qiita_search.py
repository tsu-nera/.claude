#!/usr/bin/env python3
"""Qiita API v2 adapter. クエリを受けて正規化 JSONL を stdout に吐くだけ。

判断（クエリ構築・足切り・要約）は呼び出し側に残す。ここは transport のみ。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://qiita.com/api/v2/items"
UA = "claude-code-research-adapter/1.0"


def fetch(query: str, page: int, per_page: int, token: str | None) -> list[dict]:
    url = f"{API}?{urllib.parse.urlencode({'query': query, 'page': page, 'per_page': per_page})}"
    headers = {"User-Agent": UA, "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            ctype = res.headers.get("Content-Type", "")
            raw = res.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300]
        if e.code == 403:
            hint = " (レート制限か。未認証は 60req/h、QIITA_TOKEN 設定で 1000req/h)"
        else:
            hint = ""
        sys.exit(f"qiita: HTTP {e.code}{hint}: {body}")
    except urllib.error.URLError as e:
        sys.exit(f"qiita: 接続失敗: {e.reason}")

    # 非JSONが返ったら黙って0件にせず落とす
    if "application/json" not in ctype:
        sys.exit(f"qiita: 予期しない Content-Type: {ctype}: {raw[:200]}")
    return json.loads(raw)


def snippet(body: str, limit: int) -> str:
    # markdown のノイズを軽く落とすだけ。整形は呼び出し側の仕事
    text = re.sub(r"```.*?```", " ", body, flags=re.S)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[#>*`|_-]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:limit]


def normalize(item: dict, snippet_len: int) -> dict:
    return {
        "source": "qiita",
        "title": item.get("title", ""),
        "url": item.get("url", ""),
        "author": (item.get("user") or {}).get("id", ""),
        "published_at": item.get("created_at", ""),
        "engagement": item.get("likes_count", 0),
        "stocks": item.get("stocks_count", 0),
        "tags": [t.get("name", "") for t in item.get("tags") or []],
        "snippet": snippet(item.get("body") or "", snippet_len),
    }


def main() -> None:
    p = argparse.ArgumentParser(description="Qiita 記事検索 → JSONL")
    p.add_argument("--query", required=True, help="Qiita 検索クエリ (例: 'tag:polars created:>2025-01-01')")
    p.add_argument("--limit", type=int, default=20, help="取得件数 (default: 20)")
    p.add_argument("--min-likes", type=int, default=0, help="LGTM 数の足切り")
    p.add_argument("--snippet-len", type=int, default=300, help="本文抜粋の文字数 (0 で本文なし)")
    p.add_argument("--max-pages", type=int, default=5, help="走査するページ数の上限 (default: 5)")
    args = p.parse_args()

    token = os.environ.get("QIITA_TOKEN")
    # API は新着順固定で LGTM ソート不可。min-likes は取得しながら絞る
    per_page = 100 if args.min_likes else min(100, args.limit)
    hits = 0
    for page in range(1, args.max_pages + 1):
        batch = fetch(args.query, page, per_page, token)
        if not batch:
            break
        for item in batch:
            rec = normalize(item, args.snippet_len)
            if rec["engagement"] < args.min_likes:
                continue
            sys.stdout.write(json.dumps(rec, ensure_ascii=False) + "\n")
            hits += 1
            if hits >= args.limit:
                return
        if len(batch) < per_page:
            break
    if hits == 0:
        print(f"qiita: 0件 (query={args.query!r})", file=sys.stderr)


if __name__ == "__main__":
    main()
