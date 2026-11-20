---
title: "Ruler"
category: "ai"
tags: [rules-sync, agents-md, claude-code, codex]
created: 2026-11-20
updated: 2026-11-20
---

# Ruler

## 概要

`.ruler/` に置いた1つのルールを、各コーディングエージェントの形式（`CLAUDE.md`、`AGENTS.md`、Cursor のルールなど）に配る CLI。3つの同期ツールの中で最も単純で安定しているが、できることは最も少ない。分類は「設定・ルールの同期」（[AI用語集](ai/AI用語集.md) の6章）。

---

## 1. 基本情報（2026-11-20 時点）

| 項目 | 内容 |
|---|---|
| 開発 | Eleanor Berger（intellectronica）。メンテナは1人 |
| ライセンス | MIT |
| 位置づけ | README は「Beta Research Preview」と表記 |
| 対応エージェント | 約30。Claude Code、Codex CLI、Copilot、Cursor、Gemini CLI、Kiro、OpenCode、Windsurf など。汎用の `AGENTS.md` 出力もある |
| 同期できるもの | ルール、MCP サーバー、スキル（実験的）、サブエージェント（実験的、既定はオフ） |
| 必要なもの | Node.js（`^20.19`、`^22.12`、`>=23`） |
| 最新版 | 0.3.46（2026-10-22）。すべて 0.x。リリースの間隔は空きぎみ |

## 2. 仕組み

```mermaid
flowchart LR
  subgraph SRC[".ruler/（元）"]
    A["AGENTS.md ほか *.md"]
    T["ruler.toml"]
    SK["skills/ ・ agents/"]
  end
  SRC -->|ruler apply| O1["CLAUDE.md"]
  SRC -->|ruler apply| O2["AGENTS.md（Codex など）"]
  SRC -->|ruler apply| O3["Cursor のルール"]
  SRC -->|ruler apply| O4["MCP 設定"]
  O1 & O2 & O3 & O4 -.自動で .gitignore に追加.-> GI[".gitignore"]
```

- `.ruler/` の Markdown を連結して、各エージェントの形式で書き出す。
- 生成したファイルは、既定で `.gitignore` の管理ブロック（`# START Ruler Generated Files` 〜 `# END ...`）に追加される。
- グローバル設定は `~/.config/ruler`。

## 3. 使い始め

```bash
npm i -g @intellectronica/ruler   # または npx @intellectronica/ruler apply

ruler init            # .ruler/ を作る（--global でグローバル設定）
ruler apply           # 各エージェントの形式に書き出す
ruler apply --dry-run # 書き出す内容だけ確認する
ruler revert          # .bak のバックアップから元に戻す
```

主なオプション: `--agents`（対象を絞る）、`--no-mcp`、`--no-gitignore`、`--skills`、`--subagents`。

## 4. 活用できること（筆者の案）

| 使い方 | 内容 |
|---|---|
| ルールだけを複数エージェントでそろえる | Claude Code と Codex と Cursor を併用するチームで、同じコーディング規約を配る |
| 生成物を git に入れない運用 | 元の `.ruler/` だけをコミットし、生成ファイルは各自 `ruler apply` で作る |
| まず試す1本目 | 機能が少なく、`revert` で戻せるので、同期ツールの入門に向く |

## 5. 注意点

- 既存の設定ファイルを `.ruler/` へ取り込む（import）機能は無い。
- コマンド、フック、権限、ignore ファイルの同期は README に記載が無い。
- 生成ファイルが gitignore されるため、新しい git worktree では `ruler apply` をやり直す必要がある。並列実行ツールと組み合わせるときに注意。
- Codex は、`CODEX_HOME` をプロジェクトの `.codex` に向ける必要がある。
- サブエージェントは `revert` に対応していない。
- dotfiles で `CLAUDE.md` から `AGENTS.md` を読み込んで共有しているなら、ルールだけの同期は既にできている。ツールを入れる意味が出るのは、MCP やスキルも配りたい場合。

## 参考リンク

- [intellectronica/ruler（GitHub）](https://github.com/intellectronica/ruler)
- [@intellectronica/ruler（npm）](https://www.npmjs.com/package/@intellectronica/ruler)
- [Ruler（紹介ページ）](https://ai.intellectronica.net/ruler)
