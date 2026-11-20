---
title: "CLAUDE.md vs AGENTS.md 比較ガイド"
category: "ai-coding-agents"
tags: [Claude-Code, Codex, CLAUDE.md, AGENTS.md, AIコーディングエージェント, プロジェクト設定]
created: 2026-06-10
updated: 2026-06-10
---

# CLAUDE.md vs AGENTS.md 比較ガイド

## 概要

AIコーディングエージェントに「このプロジェクトをどう扱うか」を教えるための設定ファイル。
エージェントごとに読むファイルが異なる。

| ファイル | 対象エージェント |
|---------|----------------|
| `CLAUDE.md` | Claude Code（Anthropic） |
| `AGENTS.md` | OpenAI Codex |

両方を並行運用する場合は、リポジトリルートに両ファイルを置く。

---

## 共通の役割

- プロジェクト概要・ディレクトリ構成の説明
- 作業ルール・禁止操作の定義
- コーディング規約・テストコマンドの記述
- エージェントが自律的に判断するための文脈提供

---

## 主な違い

### 1. 対象エージェント

```
CLAUDE.md  → Claude Code が起動時に自動読み込み
AGENTS.md  → OpenAI Codex が起動時に自動読み込み
```

### 2. 記述スタイルの傾向

**CLAUDE.md** はカスタマイズ機構（Skills・Hooks・Rules・MCP等）との連携が前提で、
プロジェクト固有のコマンドや設計方針を自由に記述する。

**AGENTS.md** は構造化された記述が推奨される傾向がある。
以下のセクション構成が実用的：

- プロジェクト概要
- Git管理境界（複数リポジトリの場合）
- 重要なパス
- 作業ルール
- 検証手順

### 3. デフォルトの挙動への期待値

AGENTS.mdでは「明示しない限りコミット・pushしない」を明記するのが慣例。
CLAUDE.mdでは `settings.json` の `permissions` で制御する方が適切。

### 4. 検索ツールの指定

AGENTS.mdでは `rg`（ripgrep）を優先使用するよう明記するとパフォーマンスが良い。
Claude Codeでは `Grep` / `Bash` ツールで対応するため、CLAUDE.mdへの明記は任意。

### 5. 階層的な配置

| 挙動 | Claude Code | Codex |
|------|-------------|-------|
| プロジェクトルートのファイルを読む | ✅ | ✅ |
| サブディレクトリのファイルも読む | ✅（階層的に読む） | ✅ |
| ホームディレクトリのグローバル設定 | `~/.claude/CLAUDE.md` | なし（2026年6月時点） |

---

## 並行運用パターン

Claude CodeとCodexを同一リポジトリで使う場合：

```
repo/
├── CLAUDE.md    # Claude Code 向け
├── AGENTS.md    # Codex 向け
└── ...
```

共通内容（プロジェクト概要・パス構成）は両方に記載し、
エージェント固有の設定（Hooksの参照・permissionsの言及等）はそれぞれに分けて書く。

---

## 記述のコツ

- **Git管理境界を明記する**：サブモジュールや複数リポジトリがある場合は必須
- **破壊的操作を禁止する**：`git reset --hard`・`rm -rf`・force pushは明示的に禁止
- **パスは絶対パスより相対パスで書く**：環境依存を避ける
- **長くなりすぎない**：エージェントのコンテキスト消費を抑えるため、要点だけ書く

---

## 参考

- [Codex / Claude Code 使い分けガイド](Codex_Claude_Code_使い分けガイド.md)
- [Claude Code カスタマイズ機構まとめ](claude-code/Claude_Code_カスタマイズ機構まとめ.md)
