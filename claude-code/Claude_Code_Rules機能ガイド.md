---
title: "Claude Code Rules機能ガイド"
category: "claude-code"
tags: [Claude-Code, Rules, CLAUDE.md, auto-memory, settings]
created: 2026-03-06
updated: 2026-04-17
---

# Claude Code Rules機能ガイド

## 概要

Claude Codeに永続的な指示を与える仕組み。CLAUDE.mdファイル、`.claude/rules/`ディレクトリ、auto memoryの3つで構成される。セッション開始時にコンテキストとして読み込まれ、コーディング規約やワークフローをClaude Codeに記憶させる。

---

## 1. 2つのメモリシステム

|  | CLAUDE.md | Auto Memory |
|--|-----------|-------------|
| **誰が書くか** | 人間 | Claude |
| **内容** | 指示・ルール | 学習した知見・パターン |
| **スコープ** | プロジェクト / ユーザー / 組織 | ワーキングツリー単位 |
| **読み込み** | 毎セッション全文 | 毎セッション先頭200行 |
| **用途** | コーディング規約、アーキテクチャ、ワークフロー | ビルドコマンド、デバッグ知見、好み |

## 2. CLAUDE.mdの配置場所と優先順位

より具体的（プロジェクト寄り）な場所ほど優先度が高い。

| スコープ | 配置場所 | 用途 | 共有範囲 |
|---------|---------|------|---------|
| **Managed Policy** | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md` | 組織全体の規約 | 全ユーザー |
| **Project** | `./CLAUDE.md` or `./.claude/CLAUDE.md` | チーム共有のプロジェクト指示 | チーム（git管理） |
| **User** | `~/.claude/CLAUDE.md` | 個人の全プロジェクト共通設定 | 自分のみ |
| **Local** | `./CLAUDE.local.md` | 個人のプロジェクト固有設定 | 自分のみ（gitignore） |

### 読み込み順序

1. カレントディレクトリから上位に向かってディレクトリツリーを走査
2. 各ディレクトリの `CLAUDE.md` と `CLAUDE.local.md` を読み込み
3. サブディレクトリの `CLAUDE.md` はClaude Codeがそのディレクトリのファイルを読んだ時にオンデマンドで読み込み

## 3. `.claude/rules/` ディレクトリ

CLAUDE.mdが大きくなった場合、トピック別にルールファイルを分割できる。

```
.claude/
├── CLAUDE.md
└── rules/
    ├── code-style.md    # コードスタイル
    ├── testing.md       # テスト規約
    └── security.md      # セキュリティ要件
```

### パス指定ルール（条件付きルール）

YAMLフロントマターの `paths` フィールドで、特定のファイルにだけ適用するルールを書ける。

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API開発ルール

- 全エンドポイントにバリデーションを入れること
- 標準エラーレスポンス形式を使うこと
```

| パターン例 | マッチ対象 |
|-----------|-----------|
| `**/*.ts` | 全ディレクトリのTypeScriptファイル |
| `src/**/*` | src/配下の全ファイル |
| `*.md` | プロジェクトルートのMarkdownファイル |
| `src/**/*.{ts,tsx}` | ブレース展開で複数拡張子を指定 |

`paths` なしのルールは起動時に無条件で読み込まれる。

**v2.1.84変更**: `paths` フロントマターがYAMLリスト形式の複数glob指定に対応。以前は単一パスのみだったが、上記の例のようにリストで複数パターンを指定可能になった。

### ユーザーレベルのrules

`~/.claude/rules/` に配置すると全プロジェクトに適用される。プロジェクトルールより低い優先度。

### シンボリックリンク対応

`.claude/rules/` はシンボリックリンクに対応。共通ルールを複数プロジェクトで共有できる。

```bash
ln -s ~/shared-claude-rules .claude/rules/shared
```

## 4. インポート機能

CLAUDE.mdから `@path/to/file` 構文で外部ファイルを取り込める。最大5段階のネスト。

```markdown
プロジェクト概要は @README.md を参照。
npmコマンドは @package.json を確認。

# 追加指示
- gitワークフロー @docs/git-instructions.md
```

- 相対パスはCLAUDE.mdの配置場所からの相対
- 初回は承認ダイアログが表示される

## 5. Auto Memory

Claude Codeが自動的に学習内容をメモとして保存する機能。

### 保存先

```
~/.claude/projects/<project>/memory/
├── MEMORY.md          # インデックス（毎セッション先頭200行を読み込み）
├── debugging.md       # デバッグパターン
└── api-conventions.md # API設計メモ
```

- 同一gitリポジトリ内のワーキングツリー・サブディレクトリは同じmemoryを共有
- マシンローカル（他のマシンとは共有されない）

### 制御方法

- `/memory` コマンドで確認・編集
- `autoMemoryEnabled: false` で無効化
- 環境変数 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` でも無効化可能

## 6. 効果的なCLAUDE.mdの書き方

| ポイント | 説明 |
|---------|------|
| **200行以内** | 長すぎるとトークン消費が増え、遵守率が下がる |
| **構造化** | Markdownの見出し・箇条書きで整理 |
| **具体的に** | "インデント2スペース" > "コードを綺麗に" |
| **矛盾を避ける** | 複数ファイル間で矛盾があると任意に選ばれる |
| **分割** | 大きくなったら `@import` や `rules/` で分割 |

### `/init` コマンド

`/init` を実行すると、コードベースを分析して初期CLAUDE.mdを自動生成する。既存ファイルがある場合は改善提案を行う。

## 7. モノレポ対応

`claudeMdExcludes` 設定で不要なCLAUDE.mdを除外できる。

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

Managed PolicyのCLAUDE.mdは除外不可（組織全体の指示は常に適用）。

## 参考リンク

- [How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
