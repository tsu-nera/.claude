---
name: linux-gui
description: このPC（CachyOS / niri Wayland）のデスクトップアプリを agent が操作・確認する手順。ネイティブアプリのボタンを押す、設定画面を変える、ウィンドウの中身を見る、キー入力やクリックを送る、画面を撮る、など GUI に触れる必要が出たら、スクショや座標クリックを試す前に必ず参照すること。ブラウザ内のページ操作だけなら chrome-devtools-mcp / read-web を使う。
---

# Linux GUI 操作（niri / Wayland）

## 手段の優先順位

上で済むなら下に降りない。下ほどトークンを食い、壊れやすい。

1. **GUI を避ける**: 設定ファイル・CLI・D-Bus・`gsettings`・`noctalia msg` で済まないか先に考える
2. **ブラウザ / Electron は CDP**: chrome-gui MCP の `take_snapshot`。Electron は `--remote-debugging-port=9222` で起動すれば同じ
3. **ウィンドウ把握は niri IPC**: `niri msg -j windows`（id・pid・app_id・title）、`niri msg action focus-window --id N`
4. **ネイティブアプリは AT-SPI**: `scripts/a11y.py`（`-h` で使い方）。`tree` → `find` → `do PATH` で名前ベースに押す。対象は既定でフォーカス中ウィンドウの pid
5. **最後の手段**: スクショ + `dotool` でキー/マウス

## 落とし穴

- **文字入力は IME を切ってから wtype**: 入力欄にフォーカスした後 `fcitx5-remote -c && wtype 'テキスト'`（日本語も可）。IME が有効なままだと英字が変換に巻き込まれ順序まで崩れる（`abc テスト-1` → `テストあbc－１`）。wtype で通らない欄は `printf '%s' "$TEXT" | wl-copy` → `echo 'key ctrl+v' | dotool` で貼る。AT-SPI の `a11y.py text` が通る要素ならそれが最良
- **dotool**: `DOTOOL_XKB_LAYOUT=jp` を付ける（JIS 配列）。キー名は Linux 名（`leftshift`, `enter`, `ctrl+s`）。`mouseto` は画面全体に対する 0.0〜1.0 の割合。permission denied なら input グループ未反映なので `sudo DOTOOL_XKB_LAYOUT=jp dotool`
- **座標クリックは避ける**: niri はスクロール型レイアウトでウィンドウ位置が動く。ショートカットキーか AT-SPI の `do` を使う
- **スクショはウィンドウ単位**: `niri msg action screenshot-window --id N --path /絶対パス.png`（全画面の 1/20 程度）。**これはクリップボードを上書きする**ので、wl-copy はスクショの後にやり直す
- **GTK4 の制約**: `grabFocus` は常に拒否、entry は EditableText 非対応で入力済み文字もツリーに出ない。フォーカスは `do` でクリックか Tab、入力は貼り付け、結果確認はスクショ
- **AT-SPI のパスは揮発**: 画面が変わったら `tree`/`find` を取り直す。アプリが `apps` に出ないなら Electron（`--force-renderer-accessibility`）か独自描画（5段目へ）
- **SSH 越し**（vaio → iiyama 等）: `XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1` を付けないと niri/wl-copy/AT-SPI に届かない
- **computer-use-linux プラグインは無効化中**（v0.7.22、2026-10-21 評価）: niri では click が操作後に応答を返さず固まり、screenshot も niri の `org.gnome.Shell.Screenshot` が応答せず固まる。`get_app_state` は a11y.py の約7倍の出力。再評価するなら新版で click とスクショが返るかを先に見る
- 操作で開いたウィンドウは終わったら `niri msg action close-window --id N` で閉じる。ユーザーの作業中ウィンドウからフォーカスを奪ったら戻す

## 足りない道具の記録（gaps）

次のどれかに当たったら、作業は完遂したうえで `~/.claude/skills/linux-gui/gaps.md` に1行追記する。

- 5段目（スクショ + 座標/キー）に頼った
- 使い捨てスクリプトを書いた
- 同じ操作列を3回以上繰り返した

書式: `- YYYY-MM-DD <アプリ>: やりたかったこと / 実際にやった代替 / あれば欲しい道具`

ツール化はその場でせず、gaps が溜まってからユーザーと判断する。
