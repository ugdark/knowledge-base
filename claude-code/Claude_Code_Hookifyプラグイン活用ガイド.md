---
title: "Claude Code Hookifyプラグイン活用ガイド"
category: "claude-code"
tags: [claude-code, hookify, hooks, plugin, automation]
created: 2026-03-12
updated: 2026-03-12
---

# Claude Code Hookifyプラグイン活用ガイド

## 概要

hookifyは、Claude Codeのhooks機能をmarkdownルールファイルで簡単に管理するプラグイン。Pythonスクリプトやhooks.jsonを直接書かなくても、mdファイル1つで「このパターンが来たら警告/ブロック」が設定できる。

---

## hookifyの仕組み

```
ユーザー操作 → hookイベント発火 → hookifyが .claude/hookify.*.local.md を読み込み
→ パターンマッチ → warn（警告表示）or block（操作阻止）
```

- ルールは `.claude/hookify.{名前}.local.md` に配置
- 変更は即時反映（再起動不要）
- エラーが発生しても操作をブロックしない（安全設計）

## 4つのフックポイント

| イベント | 発火タイミング | 使用例 |
|---------|--------------|--------|
| `bash` | Bashツール実行時 | 危険コマンドのブロック |
| `file` | Edit/Write実行時 | 機密情報の書き込み警告 |
| `stop` | Claudeが停止しようとした時 | テスト未実行の検知 |
| `prompt` | ユーザーがプロンプト送信時 | 特定パターンの検知 |

## ルールファイルの書き方

### 基本構造

```markdown
# .claude/hookify.{名前}.local.md
---
name: ルール識別子
enabled: true
event: bash | file | stop | prompt | all
pattern: 正規表現パターン
action: warn | block
---

ユーザーに表示するメッセージ（markdown可）
```

### frontmatterフィールド

| フィールド | 必須 | 値 | 説明 |
|-----------|------|-----|------|
| `name` | Yes | kebab-case文字列 | ルールの一意な識別子 |
| `enabled` | Yes | `true` / `false` | 有効/無効の切り替え |
| `event` | Yes | `bash`, `file`, `stop`, `prompt`, `all` | 対象イベント |
| `pattern` | △ | Python正規表現 | 単一条件の場合 |
| `conditions` | △ | 条件オブジェクト配列 | 複数条件の場合（AND） |
| `action` | No | `warn`（デフォルト）/ `block` | 警告 or ブロック |

`pattern` と `conditions` はどちらか一方を指定する。

### 複数条件（conditions）

```yaml
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env$|credentials
  - field: new_text
    operator: contains
    pattern: API_KEY
```

**operator一覧**: `regex_match`, `contains`, `equals`, `not_contains`, `starts_with`, `ends_with`

**field一覧**（イベント別）:

| イベント | 使用可能なfield |
|---------|----------------|
| bash | `command` |
| file | `file_path`, `new_text`, `old_text`, `content` |
| stop | `transcript`, `reason` |
| prompt | `user_prompt` |

## settings.json denyとの使い分け

| やりたいこと | 手段 |
|-------------|------|
| 絶対にブロック（例外なし） | settings.json `deny` |
| 警告だけ出して判断はユーザーに | hookify `warn` |
| ファイルの中身をチェック | hookify `file`イベント（denyでは不可） |
| 完了条件の強制 | hookify `stop`イベント（denyでは不可） |
| プロジェクト単位で異なるルール | hookify（.local.mdをプロジェクトに配置） |

**結論**: settings.jsonのdenyは「ツール＋コマンドパターン」のみ。hookifyは「ファイル内容・停止条件・複数条件AND」まで対応。用途が異なるため共存可能。

## 実用的なルール例

### 1. ハードコードされた秘密情報の検知

```yaml
# .claude/hookify.no-hardcoded-secrets.local.md
name: no-hardcoded-secrets
enabled: true
event: file
action: warn
conditions:
  - field: new_text
    operator: regex_match
    pattern: (password|secret|token)\s*=\s*["'][^"']+["']
```

### 2. mainブランチへのcheckout警告

```yaml
# .claude/hookify.warn-main-checkout.local.md
name: warn-main-checkout
enabled: true
event: bash
pattern: git\s+checkout\s+(main|master)
action: warn
```

### 3. テスト未実行での停止をブロック

```yaml
# .claude/hookify.require-tests.local.md
name: require-tests-run
enabled: true
event: stop
action: block
conditions:
  - field: transcript
    operator: not_contains
    pattern: npm test|pytest|cargo test|sbt test
```

### 4. ユーザーOK未取得での停止をブロック

```yaml
# .claude/hookify.require-user-ok.local.md
name: require-user-ok
enabled: true
event: stop
action: block
conditions:
  - field: transcript
    operator: not_contains
    pattern: OK|問題ない|進めて
```

## コマンド一覧

| コマンド | 機能 |
|---------|------|
| `/hookify` | 会話を分析して自動ルール生成、または指示からルール作成 |
| `/hookify:list` | 設定済みルール一覧表示 |
| `/hookify:configure` | ルールの有効/無効を切り替え |
| `/hookify:help` | ヘルプ表示 |

## セットアップ

### 有効化

settings.jsonに追加:
```json
{
  "enabledPlugins": {
    "hookify@claude-plugins-official": true
  }
}
```

### ルールファイルの配置

プロジェクトの `.claude/` ディレクトリに `.local.md` ファイルを作成する。`.gitignore` に `.claude/*.local.md` を追加してバージョン管理対象外にする。

## 正規表現パターンの書き方

```
rm\s+-rf         → rm -rf, rm  -rf
console\.log\(   → console.log(
(eval|exec)\(    → eval( or exec(
chmod\s+777      → chmod 777
API_KEY\s*=      → API_KEY=, API_KEY =
\.env$           → .envで終わるファイル
```

## 参考リンク

- [Claude Code Hooks機能ガイド](Claude_Code_Hooks機能ガイド.md)
- [Claude Code Plugins機能ガイド](Claude_Code_Plugins機能ガイド.md)
- [Claude Code settings.json リファレンス](Claude_Code_settings_json_リファレンス.md)
