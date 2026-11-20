---
title: "Claude Code Agent Teams機能ガイド"
category: "claude-code"
tags: [Claude-Code, Agent-Teams, マルチエージェント, 並列処理, experimental]
created: 2026-05-26
updated: 2026-05-26
---

# Claude Code Agent Teams機能ガイド

## 概要

Agent Teamsは、複数のClaude Codeセッションを**チーム**として連携させる実験的機能。リーダーがチームメイトをspawnし、共有タスクリスト・メールボックス経由で各セッションが直接協調する。Sub-agentsが単一セッション内の子エージェントなのに対し、Agent Teamsはそれぞれ独立したClaude Codeインスタンスとして動作する。

---

## 1. 有効化

Agent Teamsはデフォルトで無効。`~/.claude/settings.json` または環境変数で有効化する。

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 前提条件

- Claude Code **v2.1.32以上**（`claude --version` で確認）
- Split-paneモードを使う場合: `tmux` または iTerm2 + `it2` CLI

## 2. Sub-agentsとの違い

|  | Sub-agents | Agent Teams |
|---|---|---|
| コンテキスト | 独自。結果はcaller(=メインAgent)に返る | 独自。完全に独立 |
| 通信 | メインAgentにのみ報告 | チームメイト同士が直接メッセージング |
| 調整 | メインAgentが全て管理 | 共有タスクリストでself-coordination |
| 向く用途 | 結果だけ欲しい焦点的タスク | 議論・協調が必要な複雑作業 |
| トークン | 低（結果を要約してメインへ） | 高（各メイトが独立したClaudeインスタンス） |

簡単に言うと、Sub-agentsは**結果を持ち帰る部下**、Agent Teamsは**互いに会話する同僚**。

## 3. 開始方法

有効化後、自然言語でチーム作成を依頼するだけ。

```text
CLIツールのTODOコメント追跡機能を設計する。
3人のチームを作って:
- UX担当
- 技術アーキテクチャ担当
- devil's advocate(対案担当)
それぞれの視点で調査して。
```

リーダーがチームを作り、チームメイトをspawnし、共有タスクリストを介して協調する。完了後はリーダーがcleanupを試みる。

## 4. 表示モード（teammateMode）

| モード | 説明 |
|---|---|
| `in-process` | チームメイトがメインターミナル内で動作。**Shift+Down**でメイト切替、入力で直接メッセージ送信。Enterでメイトのセッションを閲覧、Escapeで中断、Ctrl+Tでタスクリスト切替 |
| `tmux` (split panes) | 各メイトが別ペイン。クリックで切替。**tmuxまたはiTerm2が必要** |
| `auto` (デフォルト) | tmuxセッション内なら split panes、それ以外は in-process |

`~/.claude/settings.json` で固定化:

```json
{
  "teammateMode": "in-process"
}
```

セッション単位で上書き:

```bash
claude --teammate-mode in-process
```

iTerm2でsplit panesを使う場合は `it2` CLIインストール後、**iTerm2 → Settings → General → Magic → Enable Python API** を有効化。

## 5. チーム制御

### チームメイト数・モデル指定

```text
4人のチームメイトでこのモジュールをリファクタリング。
各メイトでSonnetを使って。
```

デフォルトではメイトはリーダーの `/model` を継承しない。`/config` の **Default teammate model** で変更可。

### Plan承認の強制

```text
authenticationモジュールのリファクタリング用にarchitectメイトをspawn。
変更前にplan承認を必須にして。
```

メイトはread-only plan modeで作業し、リーダーが承認/却下する。

### メイトと直接対話

各メイトは完全に独立したClaude Codeセッション。
- **in-process**: Shift+Downでメイト切替、入力で直接メッセージ
- **split panes**: ペインクリックで対話

### タスク管理

- 状態: pending / in progress / completed
- タスクは依存関係を持てる（依存先未完了なら claim 不可）
- リーダーが明示割当 or メイトがself-claim
- ファイルロックでrace condition防止

### シャットダウン・クリーンアップ

```text
researcherメイトをシャットダウンして
```

```text
チームをクリーンアップして
```

> **Warning**: cleanupは必ずリーダー経由で。メイトから実行するとリソースが不整合状態になる可能性あり。

## 6. 品質ゲートのHooks連携

[Hooks](Claude_Code_Hooks機能ガイド.md) を使ってチーム動作にゲートを設けられる。

