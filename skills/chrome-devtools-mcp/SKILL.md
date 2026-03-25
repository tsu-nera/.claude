---
name: chrome-devtools-mcp
description: Chrome DevTools MCP の接続確認・トラブルシューティング（WSL2環境）
user-invocable: true
allowed-tools: Bash
---

# Chrome DevTools MCP (WSL2)

WSL2 内にインストールした Chrome を使い、ブラウザの操作・検査を行う。
2つのモードが登録されており、用途に応じて使い分ける。

## 2つのモード

| サーバー名 | モード | 用途 |
|---|---|---|
| `chrome-devtools` | ヘッドレス | バックグラウンド検証、CI的な用途 |
| `chrome-gui` | WSLg GUI 表示 | ユーザーが操作しながらデバッグ |

- ヘッドレス: ウィンドウなし。`navigate_page` → `take_screenshot` で確認
- GUI: WSLg 経由でウィンドウが表示される。ユーザーが操作しつつ、Claude がログ確認・JS実行できる

## ~/.claude.json 設定

```json
{
  "chrome-devtools": {
    "type": "stdio",
    "command": "bash",
    "args": ["-c", "source ~/.nvm/nvm.sh && npx -y chrome-devtools-mcp@latest --headless --isolated"]
  },
  "chrome-gui": {
    "type": "stdio",
    "command": "bash",
    "args": ["-c", "source ~/.nvm/nvm.sh && npx -y chrome-devtools-mcp@latest --isolated"]
  }
}
```

### 設定の重要ポイント

- **`bash -c "source ~/.nvm/nvm.sh && ..."`**: system node (v20.18) では chrome-devtools-mcp が動かない。nvm の node (v23+) を使うためにラップが必要
- **`--isolated`**: 2つのサーバーがプロファイルを共有しないよう、一時ディレクトリを使用。これがないとプロファイルロックで片方が起動失敗する

## 使い方

### 基本的な流れ

1. HTTP サーバーを起動（ローカルファイル配信用）:
```bash
python3 -m http.server 8080 --directory /path/to/project &
```

2. ページを開く:
```
mcp__chrome-gui__navigate_page(url="http://localhost:8080/path/to/page.html")
```

3. 確認・デバッグ:
- `take_screenshot` — 画面確認
- `list_console_messages` — コンソールログ読取
- `evaluate_script` — JavaScript 実行・値取得
- `click` — 要素クリック

### 利用可能なツール

各サーバーで同じツールが `mcp__chrome-devtools__*` / `mcp__chrome-gui__*` のプレフィックスで使える:

- `navigate_page` — URL遷移、リロード、戻る/進む
- `take_screenshot` — スクリーンショット取得
- `evaluate_script` — JavaScript 実行（値を返す）
- `list_console_messages` — コンソールログ一覧
- `list_network_requests` — ネットワークリクエスト一覧
- `click` — 要素クリック
- `fill` — フォーム入力
- `take_snapshot` — DOM スナップショット

## 実行手順（このスキルが呼ばれた時）

### Step 1: MCP ツールが使えるか確認

ToolSearch で `chrome-gui navigate` または `chrome-devtools take_screenshot` を検索。
見つかれば OK、見つからなければ Step 2 へ。

### Step 2: トラブルシューティング

1. Chrome がインストールされているか確認:
```bash
google-chrome --version
```
未インストールなら:
```bash
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb
sudo dpkg -i /tmp/google-chrome.deb
sudo apt -f install -y
```

2. Node バージョン確認（v20.19+ が必要）:
```bash
bash -c "source ~/.nvm/nvm.sh && node --version"
```

3. 手動起動テスト:
```bash
bash -c "source ~/.nvm/nvm.sh && npx -y chrome-devtools-mcp@latest --help" 2>&1 | head -5
```

4. 上記が成功するなら Claude Code を再起動 (`/exit` → `claude`)

## 注意事項

- **GUI モードの音質**: WSLg 経由の音声は品質が劣る。音のデバッグには Windows Chrome を使うのが望ましい
- **WSLg の前提**: `DISPLAY=:0` と `WAYLAND_DISPLAY=wayland-0` が設定されていること（`echo $DISPLAY` で確認）
- **MCP のロードタイミング**: MCP サーバーは Claude Code 起動時にロードされる。設定変更後は再起動が必要
