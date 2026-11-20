---
title: "Claude Code Hooks機能ガイド"
category: "claude-code"
tags: [Claude-Code, Hooks, 自動化, イベント駆動]
created: 2026-03-06
updated: 2026-07-28
---

# Claude Code Hooks機能ガイド

## 概要

Hooksは、Claude Codeのライフサイクル上の特定イベントで自動実行されるシェルコマンド・HTTPエンドポイント・LLMプロンプト。ファイル編集後のlint実行やツール呼び出し前のバリデーションなど、ワークフローの自動化に使う。

---

## 1. Hooksの仕組み

イベント発火 → マッチャー判定 → JSON入力をstdinで渡す → ハンドラ実行 → 終了コードで制御

## 2. イベントタイプ一覧

| イベント | 発火タイミング | マッチャー入力 | 主な用途 |
|---------|---------------|---------------|---------|
| `PreToolUse` | ツール実行前 | ツール名 | コマンドのバリデーション、実行ブロック |
| `PostToolUse` | ツール実行後 | ツール名 | lint実行、フォーマッタ適用 |
| `Stop` | Claudeの応答完了時 | なし | 最終チェック、通知 |
| `SubagentStart` | サブエージェント開始時 | エージェント名 | DB接続セットアップ等 |
| `SubagentStop` | サブエージェント完了時 | エージェント名 | クリーンアップ |
| `InstructionsLoaded` | 指示ファイル読み込み時 | なし | デバッグ・ロギング |
| `Elicitation` / `ElicitationResult` | MCP elicitation応答時 (v2.1.76) | なし | MCP elicitation応答のインターセプト |
| `PostCompact` | コンパクション完了後 (v2.1.76) | なし | コンパクション後の処理 |
| `StopFailure` | APIエラー発生時 (v2.1.78) | なし | レートリミット・認証エラーのハンドリング |
| `CwdChanged` / `FileChanged` | CWD変更時・ファイル変更時 (v2.1.83) | なし | direnv等のリアクティブ環境管理 |
| `TaskCreated` | タスク作成時 (v2.1.84) | なし | タスク作成時の初期化処理 |
| `PermissionDenied` | 自動モードで権限拒否時 (v2.1.89) | なし | 拒否後のリトライ（`{retry: true}`を返却可能） |

## 3. 設定方法

`settings.json` の `hooks` キーに記述する。

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

### フック定義の構造

| フィールド | 説明 |
|-----------|------|
| `matcher` | 正規表現でイベント対象をフィルタ（ツール名等） |
| `hooks[].type` | `command`（シェル）、`http`（HTTPエンドポイント）、`prompt`（LLMプロンプト） |
| `hooks[].command` | 実行するシェルコマンド |

## 4. 終了コードによる制御

| 終了コード | 動作 |
|-----------|------|
| `0` | 成功（続行） |
| `1` | エラー（Claudeにエラー内容を通知） |
| `2` | **ブロック**（ツール実行を中止。PreToolUseのみ） |

## 5. 実用例

### ファイル保存時に自動フォーマット

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write" }
        ]
      }
    ]
  }
}
```

### 危険なコマンドをブロック

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "./scripts/validate-command.sh" }
        ]
      }
    ]
  }
}
```

### 応答完了時にSlack通知

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "./scripts/notify-slack.sh" }
        ]
      }
    ]
  }
}
```

## 6. Hook拡張機能（2026年3月〜）

### 条件付きフック実行

`if` フィールドでパーミッションルール構文によるフィルタリングが可能（v2.1.85）。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "if": "Bash(git *)",
        "hooks": [
          { "type": "command", "command": "./scripts/git-hook.sh" }
        ]
      }
    ]
  }
}
```

### PreToolUseの新機能

- **`"defer"` パーミッション決定** (v2.1.89): ヘッドレスセッションでツール呼び出し時に一時停止させる
- **AskUserQuestion応答** (v2.1.85): `updatedInput` を返却してAskUserQuestionを自動応答可能

### Hook出力の制限

Hook出力が50K文字を超える場合、コンテキストに注入せずディスクに保存される（v2.1.89）。

### セキュリティ・管理設定

| 設定 | 説明 |
|------|------|
| `allowManagedHooksOnly` | 管理されたフックのみ許可 |
| `allowedHttpHookUrls` | HTTPフックの許可URL一覧 |
| `httpHookAllowedEnvVars` | HTTPフックに渡す環境変数の許可リスト |

### その他の拡張

- `WorktreeCreate` フックが `type: "http"` をサポート（v2.1.84）
- `UserPromptSubmit` フックが `hookSpecificOutput.sessionTitle` をサポート（v2.1.94）

## 7. Skillsとの使い分け

- **Hooks**: 「常に自動で実行したい処理」（lint、バリデーション、通知）
- **Skills**: 「特定の場面でClaude（または人間）が呼び出すワークフロー」

## 8. 2026年5月以降の変更点（追記）

- **effortレベルの参照**（5月上旬）: hooksから現在のreasoning effortを `effort.level`（JSON入力）または環境変数 `$CLAUDE_EFFORT` で参照できる。effortに応じて処理を分岐するhookが書ける

## 参考リンク

- [Hooks reference](https://code.claude.com/docs/en/hooks)
- [Automate workflows with hooks](https://code.claude.com/docs/en/hooks-guide)
