# LGTM - PRをマージしてブランチを削除する

ユーザーがPRをレビューしてOKと判断したため、マージしてブランチを削除する。

## 手順

1. **現在のPRを確認**
   - `gh pr list` で現在のPRを確認
   - 対象のPR番号を特定する（引数で指定された場合はそれを使う）

2. **CIの状態を確認**
   - `gh pr checks <PR番号>` でCIがpassしているか確認
   - failしている場合はユーザーに報告して中断する

3. **マージ**
   - `gh pr merge <PR番号> --merge --delete-branch` でマージ＆ブランチ削除
   - `--merge` はmerge commit方式（スカッシュしない）

4. **ローカルのクリーンアップ**
   - `git checkout main` でmainに戻る
   - `git pull` でmainを最新化
   - ローカルのブランチが残っていれば `git branch -d <ブランチ名>` で削除

5. **完了報告**
   - マージされたcommit hashとPR番号を報告する

## 注意事項
- CIがfailしている場合はマージしない
- PR番号が不明な場合は `gh pr list` で確認してユーザーに問い合わせる
