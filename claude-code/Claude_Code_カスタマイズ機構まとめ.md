---
title: "Claude Code カスタマイズ機構まとめ"
category: "claude-code"
tags: [Claude-Code, カスタマイズ, 機構比較, 使い分け]
created: 2026-03-06
updated: 2026-07-28
---

# Claude Code カスタマイズ機構まとめ

## 概要

Claude Codeの動作をカスタマイズする7つの機構を横断的に比較し、「こういう時はこれを使う」を事例ベースで整理する。

---

## 1. 機構一覧

| 機構 | 何をするか | 配置場所 | 読み込み | 実行主体 |
|------|-----------|---------|---------|---------|
| **Rules** | 永続的な指示・ルール | `CLAUDE.md`, `.claude/rules/` | 毎セッション開始時 | Claude（コンテキストとして参照） |
| **Skills** | 再利用可能なワークフロー | `.claude/skills/` | 説明は常時、本文は呼び出し時 | Claude自動 or `/skill名` で手動 |
| **Hooks** | イベント駆動の自動実行 | `settings.json` | イベント発火時 | シェルコマンド/HTTP/LLM |
| **Sub-agents** | タスク特化型の子エージェント | `.claude/agents/` | セッション開始時 | Claudeが自動委譲 or 指示で明示 |
| **MCP** | 外部ツール・データ連携 | `settings.json` | セッション開始時 | Claude（ツールとして使用） |
| **Settings** | 権限・動作・環境設定 | `settings.json` | 毎セッション開始時 | システム |
| **Plugins** | 上記を束ねたパッケージ配布 | 独立ディレクトリ | インストール時 | 上記の組み合わせ |

## 2. 「こういう時はこれを使う」事例集

### コーディング規約・ルールを守らせたい

→ **Rules** (`CLAUDE.md` or `.claude/rules/`)

```
例: インデント2スペース、コミット前にテスト実行、APIは必ずバリデーション
```

- 全ファイル共通なら `CLAUDE.md` に記載
- 特定ファイルだけなら `.claude/rules/` に `paths` フロントマターで限定

### 繰り返すワークフローをテンプレ化したい

→ **Skills** (`.claude/skills/`)

```
例: PR作成、Plan作成、コードレビュー、デプロイ手順
```

- `/pr-create` のように手動呼び出しなら `disable-model-invocation: true`
- Claudeに自動で使わせるなら `description` を明確に書く

### ファイル保存時に自動でlint/formatしたい

→ **Hooks** (`settings.json`)

```
例: Edit/Write後にprettier実行、危険コマンドのブロック、完了時Slack通知
```

- `PostToolUse` + matcher `Write|Edit` でファイル変更を検知
- `PreToolUse` + 終了コード2 でツール実行をブロック

### 大量出力をメイン会話から隔離したい

→ **Sub-agents** (`.claude/agents/`)

```
例: テスト一括実行→失敗だけ報告、コードベース全体の探索、並列リサーチ
```

- 出力が大きい作業はSub-agentに委譲してコンテキスト節約
- `model: haiku` で高速・低コストに探索

### 外部サービスと連携したい

→ **MCP** (`settings.json`)

```
例: GitHub API、Slack、DB接続、Notion、Jira
```

- MCPサーバーを設定すると、Claudeがツールとして使える
- Sub-agentの `mcpServers` フィールドで特定エージェントだけに提供も可

### チームに設定を配布したい

→ **Plugins**

```
例: 社内レビュースキル+lint hooks+MCPサーバーをセットで配布
```

- Skills + Hooks + Agents + MCP を1パッケージで管理
- マーケットプレイスで配布、`/plugin install` でインストール

### 個人の好みを全プロジェクトに適用したい

→ **Rules** (`~/.claude/CLAUDE.md`) + **Settings** (`~/.claude/settings.json`)

```
例: 常にsnake_case、vim keybind、特定ツールの許可/拒否
```

## 3. 組み合わせパターン

### パターン1: Skill + Sub-agent

Skillの `context: fork` でSub-agentに委譲実行する。

```yaml
---
name: deep-research
description: コードベースを徹底調査
context: fork
agent: Explore
---
$ARGUMENTS について調査し、結果をまとめてください。
```

→ Skillがインターフェース、Sub-agentが実行環境。

### パターン2: Sub-agent + Hooks

Sub-agentにHooksを定義して、ツール使用をバリデーション。

```yaml
---
name: db-reader
description: 読み取り専用のDBクエリ実行
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---
```

→ SELECT文のみ許可、INSERT/DELETE等はブロック。

