---
name: create-issue
description: 会話で決めた内容からGitHub Issueを作成する。「イシューをあげて」「issueにして」で起動。
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash(gh *), Read, Grep, Glob
---

# Issue作成スキル

会話コンテキストからGitHub Issueを作成する。

**このスキルの目的: `/issue-to-pr`（または codex の issue-to-pr）がそのまま自走できる粒度・format で Issue を作る。**
作成した Issue は下流で「高品質（一気通貫で進む）」と判定され、人間への差し戻しが発生しないことをゴールとする。

## 設計の丁寧さ: 最も context が乏しい実装者に合わせる

同じ Issue が2経路で実装され、前提が大きく違う。**作成時点でどちらか確定しないことが多いので、乏しい側（codex 直接）を基準に書く。**

- **Claude `/issue-to-pr`**: 同セッションの会話を持ち、Phase 2/3 で再調査・再設計する。Issue 設計はアンカーで、過不足は Phase 3.5 で自己補正される。
- **codex CLI を Issue に直接当てる**: **Issue が唯一の入力**。会話なし・再設計なし・規約知識が弱い。設計の過不足はそのまま drift する。
  （注: `issue-to-pr --codex` 経由なら Claude が再設計した方針を codex に渡すのでこのケースに当たらない。該当するのは codex を Issue へ直接当てる運用のみ）

書き分けの基準:
- **常に厚く**: WHAT / WHY / 制約 / Acceptance Criteria / 変更対象ファイル（具体パス） / 方針（アプローチレベル — どの既存パターン・ユーティリティに寄せるか）。
- **書きすぎ厳禁**: 確信のない行レベルのコードスケッチ。codex は Issue を literally 追うため、誤ったコード例は「例なし」より有害。**確定した判断だけ書き、推測コードは書かない。**

なお、コーディング規約（コメント英語・`Number` 禁止 等）は Issue 本文に書かない。実装側（Claude / codex）がそれぞれ自分の環境で規約を保持する前提とする。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- `--repo=owner/repo`: リポジトリ（省略時は現在のリポジトリ）
- `--label=<label>`: ラベル（省略時はなし、複数指定可）
- それ以外のテキスト: Issueの内容に関する補足

リポジトリが省略された場合:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## コンテキスト

- 変更ファイル: !`git diff --name-only`
- 最近のコミット: !`git log --oneline -5`

## 実行手順

### Step 1: 変更対象の特定

会話で変更対象ファイルが具体的に特定済みなら、それを使う。
**未特定なら `Grep`/`Glob`/`Read` でコードベースを探索し、具体的なパスまで落とし込む。**
（曖昧な「変更対象」欄は下流で低品質判定 → 調査やり直しの原因になる。ここで前倒しする）

### Step 2: スコープ判定（1 PR で完結するか）

`issue-to-pr` は「独立して merge・レビューできる成果物が複数に分かれる規模」を `SPLIT_NEEDED` として人間に差し戻す。
**それを未然に防ぐため、Issue 作成前にスコープを判定する。**

- **1 PR で完結する規模** → Step 3 へ。
- **複数 PR に割るべき規模** → 単一 Issue を作らず、分割を提案する:
  - 親子関係が要るなら `create-subissue` を案内
  - 1つの大きな塊を割るなら `split-issue` を案内
  - どう割るか（境界）の案を添えてユーザーに確認する。

### Step 3: Issue内容の生成

会話の流れと Step 1 の探索結果から生成する。
**format は `issue-to-pr` の品質判定3軸（変更ファイルの具体列挙 / Acceptance Criteria / 設計方針）に1対1で対応させる。**

- **タイトル**: 簡潔に要点をまとめる
- **body**: 下記フォーマット

bodyのフォーマット:
```markdown
## 背景 / 目的

（会話で議論した背景・動機・なぜやるか）

## 変更対象

- `src/xxx/foo.ts`: （何をどう変えるか）
- `config/bar.ts`: （同上）

## 方針

（実装アプローチをアプローチレベルで書く。寄せる既存パターン・ユーティリティを名指しする。
確信のない行レベルのコード例は書かない）

## Acceptance Criteria

- [ ] （検証可能な完了条件）
- [ ] （回帰確認: 既存機能への影響がないこと）
```

各セクションの必須度:
- **変更対象**・**Acceptance Criteria** は必須。空・曖昧だと下流で差し戻される。
- **方針** はアプローチが自明な小規模変更なら簡潔で可。複数アプローチがあるなら採用案と理由を明記する。

### Step 4: Issue作成

```bash
gh issue create --repo <REPO> --title "<タイトル>" --body "<body>" [--label "<label>"]
```

### Step 5: 完了報告

作成したIssueのURLを報告する。`/issue-to-pr <番号>` で着手できる旨を添える。
