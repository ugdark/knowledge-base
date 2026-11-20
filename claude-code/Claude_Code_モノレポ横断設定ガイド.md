---
title: "Claude Code モノレポ・複数repo横断設定ガイド"
category: "claude-code"
tags: [Claude-Code, モノレポ, 設定解決, Plugins, 大規模コードベース]
created: 2026-06-23
updated: 2026-06-23
---

# Claude Code モノレポ・複数repo横断設定ガイド

## 概要

複数のrepoをサブディレクトリにぶら下げた構成（モノレポ / Docsリポジトリ + submodule等）で、`CLAUDE.md` / `rules` / `skills` / `settings.json` が「どこから読み込まれるか」の発見ルールと、設定を横断的に効かせる公式の推奨パターンを整理する。

---

## 1. 発見ルールの核心: 「指示系」と「設定系」で挙動が真逆

起動ディレクトリ（cwd）より下のサブディレクトリ（=各repo）に置いた `.claude/` がどう扱われるかは、**ファイルの種類で2分される**。

| 各repo内のファイル | ネスト発見される？ | タイミング |
|---|---|---|
| `CLAUDE.md` | ✅ | そのrepoのファイルを触った時（オンデマンド） |
| `.claude/rules/` | ✅ | マッチするファイルを触った時 |
| `.claude/skills/` | ✅ | Claudeが関連と判断した時にロード |
| `.claude/commands/` | ✅ | skillsに統合済み。同様 |
| `.claude/settings.json` / `settings.local.json` | ❌ | **起動したcwdの1枚のみ。親も子も継承しない** |
| hooks / permissions / env（settings.json内） | ❌ | settings.jsonと同じ運命 |

### 線引きの本質

「rules/skillsかどうか」ではなく、**指示（Claudeの振る舞いを導くもの）か、設定（クライアントが強制するもの）か**で分かれる。

- **指示系**（`CLAUDE.md` / `rules` / `skills` / `commands`）→ コンテキストに載るもの → **ツリーを歩いて発見**
  - 親方向: 起動時にcwd〜リポジトリrootまで全て読む
  - 子方向: そのディレクトリのファイルを触った時にオンデマンドで読む
- **設定系**（`settings.json` 一式）→ クライアントが実行・強制するもの → **cwd 1セットのみ**（+ user + managed）

> 公式の明言: "Project settings in `.claude/settings.json` load only from your starting directory and are **not inherited from parent directories** the way CLAUDE.md files are."

### なぜ設定系だけネストしないか

- rules/skillsは「関連する時だけコンテキストに載せたい」もの。遅延発見する価値がある（無関係なrepoのskillが常時数百個並ぶのを防ぐ）。
- settings.jsonはコンテキストを食わない二値設定。凝った解決のインセンティブが薄い。
- **セキュリティ上も妥当**: 触ったディレクトリのhookが勝手にシェルコマンドを走らせ始めたら危険。だから設定系はcwd固定 + workspace trustダイアログで守る設計。

## 2. 名前衝突時の挙動（skills）

ネストしたskillが上位のskillと名前衝突すると、**パス接頭辞**が付く。

```
project root の .claude/skills/deploy/        → /deploy
apps/web/.claude/skills/deploy/  （衝突）     → /apps/web:deploy
```

衝突しなければ素の `/deploy` のまま使える。

## 3. 横断対応の公式推奨パターン

設定系がネストしない弱点と、指示系が散らかる問題を、公式は以下のパターンで解く。

### ① 指示の横断 → Plugin + 社内マーケットプレイス（本命）

per-directoryの `CLAUDE.md` を各所に置くのが**スケールしなくなったら**、Pluginに巻き取るのが推奨ルート。

- 規約・skill・hook・commandをPluginに固め、private リポジトリのマーケットプレイス経由で配布
- `enabledPlugins` をproject settingsに書けば**チーム全員に自動適用**
- 名前空間が `plugin-name:skill` で固定 → 衝突しない、バージョン管理できる
- 「プラットフォームチームが1箇所で所有」という統治モデル

### ② 設定（settings.json）の横断 → managed / server-managed settings

「settings.jsonはcwd 1枚で継承しない」問題の公式回答。

> "To enforce the same deny rules in every session regardless of starting directory, set them in **managed settings**, which user and project settings cannot override."

permission deny・env・sandboxを**どこで起動しても効かせたい**なら、各repoに置かずmanaged/server-managed settingsに集約する。

### ③ 「どのPluginを使うべきか」の案内 → SessionStart hook

repoごとに別Pluginを使い分ける時、起動した人間がそれを知らない隙間を埋める。

- 起動ディレクトリ → 推奨Pluginのマップをrepoにコミット
- `SessionStart` hookがマップを引き、最初に「ここではこのPluginを使え」とコンテキストに出力

### ④ クロスパッケージのファイルアクセス → `additionalDirectories` / `--add-dir`

| 追加方法 | CLAUDE.md/rules をロード | skills をロード |
|---|---|---|
| `additionalDirectories` 設定 | しない | しない |
| `--add-dir` フラグ / `/add-dir` | 環境変数 `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` 時のみ | **する（例外）** |

- 恒久・チーム共有 → `permissions.additionalDirectories` をsettings.jsonに
- 一時的 → `--add-dir`（skillも自動ロードされる）

### ⑤ worktreeのスコープ → `worktree.sparsePaths` + `symlinkDirectories`

巨大ツリーでworktreeを切る時、必要なディレクトリだけsparse-checkout。`node_modules` はsymlinkで使い回す。`.claude` をリストに含めないとroot設定がworktree内で効かない点に注意。

## 4. 起動ディレクトリの選び方

| 起動位置 | ファイルアクセス | 起動時にロードされるCLAUDE.md | 使いどころ |
|---|---|---|---|
| リポジトリroot | 全ファイル | rootのみ（子はオンデマンド） | タスクが複数パッケージに跨る |
| サブディレクトリ | そのsubtreeのみ | そのディレクトリ + 全祖先 | 作業が1パッケージに閉じる |

**結論**: 効かせたい設定がどこにあるかは「どこでClaudeを起動するか」で決まる。設定系をrepo単位で効かせたいなら、そのrepoで `cd` して起動するのが最も確実。

## 5. 実務的な指針

- 指示系（CLAUDE.md/rules/skills）は**repoごとに置けば、そのrepoを触った時だけ効く**。モノレポ構成では仕込みゼロでこの挙動が得られる。
- 設定系（permission/hook/env）だけは別管理が必要。痛みが出ているならまずここをmanaged settingsに寄せる。
- **全部を最初からPlugin化する必要はない**。公式も「まずstandaloneな `.claude/` で回し、共有が必要になったらPlugin化しろ」と推奨。

## 参考リンク

- [大規模コードベース / モノレポ設定](https://code.claude.com/docs/en/large-codebases)
- [Memory (CLAUDE.md / rules)](https://code.claude.com/docs/en/memory)
- [Skills](https://code.claude.com/docs/en/skills)
- [Settings](https://code.claude.com/docs/en/settings)
- [Plugins](https://code.claude.com/docs/en/plugins)
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Server-managed settings](https://code.claude.com/docs/en/server-managed-settings)
