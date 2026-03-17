# Forget Command

完了したタスクの HANDOFF.md をアーカイブし、クリーンな状態にする。

## Instructions for Claude:

1. プロジェクトルートの HANDOFF.md が存在するか確認する
2. 存在しない場合は「HANDOFF.md が見つかりません」と伝えて終了
3. 存在する場合:
   - `.handoff-archive/` ディレクトリを作成（なければ）
   - HANDOFF.md を `.handoff-archive/HANDOFF-YYYY-MM-DD-HHMMSS.md` にコピー
   - `.handoff-archive/` が .gitignore に含まれているか確認し、なければ追加
   - プロジェクトルートの HANDOFF.md を削除
   - 「HANDOFF.md をアーカイブしました。新しいセッションを開始できます。」と伝える
