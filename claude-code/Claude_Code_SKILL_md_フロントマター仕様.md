---
title: "Claude Code SKILL.md フロントマター仕様"
category: "claude-code"
tags: [skill-md, frontmatter, yaml, agent-skills, metadata]
created: 2026-01-01
updated: 2026-10-16
---

# Claude Code SKILL.md フロントマター仕様

## 概要

SKILL.md のフロントマター（YAML形式）でスキルのメタデータを定義する。**全フィールドが任意**だが、`description` は強く推奨。

---

## 1. フィールド一覧

| フィールド | 型 | デフォルト | 説明 |
|---|---|---|---|
| `name` | string | ディレクトリ名 | スキル名。`/name` でスラッシュコマンドになる |
| `description` | string | 本文の最初の段落 | スキルの説明。Claudeの自動選択の判断材料 |
| `when_to_use` | string | なし | Claudeが呼び出すべき場面の追加コンテキスト |
| `user-invocable` | boolean | `true` | `false` で `/` メニューに非表示 |
| `disable-model-invocation` | boolean | `false` | `true` でClaudeの自動呼び出しを禁止 |
| `allowed-tools` | string / list | なし | スキル実行中に許可確認なしで使えるツール |
| `disallowed-tools` | string / list | なし | スキル実行中に使用禁止にするツール |
| `argument-hint` | string | なし | オートコンプリート時の引数プレースホルダー |
| `arguments` | string / list | なし | `$name` 置換用の名前付き位置引数 |
| `model` | string | セッション継承 | スキル実行時のモデル指定 |
| `effort` | `low`〜`max` | 継承 | effortレベルの上書き（v2.1.80） |
| `context` | `fork` | なし（インライン） | `fork` で隔離サブエージェント実行 |
| `agent` | string | `general-purpose` | `context: fork` 時のサブエージェント種類 |
| `background` | boolean | `true` | `context: fork` のみ。`false` で完了を待機 |
| `hooks` | object（YAML） | なし | スキルスコープのライフサイクルフック |
| `paths` | string / list | なし | スキル有効化を限定するglobパターン |
| `shell` | `bash` / `powershell` | `bash` | `` !`command` `` 注入コマンド用シェル |
| `metadata` | object（YAML） | なし | フリーフォームのK-Vデータ |
| `license` | string | なし | ライセンス（Agent Skills仕様） |
| `compatibility` | string | なし | 環境要件・最大500字（Agent Skills仕様） |
| `initialPrompt` | string | なし | agent型スキルの初期プロンプト（v2.1.83） |

---

## 2. 各フィールド詳細

### `name`

- 小文字・数字・ハイフンのみ、最大64文字
- `anthropic` `claude` は予約語で使用不可、XMLタグ不可
- 同名スキルの優先順位: enterprise > personal > project
- `.claude/commands/` と同名の場合、スキルが優先

### `description`

- Claudeのシステムプロンプトにメタデータとしてプリロードされる（本文は呼出時のみ）
- 三人称で記述すべき（"Processes Excel files" ○、"I can help you" ×）
- 「何をするか」+「いつ使うか」の両方を含めると自動発見の精度が上がる
- 最大1024文字、XMLタグ不可
- description合計のコンテキスト予算: コンテキストウィンドウの2%（fallback: 16,000文字）。超過するとスキルが除外される（`/context` で確認可能）
- **v2.1.86変更**: `/skills` 一覧表示時のdescriptionが250文字に制限されるようになった（コンテキスト削減のため）

### `user-invocable` と `disable-model-invocation` の組み合わせ

**覚え方**: `user-invocable` はユーザー側のスイッチ、`disable-model-invocation` はClaude側のスイッチ

| user-invocable | disable-model-invocation | ユーザー | Claude | 使いどころ |
|---|---|---|---|---|
| `true` | `false` | `/` で呼べる | 自動で呼ぶ | 通常のスキル（plan系など） |
| `true` | `true` | `/` で呼べる | 呼べない | 手動専用（persona等、勝手に発動すると困るもの） |
| `false` | `false` | メニューに出ない | 自動で呼ぶ | バックグラウンド知識 |
| `false` | `true` | メニューに出ない | 呼べない | 誰も呼べない（実質無意味） |

コンテキストロードの挙動：

| 設定 | descriptionのロード | 本文のロード |
|---|---|---|
| デフォルト | 常時プリロード | 呼出時のみ |
| `disable-model-invocation: true` | ロードされない | ユーザー呼出時のみ |
| `user-invocable: false` | 常時プリロード | Claude呼出時のみ |

### `allowed-tools`

- カンマ区切りでツール名を列挙: `Read, Grep, Glob`
- ワイルドカードスコープ可能: `Bash(git *)`, `Bash(npm run *)`
- **追加許可**であり制限ではない。セッション全体のパーミッションも引き続き適用
- 省略時はセッションのパーミッション設定がそのまま適用

### `argument-hint`

- `/` メニューのオートコンプリート表示用（表示のみ、動作に影響しない）
- 例: `[issue-number]`, `[filename] [format]`

