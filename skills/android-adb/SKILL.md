---
name: android-adb
description: adb で Android スマホを操作・調査する時の落とし穴と手順。画面を読む・タップする・文字を入れる・アプリを起動する・設定や権限を変える・dumpsys や logcat で状態を調べる・ファイルを push する、など adb に触れる作業を始める前に必ず読むこと。画面は screencap の画像でなく uiautomator dump で読む。どのリポジトリにいても使う。
---

# Android を adb で扱う

端末の一覧と各端末の癖は `~/repo/agent-private/infra/phones.md`。adb を打つ前に読む。

## 画面を読む・触る

- 画面は `adb exec-out uiautomator dump /dev/tty` の text・resource-id・content-desc・bounds で判断し、タップ座標も bounds の中心から取る。`screencap` の画像は文脈に溜まり以後の毎ターン読み直すので、dump で中身が取れない画面（WebView・ゲーム・Canvas 描画）だけに使う
- dump は数万字になるので、そのまま読まず `scripts/ui.sh`（1行1要素に縮める・空振りを取り直す）で読む
- タップが効かない・違う画面が出る時は `dumpsys window | grep mCurrentFocus` を見る。メニュー（PopupWindow）が開いたままだと、その後のタップを全部吸う。通知シェードは HyperOS では dump できないことがあり、中身は `dumpsys notification --noredact` で読む
- 秘密値（パスワード・トークン・URL のパス）が出る画面の dump は、出力を sed で伏せてから読む
- `input text` は Gboard の自動修正・自動大文字化が効く（`tickr`→`ticker`、`json"`→`Jason"`）。単語の直後に記号を置かない。入れた後は dump で値を確かめる。Gboard が日本語かなだと `dumpsys` が `づMPsys` に化ける。`input keyevent KEYCODE_LANGUAGE_SWITCH` で英字に切り替わる
- 入力欄を打ち直すのは `input keycombination 113 29`（Ctrl+A）→ `KEYCODE_DEL`。`KEYCODE_MOVE_END` は行末までで、折り返した欄の途中を消す。空白は `%s`、記号を含む時は `adb shell "input text '...'"` と端末側でもクォートする
- ドラッグは `input draganddrop` も `motionevent` の長押し移動も効かないアプリがある。並べ替えは足して古い方を消す方が早い
- アプリ起動は `am start -n <pkg>/<activity>`。`monkey -p` は副アイコンの Activity を開くことがある

## 権限・接続

- `input tap`・`pm grant` が SecurityException（INJECT_EVENTS）なら、Xiaomi 系は「USB デバッグ（セキュリティ設定）」が要る。オンにする時だけ SIM＋モバイルデータが必要（Wi-Fi・VPN を切る）。一度オンにすれば SIM を抜いても再起動しても残る
- ワイヤレスデバッグはポートが再起動・ネットワーク変更で変わるので自動化に向かない。USB か、USB で `adb tcpip 5555` してから IP で繋ぐ（tcpip は再起動で消える）
- 端末の中のアプリに shell 権限を持たせたい時（再起動後も PC なしで）は Shizuku。ペアリングは設定のペア設定コードを Shizuku の通知の返信欄に入れる。アプリの許可は `pm grant <pkg> moe.shizuku.manager.permission.API_V23` だけでは足りず、Shizuku のアプリ管理画面でもオンにする
- adb が端末を拾わない時は `adb kill-server` してから起動し直す。非 root で `no permissions` は udev ルール（`android-udev`）と `adbusers` グループ
- `appops set` は再起動やアプリ側で元に戻ることがある。効かなければ設定画面を `am start -a android.settings...` で開いて操作する
- HyperOS は開発者オプションの「USB 経由でインストール」がオフだと `adb install` が `INSTALL_FAILED_USER_RESTRICTED` になる（`getprop persist.security.adbinstall` が無い＝オフ）。補助 APK を入れる道具（agent-device など）もここで止まる
- HyperOS は `pm disable-user` を拒否する。外すなら `pm uninstall -k --user 0`（戻すのは `cmd package install-existing`）

## 調べる

- アプリが止まった理由は `dumpsys activity exit-info <pkg>`（`LOW_MEMORY`・`USER REQUESTED / remove task` など）。強制停止状態は `dumpsys package <pkg> | grep -o 'stopped=[a-z]*'`
- 通知の中身は `dumpsys notification --noredact`
- アプリ別の使用時間は `dumpsys usagestats` しかない。イベントは前日 00:00 以降しか残らないので、当日〜翌日に取る
- BT 機器の残量は `dumpsys bluetooth_manager`（Fast Pair 対応イヤホンは左・右・ケースが metadata に載る）

## 触ると壊れるもの

- `cmd wifi connect-network` は保存済みのパスワードを上書きする。仮の値を渡さない。PSK を渡すと logcat の adbd 行に平文で残る（`adb logcat -c` で消し、出力を表示しない）
- `/sdcard/Android/data/<pkg>/` をアプリより先に adb で作るとアプリから読めなくなる（EACCES）。受け渡しは `/sdcard/Download/` 配下
