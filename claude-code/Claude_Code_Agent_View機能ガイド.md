---
title: "Claude Code Agent View機能ガイド"
category: "claude-code"
tags: [claude-code, agent-view, multi-session, background-session, tui]
created: 2026-06-18
updated: 2026-06-18
---

# Claude Code Agent View機能ガイド

## 概要

Claude Code の **Agent View（エージェントビュー）** は、複数セッション/エージェントを1画面で一覧管理する司令塔。状態別（Needs input / Working / Completed）にセッションが並び、Attach・Peek・新規作成・削除などをキーボードで操作できる。

---

## 1. Agent View とは

ターミナルから切り離された**複数のバックグラウンドセッション**を一覧で管理するビュー。各セッションは独立プロセスとして並行稼働し、`Supervisor process`（常駐プロセス）がそれらをホストする。マシンスリープ中も状態を保持する。

画面構成（例）:

```
Claude Code v2.1.181
Opus 4.8 (1M context) · ~/Works/cel_account_manager
4 awaiting input · 4 working · 2 completed

Needs input
 * current session              ...
 * japanese-language-session    ...
Working
 * needs input backlog review   ...
Completed
 * bg                           ...

describe a task for a new session   ← 最下部の入力欄
```

## 2. 開き方・閉じ方

### 開く

| 方法 | 操作 |
|------|------|
| ショートカット | セッション内で**空のプロンプト**のまま `←`（左矢印）。現在のセッションをバックグラウンド化して Agent View へ |
| コマンド | `claude agents` |

> ⚠️ 「左クリックで出た」と感じるのは誤解で、実際は**空プロンプトでの左矢印キー**。

起動オプション:

```bash
claude agents --cwd ~/path/to/project   # 特定ディレクトリのセッションのみ
claude agents --permission-mode plan    # デフォルトパーミッションモード
claude agents --model opus              # デフォルトモデル
```

### 閉じる・戻る

| やりたいこと | 操作 |
|------|------|
| ターミナルに戻る | `Esc` または `Ctrl+C` ×2 |
| セッションに入る（Attach） | 行を選択して `Enter` または `→` |
| セッションから抜ける（detach、実行は継続） | 空プロンプトで `←` |

## 3. 基本操作キーバインド

| 操作 | キー | 説明 |
|------|------|------|
| セッション選択 | `↑` / `↓` | 行間移動 |
| Attach | `Enter` / `→` | フル会話ビューへ切替 |
| Peek | `Space` | 入らずに最新出力・質問を確認 |
| 新規セッション作成 | 入力欄に記入 + `Enter` | 最下部の入力欄を使う |
| リネーム | `Ctrl+R` | セッション名変更 |
| ピン留め | `Ctrl+T` | 最上部に固定（プロセス保持） |
| グループ表示切替 | `Ctrl+S` | 状態別 ↔ ディレクトリ別 |
| 削除（停止して削除） | `Ctrl+X` ×2 | |
| 行の並び替え | `Shift+↑` / `Shift+↓` | |
| グループ折りたたみ | グループヘッダーで `Enter` | expand/collapse |
| ヘルプ | `?` | ショートカット一覧 |

### フィルタリング（最下部の入力欄）

- `a:<name>` … 指定エージェント名のセッション
- `s:<state>` … 指定状態（working, blocked など）
- `#<PR番号>` または PR URL … その PR 関連セッション

## 4. セッションの削除（Completed の片付け）

「停止」と「削除」は別概念。

| 操作 | 効果 | 一覧表示 |
|------|------|----------|
| `Ctrl+X`（1回目） | 停止（状態が Stopped に） | 残る |
| `Ctrl+X`（2秒以内に再度） | 削除 | 消える |
| `claude stop <id>` | 停止のみ（シェルから） | Stopped で残る |
| `claude rm <id>` | 削除（シェルから） | 消える |

- **個別削除**: 対象行で `Ctrl+X` を**2連打**。Completed は処理済みなので1回目の停止は実質的に削除の前段階。
- **グループ一括削除**: **グループ見出し**（例: `Completed`）にカーソルを合わせて `Ctrl+X` → 確認後、グループ内の全セッションを一括削除。大量に溜まった Completed の掃除に有効。
- **削除しても会話履歴は残る**: 一覧から消えるだけで transcript はローカル（`~/.claude/`）に保持され、`claude --resume` で復元可能。
- ⚠️ **worktree 注意**: そのセッションが自動生成した worktree を持つ場合、削除すると **未コミット変更も一緒に失われる**。残したいコードは削除前に commit/push する。自分で作って中で起動した worktree は残る。

## 5. セッション状態の意味

| 状態 | 表示 | 意味 |
|------|------|------|
| Working | 🔄 アニメーション | ツール実行・レスポンス生成中 |
| Needs input | 🟡 黄 | 質問やパーミッション決定を待機中 |
| Idle | ⚪ グレー | 処理なし、次のプロンプト待ち |
| Completed | 🟢 緑 | タスク正常完了 |
| Failed | 🔴 赤 | エラー終了 |
| Stopped | ⚫ グレー | `Ctrl+X` / `claude stop` で停止 |

グループセクションは `Pinned` / `Ready for review`（Open PR あり）/ `Needs input` / `Working` / `Completed` の順で整理される。

## 6. 他の並列実行機能との違い

| 機能 | 役割 |
|------|------|
| **Agent View** | 複数セッションを一覧管理（本体機能） |
| Subagents | 1セッション内で複数エージェントを並列実行 |
| Agent Teams | 複数セッション間でメッセージ交換 |
| Worktrees | 各セッションが独立した git 作業領域を使用 |

関連記事: [Sub-agents機能ガイド](Claude_Code_Sub-agents機能ガイド.md) / [Agent Teams機能ガイド](Claude_Code_Agent_Teams機能ガイド.md) / [タスク管理ツール](Claude_Code_タスク管理ツール.md)

## 7. 迷ったときの最小知識

- **戻りたい → `Esc`**
- **困ったら → `?` でヘルプ**
- 左端に見える縦の切れた文字はサイドバー/メニューがウィンドウ幅で潰れているだけ。気にしなくてよい。

## 参考リンク

- [Manage multiple agents with agent view - Claude Code Docs](https://code.claude.com/docs/en/agent-view.md)
- [Run agents in parallel - Claude Code Docs](https://code.claude.com/docs/en/agents.md)
- [Claude Code Agent View: Manage Every Session in One List](https://claudefa.st/blog/guide/agents/agent-view)
