---
name: chrome-devtools-mcp
description: Chrome DevTools MCP の接続確認・トラブルシューティング（CachyOS / Wayland 環境）
user-invocable: true
allowed-tools: Bash
---

# Chrome DevTools MCP (CachyOS)

CachyOS にインストールした Chrome (`/usr/bin/google-chrome-stable`) を使い、ブラウザの操作・検査を行う。

ページの中身を読む・操作するだけなら `read-web`（agent-browser CLI）を先に使う。この MCP は
コンソール・ネットワーク・performance trace など DevTools 固有の機能が要るとき用。

## 登録は使うプロジェクトの local scope だけ

**user scope（global）に登録しない。** MCP は全セッションで常駐し、npx 経由の node が
1サーバあたり約3プロセス・数百MB 増える（2026-10-23、4サーバ×11セッションで swap 6.6G を占有していた）。
スキルから呼んでも未登録のセッションには MCP ツールが存在しない。

```bash
NPX=/home/tsu-nera/.asdf/shims/npx
cd <プロジェクト>
claude mcp add chrome-gui      -s local -- $NPX -y chrome-devtools-mcp@latest --isolated             # GUI 表示
claude mcp add chrome-devtools -s local -- $NPX -y chrome-devtools-mcp@latest --headless --isolated  # ヘッドレス
```

- ヘッドレスは bot 検出サイトで空ページになりやすい。迷ったら GUI
- 登録済みプロジェクトは `jq '.projects|map_values(.mcpServers|keys?)' ~/.claude.json` で一覧。local scope はパス単位なので git worktree には効かない

### 設定の重要ポイント

- **node は asdf の v22.16.0**（PATH 上の `~/.asdf/shims/npx`）。chrome-devtools-mcp は v22.16 で動作確認済み。旧 WSL2 環境の `bash -c "source ~/.nvm/nvm.sh && ..."` ラッパーは **不要**（nvm は無い）
- **`--isolated`**: 2つのサーバーがプロファイルを共有しないよう、一時ディレクトリを使用。これがないとプロファイルロックで片方が起動失敗する

## 使い方

### 基本的な流れ

1. ページを開く:

外部サイト:
```
mcp__chrome-gui__navigate_page(type="url", url="https://example.com")
```

ローカルファイル（HTTPサーバー経由）:
```bash
python3 -m http.server 8080 --directory /path/to/project &
```
```
mcp__chrome-gui__navigate_page(type="url", url="http://localhost:8080/page.html")
```

2. コンテンツを取得:
- `take_snapshot` — 要素の uid を探すため。1ページで数万字になるので本文読みには使わず、文字は `evaluate_script` で必要な値だけ返す
- `take_screenshot` — 画像で画面確認。レイアウトや視覚的な確認に

3. 操作・デバッグ:
- `click(uid="...")` — snapshotで取得したuidで要素クリック
- `fill(uid="...", value="...")` — フォーム入力
- `evaluate_script` — JavaScript 実行・値取得
- `list_console_messages` — コンソールログ読取

## 実行手順（このスキルが呼ばれた時）

### Step 1: MCP ツールが使えるか確認

ToolSearch で `chrome-gui navigate` を検索。見つからなければ、まずこのプロジェクトに登録されているか `claude mcp list` で確認（未登録なら上の `claude mcp add -s local`）。登録済みで失敗するなら Step 2 へ。

### Step 2: トラブルシューティング

1. Chrome がインストールされているか確認:
```bash
google-chrome-stable --version
```
未インストールなら CachyOS では AUR から:
```bash
paru -S google-chrome   # or: yay -S google-chrome
```

2. Node バージョン確認（v20.19+ が必要、現状 asdf の v22.16.0）:
```bash
node --version
```

3. 手動起動テスト:
```bash
/home/tsu-nera/.asdf/shims/npx -y chrome-devtools-mcp@latest --help 2>&1 | head -5
```

4. 上記が成功するなら Claude Code を再起動 (`/exit` → `claude`)

### "Failed to connect" の頻出原因: npx cache の bin に実行権限が無い

`claude mcp list` で chrome-devtools/chrome-gui が `✘ Failed to connect`、手動起動で
`.../node_modules/.bin/chrome-devtools-mcp: 許可がありません` (permission denied) が出る場合、
npx cache 内の本体 JS に +x が付いていない（公開 tarball の bin が non-exec で展開される）。
shebang 実行できず接続失敗する。fix:

```bash
chmod +x ~/.npm/_npx/*/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js
```

修正後は Claude Code 再起動が必要（MCP は起動時のみ接続を試みる）。

## 注意事項

- **Wayland 前提**: `DISPLAY=:1` と `WAYLAND_DISPLAY=wayland-1` が設定されていること（`echo $DISPLAY $WAYLAND_DISPLAY` で確認）
- **MCP のロードタイミング**: MCP サーバーは Claude Code 起動時にロードされる。設定変更後は再起動が必要