### パターン3: Rules + Skills

Rulesでプロジェクトの規約を定義し、Skillsでその規約に沿ったワークフローを提供。

```
CLAUDE.md → 「コミットメッセージはConventional Commits形式」
/commit skill → 「git diffを分析してConventional Commits形式でコミット」
```

→ Rulesが「何を守るか」、Skillsが「どう実行するか」。

### パターン4: Plugin = 全部入り

Skills + Hooks + Agents + MCP + Settings をPluginで束ねて配布。

```
my-team-plugin/
├── skills/review/SKILL.md     # レビュースキル
├── agents/reviewer.md         # レビュー用エージェント
├── hooks/hooks.json           # 自動フォーマット
└── .mcp.json                  # 社内APIサーバー
```

## 4. 判断フローチャート

```
やりたいことは？
│
├─ 常に適用するルール・指示 → Rules
│
├─ 特定の操作をテンプレ化 → Skills
│   ├─ 手動で呼びたい → disable-model-invocation: true
│   └─ Claudeに自動判断させたい → description を明確に
│
├─ ツール使用時に自動で何かしたい → Hooks
│   ├─ 実行前に検証 → PreToolUse
│   └─ 実行後に処理 → PostToolUse
│
├─ 隔離コンテキストで作業させたい → Sub-agents
│   ├─ 読み取り専用探索 → Explore (ビルトイン)
│   └─ カスタム処理 → .claude/agents/ に定義
│
├─ 外部サービス連携 → MCP
│
└─ チームに配布したい → Plugins
```

## 5. 最新の主要機能（2026年3月〜4月）

### Auto Mode（v2.1.83, 2026-03-25）

Research Preview。パーミッション分類器がプロンプトを自動判定し、ツール許可の確認なしで実行を継続する。対話的な承認の手間を大幅に削減。

### Computer Use（v2.1.86〜91, 2026-03-30）

Research Preview。ターミナルからネイティブアプリの起動やUIクリックが可能。GUIテストやブラウザ操作の自動化に活用できる。

### Routines / Scheduled Agents（2026-04-14）

クラウドベースの自動化。cron / API / GitHubトリガーでClaude Codeエージェントをリモート実行する仕組み。定期レビューやデプロイ監視を無人で回せる。

### Ultraplan（v2.1.92, 2026-04-06）

クラウド上でドラフトプランを生成し、Webエディタでレビュー・編集する機能。大規模タスクの計画フェーズを効率化。

### NO_FLICKER alt-screen rendering（v2.1.89）

環境変数 `CLAUDE_CODE_NO_FLICKER=1` またはTUI設定で有効化。alt-screenレンダリングにより画面のちらつきを抑制。

### Monitor tool（v2.1.98, 2026-04-09）

バックグラウンドで発生しているイベントを会話にストリーミングするツール。CI/CD実行やデプロイの進行状況をリアルタイムで会話内に表示できる。

### Opus 4.7（2026-04-16）

SE能力が向上した新モデル。xhigh effortレベルに対応。`/ultrareview` コマンドを新たに提供。

---

## 6. 2026年5〜7月の主要アップデート（追記）

- **dynamic workflows**（5月下旬）: Claudeが書いたスクリプトから数十〜数百のサブエージェントを編成する仕組み。大規模な調査・レビュー・移行向け
- **`/goal`**（5月中旬）: 完了条件を満たすまでターン跨ぎで作業を継続させる
- **カスタムテーマ**（4月下旬）: `/theme` またはプラグインでカラーパレットを配布可能
- **プラグインの.zip/URL読込**（5月上旬): `--plugin-dir` が.zip対応、`--plugin-url` でセッション単位の取得
- **`--safe-mode`**（6月上旬）: 全カスタマイズを無効化して起動するトラブルシュート用フラグ
- **`/doctor`（別名 `/checkup`）**（7月上旬）: セットアップ診断と自動修復
- **`/fork` の背景セッション化**（7月中旬): 会話コピーを別セッションとして起動。従来のセッション内サブエージェント起動は `/subtask` に改名
- **hooksがeffortレベルを参照可能**（5月上旬）: `effort.level` / `$CLAUDE_EFFORT`

## 参考リンク

- [Rules (Memory)](https://code.claude.com/docs/en/memory)
- [Skills](https://code.claude.com/docs/en/skills)
- [Hooks](https://code.claude.com/docs/en/hooks)
- [Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [MCP](https://code.claude.com/docs/en/mcp)
- [Plugins](https://code.claude.com/docs/en/plugins)
- [Settings](https://code.claude.com/docs/en/settings)
