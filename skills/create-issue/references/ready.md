# ready モードの doctrine

`/create-issue` の ready モードで Issue 本文を書くときに従う。draft モードでは読まない。

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

## 検証（任意・codex スコープ外）

（live smoke / RPC / 外部API / market data 等、merge 後に Claude / 人間側で行う検証があればここに分離する）
```

各セクションの必須度:
- **変更対象**・**Acceptance Criteria** は必須。空・曖昧だと下流で差し戻される。
- **方針** はアプローチが自明な小規模変更なら簡潔で可。複数アプローチがあるなら採用案と理由を明記する。
  実装中に product/spec 判断が発生する余地を残さない（未確定の判断があるなら Issue 化前にユーザーと確定させる）。

Acceptance Criteria の検証可能性（codex stop condition との整合）:
- AC は **focused unit/regression test か typecheck で検証できる形**で書く
- live smoke・外部データ調査が必要な検証は blocking AC に混ぜず「## 検証」セクションへ分離する。
  codex が AC を literally 追って deep troubleshooting（LayerZeroScan / onchain receipt / market data 調査等）に
  滑り込むのを Issue 文面で防ぐ（#2038 の教訓）
- AC が現行コード / registry / data の実態と衝突しないか Step 1 の探索で確認する（衝突は codex の即 handoff トリガー）

### Step 4: autopilot 判定

**金曜バッチ（週の枠が余った時に無人で消化するキュー）に入れてよいかを判定する。** 条件は2つだけ:

- **blocker が無い**（依存 Issue が未 merge なら付けない。前提が merge された時点で付ける）
- **検証がローカルで閉じる**（実弾・サーバ deploy・課金 API・market data 調査を必要としない）

満たすなら `--label autopilot` を足す。レビュー要否・お金に関わるかは条件に含めない
（前者は既定が無人 merge、後者はユーザーが `/issue-to-pr` と `/issue-to-merge` の選択で制御する）。

**判定結果と理由を本文末尾に1行残す**（付けた/付けない どちらでも）。後から基準が緩んでいないか検証できるようにする。
例: `autopilot: 見送り（#3489 の merge 待ち）` / `autopilot: 対象（blocker 無し・型チェックで担保）`

不変条件: **`autopilot` が付いている = キューから任意の順で取り出して回せる**。
これが崩れると金曜の並列 worktree 実行が壊れるので、blocker 条件は必ず守ること。

### Step 5: Issue作成

```bash
~/.claude/bin/create-issue.sh --mode ready --repo <REPO> --title "<タイトル>" --body-file <path> --label <type> [--label autopilot]
```

生 `gh issue create` は hook で deny される。`--body-file` 必須（本文をコマンドラインに埋めない）。

### Step 6: 完了報告

作成したIssueのURLを報告する。`/issue-to-pr <番号>` で着手できる旨を添える。
