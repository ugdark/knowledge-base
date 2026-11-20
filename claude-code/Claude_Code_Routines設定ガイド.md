---
title: "Claude Code Routines設定ガイド"
category: "claude-code"
tags: [Claude Code, Routines, スケジュール, 自動化, GitHub連携]
created: 2026-04-17
updated: 2026-04-17
---

# Claude Code Routines設定ガイド

## 概要

Routines（Research Preview、2026年4月〜）は、Claude Codeエージェントをクラウド上で定期実行・API呼び出し・GitHubイベント連携で自動実行する機能。ローカルPCが起動していなくても動作する。

---

## 1. Routinesとは

Anthropicのクラウドインフラ上で、完全に隔離されたClaude Codeセッションを自動起動する仕組み。

| 特徴 | 説明 |
|------|------|
| **実行環境** | Anthropicクラウド（ローカルではない） |
| **リポジトリ** | GitHubリポジトリを自動チェックアウト |
| **ツール** | Bash, Read, Write, Edit, Glob, Grep等を使用可能 |
| **MCP接続** | Notion, Asana等のMCPコネクタと連携可能 |
| **対応プラン** | Pro, Max, Team, Enterprise |

## 2. トリガータイプ

1つのRoutineに複数のトリガーを設定可能。

### Scheduled（cron）

cron式でスケジュール実行。最小間隔は1時間。

```
例: 毎週月曜9時(JST) = 0 0 * * 1 (UTC)
```

### API

HTTPのPOSTリクエストで実行。Bearer tokenで認証。

```
POST /api/triggers/{trigger_id}/run
Authorization: Bearer {token}
```

### GitHub

PR作成・リリース等のGitHubイベントで実行。

対応イベント:
- **Pull Request** — 作成、更新、ラベル追加等。著者、タイトル、ラベル、ブランチ、ドラフト状態でフィルタ可能
- **Release** — リリース公開時

## 3. 作成方法

### Webから

[claude.ai/code/scheduled](https://claude.ai/code/scheduled)（旧名称）または [claude.ai/code/routines](https://claude.ai/code/routines) で作成・管理。

### CLIから

```
/schedule
```

`RemoteTrigger`ツールを使用して作成・更新・実行。

### 設定項目

| 項目 | 説明 |
|------|------|
| **name** | Routine名 |
| **prompt** | エージェントへの指示（自己完結的に書く） |
| **repositories** | 対象GitHubリポジトリ |
| **environment** | 実行環境（ネットワーク、環境変数、セットアップスクリプト） |
| **connectors** | MCP接続（Notion, Asana等） |
| **cron_expression** | スケジュール（5フィールドcron、UTC） |
| **model** | 使用モデル（デフォルト: claude-sonnet-4-6） |

## 4. プロンプト設計のコツ

リモートエージェントはゼロコンテキストで起動するため、プロンプトは自己完結的に書く。

- **何をするか**を具体的に（「PRをレビューして」ではなく「mainブランチとの差分を確認し、セキュリティ上の問題があればコメントを残す」）
- **成功条件**を明確に
- **対象ファイル・ディレクトリ**を指定
- **アクション**を明示（コミットする、PRを作る、分析だけする等）

## 5. 制約事項

- ローカルファイル・環境変数にアクセス不可（リモート実行のため）
- cron最小間隔は1時間
- サブスクリプションの使用量に日次キャップあり
- 削除はWebUI（[claude.ai/code/scheduled](https://claude.ai/code/scheduled)）からのみ

## 6. 活用例

| 用途 | トリガー | プロンプト例 |
|------|---------|-------------|
| PRの自動レビュー | GitHub PR | 「セキュリティ・パフォーマンス観点でレビューし、問題があればコメントを残せ」 |
| 依存関係の定期チェック | Scheduled（週1） | 「package.jsonの依存を確認し、脆弱性があればissueを作成しろ」 |
| ナレッジベース更新 | Scheduled（月1） | 「knowledge-baseの記事を最新情報で更新し、PRを作成しろ」 |
| リリースノート生成 | GitHub Release | 「前回リリースからの変更をまとめ、CHANGELOG.mdを更新しろ」 |

## 参考リンク

- [Claude Code Routines Documentation](https://code.claude.com/docs/en/web-scheduled-tasks)
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog)