| Hook | 用途 |
|---|---|
| `TeammateIdle` | メイトがidleになる直前。exit code 2でフィードバックを返し作業継続 |
| `TaskCreated` | タスク作成時。exit code 2で作成を阻止 |
| `TaskCompleted` | タスク完了時。exit code 2で完了を阻止 |

## 7. アーキテクチャ

| コンポーネント | 役割 |
|---|---|
| **Team lead** | チームを作成・メイトをspawn・調整する元セッション |
| **Teammates** | 個別のClaude Codeインスタンス |
| **Task list** | メイトがclaim/completeする共有作業リスト |
| **Mailbox** | エージェント間通信 |

ローカル保存先:
- Team config: `~/.claude/teams/{team-name}/config.json`
- Task list: `~/.claude/tasks/{team-name}/`

> Team configは自動生成・自動更新される。**手動編集禁止**（次回更新で上書きされる）。

### Sub-agent定義をメイトとして再利用

```text
security-reviewerエージェント型を使ったメイトをspawn、authモジュールを監査して。
```

Sub-agentの `tools` と `model` は適用される。本文はsystemプロンプトに**追加**される（置換ではない）。

> **注意**: Sub-agent frontmatterの `skills` と `mcpServers` は**メイトとして動作する時には適用されない**。メイトはプロジェクト/ユーザー設定からロードする。

### 権限

メイトはリーダーの権限設定で起動する。`--dangerously-skip-permissions` もそのまま継承。spawn後に個別変更可能だが、spawn時に個別指定はできない。

### コンテキスト共有

| コンテキスト | メイト引継ぎ |
|---|---|
| CLAUDE.md | ✅ |
| MCP servers | ✅ |
| Skills | ✅ |
| Spawn prompt | ✅（リーダーから） |
| リーダーの会話履歴 | ❌ |

メッセージは自動配信。idleになったメイトは自動でリーダーに通知。

## 8. 使い分けの目安

**Agent Teams向き**:
- 複数視点でのリサーチ・レビュー（PR review、設計検討）
- 競合仮説のデバッグ（5人で別の仮説を検証して論破し合う）
- レイヤー跨ぎの新機能開発（frontend/backend/test を別メイトが担当）
- 互いに独立して進められる新規モジュール開発

**Agent Teams不向き**（Sub-agentsか単一セッションで十分）:
- シーケンシャルなタスク
- 同一ファイルへの編集
- 依存関係の多い作業
- 軽い調査・単発タスク

## 9. ベストプラクティス

- **チーム規模**: 3-5人を目安。メイトあたり5-6タスクが理想
- **タスクサイズ**: self-containedで明確な成果物を出せる単位（関数1つ、テストファイル1つ、レビュー1件）
- **コンテキスト付与**: spawn promptに具体的な作業範囲・前提・出力要件を含める
- **ファイル競合回避**: メイトごとに担当ファイル集合を分ける
- **監視と修正**: 放置しすぎず、随時チェックして方向修正
- **PR reviewから始める**: コードを書かないタスクから慣れるのがおすすめ

## 10. トラブルシューティング

| 症状 | 対処 |
|---|---|
| メイトが現れない | in-processなら Shift+Down で切替確認。split panesなら `which tmux` 確認 |
| 権限プロンプトが多い | spawn前にpermissionsで共通操作を事前承認 |
| メイトがエラーで停止 | Shift+Down/ペイン切替で出力確認 → 直接指示か代替メイトをspawn |
| リーダーが先に終わる | 「メイトの完了を待ってから進めて」と指示 |
| orphan tmuxセッション | `tmux ls` → `tmux kill-session -t <name>` |

## 11. 制約（experimental）

- **/resume・/rewindで復元されない**（in-processメイト）
- タスクステータスがlagすることがある
- シャットダウンが遅い（実行中のtool callが完了するまで待つ）
- 同時に1チームのみ。新規作成前にcleanup必要
- **ネストチーム不可**（メイトは自分のチームを作れない）
- リーダーは固定（メイトに昇格不可）
- Split panesはVS Code統合ターミナル/Windows Terminal/Ghostty非対応

## 参考リンク

- [Orchestrate teams of Claude Code sessions（公式）](https://code.claude.com/docs/en/agent-teams)
- [Sub-agents機能ガイド](Claude_Code_Sub-agents機能ガイド.md) — 単一セッション内の子エージェント
- [Hooks機能ガイド](Claude_Code_Hooks機能ガイド.md) — TeammateIdle/TaskCreated/TaskCompleted
- [settings.json リファレンス](Claude_Code_settings_json_リファレンス.md) — `env`, `teammateMode`
