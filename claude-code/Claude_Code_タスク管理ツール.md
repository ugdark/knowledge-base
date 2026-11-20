---
title: "Claude Code タスク管理ツール（TaskCreate/TaskUpdate/TaskList）"
category: "claude-code"
tags: [Claude Code, TaskCreate, TaskUpdate, TaskList, タスク管理]
created: 2026-02-21
updated: 2026-03-06
---

# Claude Code タスク管理ツール

## 概要

Claude Codeには標準のタスク管理機能（TaskCreate / TaskUpdate / TaskList / TaskGet）が組み込まれている。会話中のタスク進捗をリアルタイムで追跡・表示する。

---

## ツール一覧

| ツール | 役割 |
|--------|------|
| **TaskCreate** | 新規タスク作成 |
| **TaskUpdate** | タスクのステータス・内容更新 |
| **TaskList** | 全タスクの一覧表示 |
| **TaskGet** | 特定タスクの詳細取得 |
| **TaskOutput** | バックグラウンドタスクの出力読み取り |
| **TaskStop** | 実行中タスクの停止 |

---

## TaskCreate

新しいタスクを作成する。作成時のステータスは常に `pending`。

### パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `subject` | ○ | タスクのタイトル（命令形: 「テストを作成」） |
| `description` | ○ | タスクの詳細説明 |
| `activeForm` | 推奨 | 進行中の表示テキスト（進行形: 「テストを作成中」） |

### 例

```
subject: "Validatorクラスを実装"
description: "ユーザー入力のバリデーションロジックを実装する"
activeForm: "Validatorクラスを実装中"
```

---

## TaskUpdate

タスクのステータスや内容を更新する。

### パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `taskId` | ○ | タスクID |
| `status` | - | `pending` / `in_progress` / `completed` / `deleted` |
| `subject` | - | タイトル変更 |
| `description` | - | 説明変更 |
| `addBlockedBy` | - | 依存タスクのID配列 |
| `addBlocks` | - | このタスクがブロックしているタスクのID配列 |

### ステータスの流れ

```
pending → in_progress → completed
                ↓
            deleted（不要になった場合）
```

### 重要ルール

- **completedにするのは本当に完了した時のみ**
  - テスト失敗中、実装が部分的、未解決エラーがある場合はcompletedにしない
- **deletedは永久削除** — 不要になったタスクに使用

---

## TaskList

全タスクのサマリーを表示する。

### 表示内容

- id: タスク識別子
- subject: タイトル
- status: ステータス
- owner: 担当（エージェント名）
- blockedBy: 依存タスクのID

---

## TaskGet

特定タスクの全詳細を取得する。

### パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `taskId` | ○ | タスクID |

### 取得内容

subject, description, status, blocks, blockedBy

---

## 依存関係の管理

タスク間の依存関係を設定できる。

```
TaskUpdate: taskId="2", addBlockedBy=["1"]
→ タスク2はタスク1が完了するまで開始できない
```

---

## 使うべき場面

### 使う

- 3ステップ以上の複雑なタスク
- 複数ファイルにまたがる実装
- ユーザーが複数のタスクをリスト形式で提示した場合
- 進捗の可視化が有用な場合

### 使わない

- 単純な1-2ステップのタスク
- 情報提供だけの会話
- d-plan-*スキルで管理している場合（planのチェックボックスで十分）

---

## d-plan-*スキルとの使い分け

| 項目 | TaskCreate等（標準） | d-plan-*スキル |
|------|---------------------|---------------|
| **永続化** | メモリ内のみ | .mdファイル保存 |
| **履歴管理** | 会話中のみ | completed/でアーカイブ |
| **計画セクション** | タスクのみ | 要件・対応状況・実装メモ等 |
| **ユーザー確認** | なし | 各タスク完了時に必須停止 |
| **適用範囲** | 1会話内の作業追跡 | 複数セッションにまたがる開発 |

### 推奨

- **大きな機能開発・複数セッション**: d-plan-*スキル
- **1セッション内の作業追跡**: TaskCreate/TaskUpdate
- **併用**: d-planのチェックボックス1つの中でTaskCreateを使い、細かいステップを追跡

---

## subject / activeForm の書き方

| subject（命令形） | activeForm（進行形） |
|-------------------|---------------------|
| Validatorを実装 | Validatorを実装中 |
| テストを作成 | テストを作成中 |
| ビルドを実行 | ビルドを実行中 |
| エラーを修正 | エラーを修正中 |
| ドキュメントを更新 | ドキュメントを更新中 |

---

## TaskOutput

バックグラウンドで実行中のタスクの出力を読み取る。`run_in_background: true` で起動したBashコマンドの結果取得に使用。

### パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `taskId` | ○ | タスクID |

---

## TaskStop

実行中のタスクを停止する。

### パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `taskId` | ○ | タスクID |

---

## Agent toolとの関係

旧 Task tool は **Agent** にリネームされた。既存の `Task(...)` 参照はエイリアスとして引き続き動作する。

パーミッション設定では `Agent(agent-type)` 構文を使う。

```json
{
  "permissions": {
    "deny": ["Agent(Explore)"]
  }
}
```
