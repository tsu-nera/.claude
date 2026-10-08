---
description: 作業を中断して別の機械か次のセッションへ引き継ぐ
disable-model-invocation: true
---

# Handoff

書き出し先は `memory-sync handoff-path`（private な claude-memory repo で同期され、次にこのプロジェクトで起動したセッションの SessionStart hook が1回だけ拾う）。作業 repo が public でも、外に出せない文脈をそのまま書いてよい。

1. 作業中の worktree・ブランチごとに、未コミットの変更を WIP commit して push する（main には push しない）。push できないものは handoff に理由を書く
2. 下の形で `memory-sync handoff-path` に書く（既存があれば上書き。1プロジェクト1つ）
3. `memory-sync` で即 push し、書いた内容を3行で報告する

```markdown
from: <host（`git -C ~/.claude/projects config user.name`）> <日時>

## 目標
## 済んだこと（確認したことはコマンドと結果つき）
## うまくいかなかった・やっていないこと
## 次にやること
## ブランチ・worktree・PR・Issue
## 機械に残っている状態（動かしたままのプロセス・サービス、変更した外部の設定、tmp の成果物など）
```

会話にしかない判断の経緯を優先して書く。git・Issue・memory から読めることは場所だけ書く。
