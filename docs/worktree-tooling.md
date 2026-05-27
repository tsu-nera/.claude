# Worktree / ツーリング共通規約

自動化スキル（`issue-to-pr` / `test-pr` / `pr-merge` / `direct-commit` 等）が **どのプロジェクトでも破綻せず**
動くための環境適応規約。各スキルはこの内容をインライン化せず、本書を参照すること。

原則: **スキルは「何をするか」、本書は「どの環境でどう動かすか」** を担う。
方針変更時はこの1ファイルだけ直せば全スキルに反映される。

---

## 1. worktree での依存セットアップ

worktree では依存を**再 install しない**（時間がかかる・main の状態を壊す）。
プロジェクトのエコシステムに応じて：

- **Node**: `pnpm install` 等を実行せず、main の `node_modules` を symlink する
  `ln -s <main-repo>/node_modules <worktree>/node_modules`
- **Python**: main の `.venv` を利用するか `uv sync`（`uv.lock` がある場合）
- **判断不能・特殊構成**: プロジェクト CLAUDE.md の「開発環境 / Development Environment」節に従う

---

## 2. check / test コマンドの判定（3段フォールバック）

型チェック・lint・テストの実行コマンドは、以下の優先順で決定する：

1. **プロジェクト CLAUDE.md に check/test コマンドの明示があれば最優先**
   （独自エイリアス・非自明な手順を吸収。記述は陳腐化しうるが、独自規約はここでしか分からない）
2. **無ければ manifest + lockfile から自動判定**
   - **Node**: `package.json` の `scripts`、lockfile（`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock`）でパッケージマネージャを判定 → `<pm> run check && <pm> run test`
   - **Python**: `pyproject.toml` / `setup.cfg` から `ruff check` / `mypy` / `pytest`、`uv.lock` があれば `uv run` 経由
   - Makefile に `check` / `test` ターゲットがあればそれを使用
3. **テスト基盤が存在しない場合**: 基盤を新設しない（スコープを広げない）。
   対象モジュールの inline smoke test（`__main__` / `require.main === module`）で検証し、
   その旨を PR / 結果コメントに明記する

---

## 3. コミット除外・main 直コミット方針

何をコミットに含めるか／含めないかはプロジェクト固有。値を埋め込まず方針に従う：

- **プロジェクト CLAUDE.md にコミット除外対象**（キャッシュ・生成物ディレクトリ等）の
  指定があれば従い、`git add` は関連ファイルを明示する（blanket な `git add -A` を避ける）
- **main 直コミット運用対象**（プロジェクト CLAUDE.md で「PR を経由せず main へ直接」と
  定められたパス等）がある場合、その変更は PR 駆動スキルの対象外。直コミット運用に従う
