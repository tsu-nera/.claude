---
name: chrome-devtools-mcp
description: Chrome DevTools MCP の接続確認・トラブルシューティング（CachyOS / Wayland 環境）
user-invocable: true
allowed-tools: Bash
---

# Chrome DevTools MCP (CachyOS)

CachyOS にインストールした Chrome (`/usr/bin/google-chrome-stable`) を使い、ブラウザの操作・検査を行う。
2つのモードが登録されており、用途に応じて使い分ける。

## 2つのモード

| サーバー名 | モード | 用途 |
|---|---|---|
| `chrome-devtools` | ヘッドレス | 静的ページの検証、スクリーンショット取得 |
| `chrome-gui` | GUI 表示 (Wayland) | bot検出があるサイト、ユーザーが操作しながらデバッグ |

- ヘッドレス: ウィンドウなし。軽量だが、bot検出するサイト（nitter.net 等）では空ページになる
- GUI: Wayland セッション（`DISPLAY=:1` / `WAYLAND_DISPLAY=wayland-1`）にウィンドウが表示される。bot検出を回避でき、JSレンダリングも安定する
- **迷ったらGUI（chrome-gui）を使う** — ヘッドレスで空ページになるケースが多い

## ~/.claude.json 設定

`claude mcp add -s user` で登録するのが確実（このリポジトリの移行時はこれで再登録した）:

```bash
NPX=/home/tsu-nera/.asdf/shims/npx
claude mcp add chrome-devtools -s user -- $NPX -y chrome-devtools-mcp@latest --headless --isolated
claude mcp add chrome-gui      -s user -- $NPX -y chrome-devtools-mcp@latest --isolated
```

結果として `~/.claude.json` の `mcpServers` には以下が入る:

```json
{
  "chrome-devtools": {
    "type": "stdio",
    "command": "/home/tsu-nera/.asdf/shims/npx",
    "args": ["-y", "chrome-devtools-mcp@latest", "--headless", "--isolated"]
  },
  "chrome-gui": {
    "type": "stdio",
    "command": "/home/tsu-nera/.asdf/shims/npx",
    "args": ["-y", "chrome-devtools-mcp@latest", "--isolated"]
  }
}
```

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
- `take_snapshot` — **テキスト取得（推奨）**。a11yツリーからページ内の全テキスト・リンク・要素をuid付きで取得
- `take_screenshot` — 画像で画面確認。レイアウトや視覚的な確認に

3. 操作・デバッグ:
- `click(uid="...")` — snapshotで取得したuidで要素クリック
- `fill(uid="...", value="...")` — フォーム入力
- `evaluate_script` — JavaScript 実行・値取得
- `list_console_messages` — コンソールログ読取

### 利用可能なツール

各サーバーで同じツールが `mcp__chrome-devtools__*` / `mcp__chrome-gui__*` のプレフィックスで使える:

- `navigate_page` — URL遷移、リロード、戻る/進む
- `take_snapshot` — テキストスナップショット（a11yツリー）。uid付きで要素を特定できる
- `take_screenshot` — 画像スクリーンショット。視覚確認用
- `click` — snapshotのuidで要素クリック
- `fill` — snapshotのuidでフォーム入力
- `evaluate_script` — JavaScript 実行（値を返す）
- `list_console_messages` — コンソールログ一覧
- `list_network_requests` — ネットワークリクエスト一覧

## 実行手順（このスキルが呼ばれた時）

### Step 1: MCP ツールが使えるか確認

ToolSearch で `chrome-gui navigate` または `chrome-devtools take_screenshot` を検索。
見つかれば OK、見つからなければ Step 2 へ。

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

4. MCP サーバが登録されているか確認:
```bash
python3 -c "import json;print(list(json.load(open('$HOME/.claude.json')).get('mcpServers',{}).keys()))"
```
無ければ上記「~/.claude.json 設定」の `claude mcp add` を実行。

5. 上記が成功するなら Claude Code を再起動 (`/exit` → `claude`)

## 注意事項

- **Wayland 前提**: `DISPLAY=:1` と `WAYLAND_DISPLAY=wayland-1` が設定されていること（`echo $DISPLAY $WAYLAND_DISPLAY` で確認）
- **MCP のロードタイミング**: MCP サーバーは Claude Code 起動時にロードされる。設定変更後は再起動が必要
