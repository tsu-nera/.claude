---
name: sys-update
description: iiyama・vaio・mouse（Arch 系3台）の OS・パッケージ更新を、Arch news と AUR の PKGBUILD 差分を確認してから一括で当てる。「アップデートして」「週末の更新」「pacman -Syu」「パッケージ更新」「セキュリティ更新」「arch-audit」と言われた時、どれか1台だけの更新を頼まれた時も必ず使う。
---

# sys-update

実体は `~/repo/scripts/sys-update`（PATH 上）。iiyama から3台を扱う。mouse を起こす・更新中に寝かせない・fish を避けるのはスクリプトがやるので、手で ssh して `pacman` を叩かない。

## 流れ

1. `sys-update check` — 何も変えない。Arch news の新着と各台の更新候補
2. news に "manual intervention" や "requires" の告知があれば、リンク先を読む。対象パッケージが更新候補に入っていて手順が要るなら、apply の前にユーザーに提示して止まる
3. `sys-update apply` — 3台で並列に `pacman -Syu`。20分を超えることがあるので `run_in_background` で回す。ログは `~/.local/state/sys-update/<host>.log`
4. AUR: `sys-update aur-diff [host]` の差分を読み、問題がなければ `sys-update aur HOST PKG...`

## AUR の差分で疑うもの

2026-06 に AUR で悪意あるパッケージの事件があった。版番号とチェックサムの更新だけなら通す。次のどれかがあれば入れずに報告する:

- `source` のドメインが変わった、公式でない場所から落とす
- `.install` スクリプトの追加・変更、`curl | sh` や `pip install` のような実行時の取得
- チェックサムが `SKIP` になった、`package()` の中で `$HOME` や systemd unit をいじる

## 報告と再起動

- 失敗・`arch-audit -u` の残り・`.pacnew` を先に書く。`.pacnew` は差分を見せて統合案を出すだけで、勝手に上書きしない
- 再起動はしない。必要な台を伝える。iiyama は LUKS のパスフレーズ入力が要り（`soft-reboot` ではカーネルが替わらない）、vaio は Home Assistant が止まる
