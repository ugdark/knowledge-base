---
title: "Claude Code Sub-agents機能ガイド"
category: "claude-code"
tags: [Claude-Code, Sub-agents, エージェント, 並列処理]
created: 2026-03-06
updated: 2026-10-16
---

# Claude Code Sub-agents機能ガイド

## 概要

Sub-agentsは、特定タスクに特化した子エージェント。独自のコンテキストウィンドウ・システムプロンプト・ツール制限を持ち、メインの会話を汚さずに作業を委譲できる。

---

## 1. ビルトインSub-agents

| エージェント | モデル | ツール | 用途 |
|------------|--------|--------|------|
| **Explore** | Haiku（高速） | 読み取り専用 | ファイル検索、コードベース探索 |
| **Plan** | 継承 | 読み取り専用 | plan mode時のリサーチ |
| **general-purpose** | 継承 | 全ツール | 複雑な調査、複数ステップの操作 |

## 2. カスタムSub-agentの作成

`.claude/agents/` または `~/.claude/agents/` にMarkdownファイルを配置する。

```markdown
---
name: code-reviewer
description: コード品質とベストプラクティスをレビュー。コード変更後に積極的に使用する。
tools: Read, Glob, Grep, Bash
model: sonnet
---

あなたはシニアコードレビュアーです。呼び出された時：
1. git diffで最近の変更を確認
2. 変更ファイルに焦点を当てる
3. レビューを開始

レビューチェックリスト：
- コードの可読性
- エラーハンドリング
- セキュリティリスク
- テストカバレッジ
```

### 配置場所と優先順位

| 場所 | スコープ | 優先度 |
|------|---------|--------|
| `--agents` CLIフラグ | セッション限定 | 最高 |
| `.claude/agents/` | プロジェクト | 高 |
| `~/.claude/agents/` | 全プロジェクト | 中 |
| Plugin の `agents/` | Plugin有効範囲 | 低 |

## 3. 主要な設定フィールド

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | Yes | 一意識別子（小文字+ハイフン、256字以下） |
| `description` | Yes | Claudeがいつ委譲するか判断する説明文 |
| `tools` | No | 使用可能ツール（省略時は全継承）。カンマ区切り or YAMLリスト |
| `disallowedTools` | No | 継承ツールから除外するツール |
| `model` | No | `sonnet`, `opus`, `haiku`, `fable`, full ID, `inherit` |
| `effort` | No | `low`〜`max`。effortレベルの上書き |
| `permissionMode` | No | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, `manual` |
| `maxTurns` | No | 最大ターン数 |
| `autoCompactWindow` | No | 自動圧縮のトークン閾値（100k〜1m） |
| `skills` | No | 起動時にロードするスキル（最大32） |
| `mcpServers` | No | 利用可能なMCPサーバー名 or インライン定義 |
| `memory` | No | 永続メモリ: `user`, `project`, `local` |
| `background` | No | `true` でバックグラウンド実行を強制 |
| `isolation` | No | `worktree` で独立git worktreeで実行 |
| `hooks` | No | サブエージェント固有のフック（PreToolUse等） |
| `omitClaudeMd` | No | `true` でCLAUDE.md（user/project/local）を読み込まない |
| `color` | No | タスク一覧の表示色（red, blue, green 等8色） |
| `initialPrompt` | No | 起動時に自動送信される初期ターン |
| `experimental` | No | 実験的オプション（例: `{cacheTtl: "1h"}`） |

## 4. 永続メモリ

`memory` フィールドを設定すると、セッションを跨いで学習を蓄積できる。

| スコープ | 保存先 | 用途 |
|---------|--------|------|
| `user` | `~/.claude/agent-memory/<name>/` | 全プロジェクト共通の知見 |
| `project` | `.claude/agent-memory/<name>/` | プロジェクト固有（git共有可） |
| `local` | `.claude/agent-memory-local/<name>/` | プロジェクト固有（git除外） |

## 5. フォアグラウンド vs バックグラウンド

| モード | 特徴 |
|--------|------|
| **フォアグラウンド** | 完了まで会話をブロック。権限プロンプトが表示される |
| **バックグラウンド** | 並行実行。事前に権限を承認。Ctrl+Bで切替可能 |

## 6. Skillsとの使い分け

- **Sub-agents**: 独立コンテキストで隔離実行したい時（大量出力の処理、並列リサーチ）
- **Skills**: メイン会話のコンテキストで実行したい再利用プロンプト

## 7. Sub-agentsの制約と注意点

### コンテキスト継承の全体像

Sub-agentsはメインの会話コンテキストを**すべて引き継ぐわけではない**。何が渡り、何が渡らないかを把握しておく必要がある。

| コンテキスト | 継承 | 備考 |
|---|---|---|
| CLAUDE.md | ✅ | プロジェクト・ユーザーレベルとも読み込まれる |
| .claude/rules/ | ✅ | paths指定ルールも対応ファイル操作時に適用 |
| ~/.claude/rules/ | ✅ | ユーザーレベルルールも適用 |
| Skills（system-reminder） | ❌ | スキル一覧が渡らないため実質使えない |
| Auto memory（MEMORY.md） | ❌ | 親の蓄積は共有されない。独自メモリは`memory`フィールドで設定可能 |

### スキルが使えない

スキル一覧はsystem-reminderとしてメイン会話に注入されるが、Sub-agentsには渡されない。

### 並列実行時の典型的な失敗パターン

「3つのタスクを並列でやって」と依頼し、各タスクがスキル（例: `/d-plan-create`）を前提としている場合：

1. メインClaudeがAgentツールで3つの子プロセスを起動
2. 子プロセスにはスキル一覧が**渡らない**
3. 各エージェントはスキルのテンプレート・フローを知らずに**自己流で実行**
4. 結果、期待したフォーマットや手順が守られない

### 対策

- **スキルを使うタスクは並列にしない** → メインClaudeが1つずつ順番に実行する
- **並列に向くタスク**: 調査・検索・コード探索などスキル不要な作業
- **カスタムSub-agent**で `skills` フィールドを指定すれば、起動時にスキルをロード可能（ビルトインSub-agentsでは不可）

## 8. Sub-agents APIの変更点

### resumeパラメータの廃止（v2.1.76+）

Agentツールの `resume` パラメータは廃止された。停止中のエージェントを再開するには `SendMessage({to: agentId})` を使用する。

### SendMessageによる自動再開（v2.1.76+）

`SendMessage` で停止中のエージェントにメッセージを送ると、自動的にエージェントが再開される。

### @メンションでの名前付きサブエージェント表示（v2.1.89）

名前付きサブエージェントが `@` メンションのタイプアヘッド候補に表示されるようになった。

### /fork から /branch へリネーム（v2.1.76+）

会話を分岐するコマンドが `/fork` から `/branch` に変更された。

## 9. 2026年6〜7月の変更点（追記）

- **サブエージェントはデフォルトでバックグラウンド実行に**（6月末）: メインが作業を続けたまま並行実行。完了時に通知が来る
- **背景サブエージェントの権限プロンプト改善**（6月下旬）: 従来は自動拒否だったのが、メインセッションに許可プロンプトを表示するようになった
- **サブエージェントの入れ子生成**（6月上旬）: サブエージェントが自分のサブエージェントを生成可能に（背景チェーンは5階層まで）
- **`/subtask` 新設**（7月中旬）: 従来 `/fork` が担っていたセッション内サブエージェント起動が `/subtask` に。`/fork` は会話を別背景セッションにコピーする動作に変更

## 参考リンク

- [Create custom subagents](https://code.claude.com/docs/en/sub-agents)
