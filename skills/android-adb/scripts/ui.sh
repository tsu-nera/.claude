#!/bin/bash
# 画面の要素を1行1つ「text|content-desc|resource-id|c=clickable|bounds」で出す。text も desc も無い要素は省く。
# 端末は ANDROID_SERIAL で選ぶ。dump は「could not get idle state」で空になることがあるので3回まで取り直す。
# 秘密値が出る画面では、出力を sed で伏せてから読む。
for i in 1 2 3; do
  out=$(adb exec-out uiautomator dump /dev/tty 2>/dev/null)
  echo "$out" | grep -q '<node' && break
  sleep 1
done
echo "$out" | grep -o '<node [^>]*>' \
  | sed -E 's/.*text="([^"]*)".*resource-id="([^"]*)".*content-desc="([^"]*)".*clickable="([^"]*)".*bounds="([^"]*)".*/\1|\3|\2|c=\4|\5/' \
  | grep -v '^||'
