---
description: 作業を中断して別の機械か次のセッション、または別プロジェクトへ引き継ぐ（`/handoff take` で受け取る）
disable-model-invocation: true
argument-hint: "[take | <宛先プロジェクト>]"
---

# Handoff

引数: $ARGUMENTS

handoff は private な claude-memory repo で同期される（作業 repo が public でも、外に出せない文脈をそのまま書いてよい）。1プロジェクトに1ファイルで、別の handoff が溜まっていることがある。

## 引数 `take`: 受け取る

`memory-sync handoff-take` を実行する（sync して中身を出し、消費済みにする）。中身を2〜3行で伝え、ユーザーの指示を待ってから再開する。無ければそう伝えて終わる。

## 引数なし / `<宛先プロジェクト>`: 書き出す

宛先は引数なしなら今のプロジェクト。名前（`dailybuild` など）なら `~/repo/<名前>`、パスならそのまま。

1. 今のプロジェクトで作業中の worktree・ブランチごとに、未コミットの変更を WIP commit して push する（main には push しない）。push できないものは handoff に理由を書く。宛先側の repo には触らない
2. `memory-sync handoff-path [宛先パス]` のファイルに下の形で書く。**既存があれば上書きせず**、末尾に `---` で区切って追記する
3. `memory-sync` で即 push し、書いた内容を3行で報告する

```markdown
from: <host（`git -C ~/.claude/projects config user.name`）> <日時>（<元プロジェクト> から。別プロジェクト宛てのときのみ）

## 目標
## 済んだこと（確認したことはコマンドと結果つき）
## うまくいかなかった・やっていないこと
## 次にやること
## ブランチ・worktree・PR・Issue
## 機械に残っている状態（動かしたままのプロセス・サービス、変更した外部の設定、tmp の成果物など）
```

会話にしかない判断の経緯を優先して書く。git・Issue・memory から読めることは場所だけ書く。別プロジェクト宛てなら、なぜ向こうの領分なのかと、元プロジェクト側に残した記録の場所も書く。
