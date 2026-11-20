---
title: "Obsidian入門"
category: "development"
tags: [obsidian, note-taking, knowledge-management, markdown, pkm]
created: 2026-04-30
updated: 2026-04-30
---

# Obsidian入門

## 概要

Obsidianはローカルのmarkdownファイルを直接扱うナレッジ管理ツール。フォルダ単位（Vault）でメモを管理し、双方向リンク・グラフビュー・プラグインで自分の知識ベースを育てる用途に向く。

---

## 1. 何ができるツールか

### 基本コンセプト

- **ローカルファースト**: メモは普通の `.md` ファイル。クラウド前提ではなく、自分のディスク上のディレクトリに保存される
- **Vault**: メモを置くディレクトリ全体を「Vault」と呼ぶ。Vaultを開くと配下の `.md` を一覧・編集できる
- **双方向リンク**: `[[ページ名]]` 記法で別メモを参照すると、被リンク側からも逆引きできる
- **グラフビュー**: ノート間のリンクをネットワーク図として可視化

### 競合との違い

| ツール | 保存先 | 特徴 |
|--------|--------|------|
| Obsidian | ローカル（任意ディレクトリ） | markdown直編集、プラグイン豊富、無料（個人） |
| Notion | クラウド独自DB | DB機能リッチ、共同編集◎、ローカル編集不可 |
| Logseq | ローカル（markdown/org） | アウトライナー特化、Obsidianより構造寄り |
| Bear | クラウド（Apple独自） | Apple系UI美しい、エコシステム閉じる |

**Obsidianが向く人**: ローカルで自分の知識を長期に育てたい / git管理したい / プラグインで自分好みにカスタマイズしたい。

**Obsidianが向かない用途**: チーム共同編集（→ Notion）、構造化DB（→ Notion）、純粋なタスク管理（→ Linear/Things）。

---

## 2. インストールと最初の起動

### macOS（Homebrew）

```bash
brew install --cask obsidian
```

### 初回起動

1. 起動するとVault選択画面
2. **「フォルダをVaultとして開く」** で既存のmarkdownディレクトリを指定 OR **「新規Vault作成」** で空ディレクトリを作る
3. 既存のmarkdown群をいきなり指定してもOK（ファイルは壊さない）

### おすすめの最初の構成

```
~/notes/                  ← Vault
├── daily/                ← デイリーノート
├── topics/               ← テーマ別ノート
├── projects/             ← プロジェクト別
├── attachments/          ← 画像・添付
└── .obsidian/            ← 設定（git管理推奨）
```

---

## 3. 基本操作

### ノート作成と編集

- `Cmd+N`: 新規ノート
- `Cmd+P`: コマンドパレット（VS Code風）
- `Cmd+O`: ファイル検索（クイックスイッチャー）
- 編集モード / プレビューモード切替: `Cmd+E`

### リンク

```markdown
[[他のノート名]]              ← 内部リンク
[[他のノート名|表示テキスト]]  ← 別名表示
![[画像名.png]]               ← 画像埋め込み
[[#見出し名]]                 ← 同ノート内の見出しへ
```

### タグ

```markdown
#scala #blocking #concurrency
```

タグは検索・グラフビューでフィルタに使える。

### バックリンク

各ノートの右ペイン「Backlinks」で、そのノートを参照している他ノートが一覧表示される。

---

## 4. Vaultをgit管理する

`.obsidian/` ディレクトリが設定とプラグインを保持するので、Vault全体（メモ＋設定）をgit管理すれば複数マシン間で同期できる。

### .gitignore 例

```gitignore
.obsidian/workspace.json      # 開いてるタブ等の状態（PCごと）
.obsidian/workspace-mobile.json
.trash/                       # 削除済み（Vault内ゴミ箱）
```

`.obsidian/plugins/`、`.obsidian/themes/`、`.obsidian/snippets/` は **コミットする** とプラグイン・テーマも他マシンに引き継げる。

### 同期方法の選択肢

| 方法 | コスト | 特徴 |
|------|--------|------|
| git手動 | 無料 | コミット・プッシュ・プル全部自分でやる |
| Obsidian Git plugin | 無料 | 起動時自動pull・定期commit/push可能 |
| iCloud / Dropbox | 無料 | 単純同期、競合解決は弱い |
| Obsidian Sync（公式） | 月$4 | E2E暗号化、競合解決強、モバイル対応◎ |

エンジニアなら **git + Obsidian Git plugin** が最も安価で柔軟。

---

## 5. 必須プラグイン（コアプラグイン）

設定 → コアプラグイン から有効化。

| プラグイン | 用途 |
|-----------|------|
| Daily notes | 日付ファイルを自動生成 |
| Templates | テンプレート挿入 |
| Quick switcher | ファイル即座切替 |
| Graph view | グラフ可視化 |
| Backlinks | 被リンク表示 |
| Outline | 見出しアウトライン |
| Tag pane | タグ一覧 |

---

## 6. おすすめコミュニティプラグイン

設定 → コミュニティプラグイン → ブラウズ から検索。

| プラグイン | 用途 |
|-----------|------|
| Obsidian Git | git自動コミット・push |
| Dataview | ノートをDB的にクエリ（`TABLE FROM #tag` 等） |
| Templater | 動的テンプレート（日付・JS式埋め込み） |
| Calendar | カレンダーUIでデイリーノート遷移 |
| Excalidraw | 手書き図解 |
| Advanced Tables | 表編集アシスト |
| Periodic Notes | 週次・月次ノート自動化 |

---

## 7. デイリーノート運用の例

`daily/2026-04-30.md` のようなファイルが日付ごとに自動生成される。

### テンプレート例

```markdown
# {{date:YYYY-MM-DD}}

## やったこと
-

## 学び・メモ
-

## 明日やること
-

## リンク
-
```

毎日のメモから `[[Obsidian入門]]` のように知識ノートへリンクすれば、後から「Obsidianの調査をいつしたか」がbacklinksで辿れる。

---

## 8. 既存のmarkdownナレッジに導入する場合

すでに `~/.dotfiles/desk/knowledge-base/` のような既存markdownディレクトリがあるなら、そこを **Vaultとして開くだけ** で全ノートが利用可能になる。

### 注意点

- ファイル名やリンクの記法はObsidianに最適化されていない可能性がある
  - 既存の `[text](path/to.md)` は通常リンクとして動く
  - `[[ページ名]]` 記法はObsidian独自なので、他のツールで開く時は注意
- `.obsidian/` ディレクトリが追加で作成されるので、既存リポジトリでは `.gitignore` 調整が必要

---

## 参考リンク

- [Obsidian公式](https://obsidian.md/)
- [Obsidian Help（公式ドキュメント）](https://help.obsidian.md/)
- [Obsidian Git plugin](https://github.com/Vinzent03/obsidian-git)
- [Dataview plugin](https://blacksmithgu.github.io/obsidian-dataview/)