### `model`

- 特定モデルID指定: `claude-opus-4-6` 等
- `inherit` で現在のセッションモデルを使用（デフォルト動作）

### `context`

- 有効値: `fork` のみ（省略時はインライン実行）
- **インライン（省略時）**: スキル本文が会話にそのまま組み込まれ、会話履歴全体を共有。参考資料・ガイドライン向け
- **`fork`**: 隔離サブエージェントとして実行（メイン会話履歴にアクセスしない）。複数ステップの独立タスク向け
- `fork` 時はスキル本文がサブエージェントへのプロンプトになる
- CLAUDE.md はサブエージェントにもロードされる
- ガイドラインだけのスキルでは `fork` しても何もせず戻るので注意
- `background: false` を併記すると結果を待ってから続行する（デフォルトはバックグラウンド実行）

### `agent`

- `context: fork` と組み合わせて使用
- 組み込み: `Explore`, `Plan`, `general-purpose`
- `.claude/agents/` 内のカスタムエージェントも指定可能

### `hooks`

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "touch /tmp/triggered.txt"
          once: true
  PostToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "echo done"
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: "cleanup.sh"
```

- サポートイベント: `PreToolUse`, `PostToolUse`, `Stop`
- `once: true` でセッションあたり1回のみ実行

### `effort`（v2.1.80）

- スキルやスラッシュコマンドごとにeffortレベルを設定できる
- 例: `effort: high` でそのスキル実行時に高effortモードで動作

### `initialPrompt`（v2.1.83）

- `context: fork` のagent型スキルで初期プロンプトを宣言できる
- サブエージェント起動時に最初に渡されるプロンプトを定義する

---

## 3. 変数展開（String Substitutions）

スキル本文内で使える変数。

| 変数 | 説明 |
|------|------|
| `$ARGUMENTS` | `/skill名` に続く全引数 |
| `$ARGUMENTS[N]` | N番目の引数（0始まり） |
| `$N` | `$ARGUMENTS[N]` のショートハンド（`$0`, `$1`, `$2`...） |
| `${CLAUDE_SESSION_ID}` | セッションID（ログやファイル名に使用） |
| `${CLAUDE_SKILL_DIR}` | SKILL.mdの配置ディレクトリ（bundledスクリプトの参照に使用） |

`$ARGUMENTS` が本文に含まれない場合、引数は末尾に `ARGUMENTS: <value>` として追加される。

```yaml
---
name: migrate-component
description: コンポーネントをフレームワーク間で移行
---
$0 コンポーネントを $1 から $2 に移行してください。
```

`/migrate-component SearchBar React Vue` → `SearchBar コンポーネントを React から Vue に移行してください。`

---

## 4. 動的コンテキスト注入

`` !`command` `` 構文で、スキル実行前にシェルコマンドを実行し、結果をスキル本文に埋め込める。

```yaml
---
name: pr-summary
description: PRの変更をサマリーする
context: fork
agent: Explore
---

## PRコンテキスト
- diff: !`gh pr diff`
- コメント: !`gh pr view --comments`
- 変更ファイル: !`gh pr diff --name-only`

## タスク
このPRをサマリーしてください。
```

- 各 `` !`command` `` はClaude に送られる前に実行される
- コマンドの出力がプレースホルダーを置換する
- Claudeは最終結果だけを受け取る（前処理であり、Claudeが実行するわけではない）

---

## 5. バンドルスキル

Claude Codeに同梱されている標準スキル。

| スキル | 説明 |
|--------|------|
| `/simplify` | 変更ファイルのコード品質・再利用性・効率をレビューして修正。3並列エージェントで分析 |
| `/batch <instruction>` | コードベース全体への大規模変更を並列実行。git worktreeで隔離 |
| `/debug [description]` | セッションのデバッグログを分析してトラブルシュート |
| `/claude-api` | Claude API / Agent SDKのリファレンスをロード。`anthropic` importで自動発火 |

---

## 6. スキルのパーミッション制御

```
# 特定スキルのみ許可
Skill(commit)
Skill(review-pr *)

# 特定スキルを拒否
Skill(deploy *)

# Skillツール自体を全拒否
Skill
```

`Skill(name)` で完全一致、`Skill(name *)` でプレフィックスマッチ。

---

## 7. 注意事項

1. **カスタムフィールドは無視される**: 公式フィールド以外はパース時に除去され、モデルに渡されない。カスタム情報はマークダウン本文に記述すること
2. **SKILL.md は500行以下に抑える**: 大きくなる場合は詳細を別ファイルに分離
3. **副作用のあるスキルは `disable-model-invocation: true`**: デプロイ、コミット等の意図しない自動実行を防ぐ
4. **`allowed-tools` は最小権限の原則で**: 必要なツールのみ列挙
5. **extended thinking**: スキル本文に "ultrathink" を含めるとextended thinkingが有効になる

---

## 参考リンク

- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [GitHub Issue #13005 - カスタムフィールドが除去される件](https://github.com/anthropics/claude-code/issues/13005)
