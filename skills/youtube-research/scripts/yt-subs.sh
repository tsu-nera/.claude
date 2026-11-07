#!/usr/bin/env bash
# 動画の字幕を取り、タイムスタンプと重複行を除いた本文を標準出力に出す。
# usage: yt-subs.sh URL [lang]   (lang 既定 ja。英語動画は en)
set -euo pipefail
url=${1:?usage: yt-subs.sh URL [lang]}
lang=${2:-ja}
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

uvx yt-dlp@latest --skip-download --write-subs --write-auto-subs \
  --sub-langs "${lang}-orig,${lang}" --sub-format vtt \
  --extractor-args 'youtube:lang=ja' \
  -o "$dir/%(id)s" "$url" >/dev/null 2>"$dir/err" || { cat "$dir/err" >&2; exit 1; }

vtt=$(ls "$dir"/*.vtt 2>/dev/null | head -1 || true)
if [[ -z $vtt ]]; then
  echo "字幕なし（lang=$lang）。--list-subs で言語を確認する" >&2
  exit 2
fi

grep -v -e '^$' -e '-->' -e '^WEBVTT' -e '^Kind:' -e '^Language:' "$vtt" \
  | sed 's/<[^>]*>//g' | awk 'NF && !seen[$0]++'
