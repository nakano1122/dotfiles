# 並列開発ワークフロー詳細

## 目次

- [全体フロー](#全体フロー)
- [Phase 1: 計画](#phase-1-計画)
  - [project-orchestrator の作業](#project-orchestrator-の作業)
  - [BE/FE オーケストレータの作業](#befe-オーケストレータの作業)
  - [計画完了時の案内テンプレート](#計画完了時の案内テンプレート)
- [Phase 2: 実装](#phase-2-実装)
  - [並列実行パターン](#並列実行パターン)
  - [モデル選択](#モデル選択)
  - [実装エージェントの動作](#実装エージェントの動作)
- [Phase 3: レビュー](#phase-3-レビュー)
  - [レビューの流れ](#レビューの流れ)
- [統合](#統合)
  - [feature → develop マージ](#feature--develop-マージ)
  - [クリーンアップ](#クリーンアップ)
- [フェーズ遷移ガイド](#フェーズ遷移ガイド)

## 全体フロー

```
Phase 1: 計画（project-orchestrator + BE/FE orchestrator）[Opus]
  ↓
Phase 2: 実装（エキスパートエージェントが worktree 内で自律実行）[Sonnet]
  ↓
Phase 3: レビュー（BE/FE orchestrator → project-orchestrator 横断レビュー）[Opus]
  ↓
統合（project-orchestrator が feature → develop をマージ管理）
```

## Phase 1: 計画

### project-orchestrator の作業

1. **feature ブランチ作成**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/{機能名}
   git push -u origin feature/{機能名}
   ```

2. **worktree 基盤準備**（初回のみ）
   ```bash
   echo ".worktrees/" >> .gitignore
   git add .gitignore && git commit -m "chore: .worktreesをgitignoreに追加"
   mkdir -p .worktrees
   ```

3. **タスクを BE/FE に振り分け**

   タスク分解結果をもとに、BE タスクと FE タスクに分類し、各オーケストレータに委譲する。

4. **BE/FE オーケストレータへの委譲**

   委譲フォーマット（後述）に従って、各オーケストレータにタスク一覧を渡す。

5. **開発者に実行手順を案内**

### BE/FE オーケストレータの作業

1. 各タスクの worktree + タスクブランチを作成
2. 各タスクのスラッシュコマンド（`worker-{task}.md`）を生成
3. 開発者に実行手順を案内

### 計画完了時の案内テンプレート

```
=== 計画完了 ===
以下のスラッシュコマンドを生成しました。

【BE タスク】
- /worker-{be-task-1}: {概要}
- /worker-{be-task-2}: {概要}

【FE タスク】
- /worker-{fe-task-1}: {概要}
- /worker-{fe-task-2}: {概要}

【次のアクション】
1. ターミナルで新しいタブを開く
2. プロジェクトルートで `claude --model sonnet` を起動（実装には Sonnet を使用）
3. 以下のコマンドを入力して放置:

(依存なしの場合) 同時に別タブで実行:
   /worker-{be-task-1}
   /worker-{fe-task-1}

(依存ありの場合) 先行タスク完了後に:
   /worker-{be-task-2}

4. 実装完了後、このタブに戻ってきてください
```

## Phase 2: 実装

### 並列実行パターン

#### パターン1: 独立タスク並列

```
ターミナル タブ1: /worker-{be-task-1}  ← 同時実行可
ターミナル タブ2: /worker-{fe-task-1}  ← 同時実行可
→ 依存なし、異なるディレクトリ
```

#### パターン2: 依存関係あり

```
ターミナル タブ1: /worker-{be-schema}   ← まず実行
→ schema 完了後
ターミナル タブ2: /worker-{be-api}      ← 同時実行可
ターミナル タブ3: /worker-{fe-auth}     ← 同時実行可
```

#### パターン3: レビュー + 修正

```
対話環境: task/{be-api} レビュー → fix コマンド生成
ターミナル: /fix-{be-api}              ← 非対話で修正
対話環境: 再レビュー → 承認

(並列で)
対話環境: task/{fe-auth} レビュー → fix コマンド生成
ターミナル: /fix-{fe-auth}             ← 非対話で修正
対話環境: 再レビュー → 承認
```

### モデル選択

- **Phase 1（計画）/ Phase 3（レビュー）**: `claude --model opus` で起動
- **Phase 2（実装）**: `claude --model sonnet` で起動

### 実装エージェントの動作

1. スラッシュコマンドの指示を読み込む
2. worktree ディレクトリに移動
3. 使用スキルに従って実装
4. 品質ゲート（lint/test/format）をすべてパスさせる
5. コミット・プッシュ
6. 完了出力を表示

## Phase 3: レビュー

### レビューの流れ

1. **BE/FE オーケストレータによるレビュー**
   - 各担当タスクの差分確認
   - スキル規約 + 専門観点でレビュー
   - 修正要求時は fix コマンド生成 → 修正 → 再レビュー
   - 承認後、rebase + feature ブランチへマージ

2. **project-orchestrator による横断レビュー**
   - BE/FE の整合性確認（API インターフェース、型定義の一致等）
   - 全体アーキテクチャとの整合性
   - 修正が必要な場合は担当オーケストレータに差し戻し

詳細は [review-session.md](review-session.md) を参照。

## 統合

### feature → develop マージ

project-orchestrator が管理:

1. 全タスクが feature ブランチにマージ済みであることを確認
2. 横断レビューが完了していることを確認
3. feature → develop の PR 作成・マージを案内

### クリーンアップ

```bash
# worktree 削除
git worktree remove .worktrees/task-{作業名}
# 全 worktree を一括削除する場合
rm -rf .worktrees && git worktree prune

# スラッシュコマンドファイル削除
rm -f .claude/commands/worker-*.md
rm -f .claude/commands/fix-*.md

# 作業ブランチ削除（任意）
git branch -d task/{作業名}
git push origin --delete task/{作業名}

# feature ブランチ削除（develop マージ後）
git branch -d feature/{機能名}
git push origin --delete feature/{機能名}
```

## フェーズ遷移ガイド

各フェーズ完了時に「次に何をすべきか」を具体的に案内する:

1. **計画完了時**: ターミナルで何を実行すべきかを案内（コマンド、タブ数、起動順序）
2. **実装完了時**（実装エージェントが出力）: 完了報告と次のアクションを案内
3. **レビューで修正要時**: fix コマンドとターミナルでの実行方法を案内
4. **レビュー承認時**: rebase・マージ手順と次のアクション（次タスク or 横断レビュー）を案内
5. **全完了時**: クリーンアップ手順を案内
