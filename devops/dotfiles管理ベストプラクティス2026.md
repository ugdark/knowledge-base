---
title: "dotfiles管理 ベストプラクティス（2026年版）"
category: "devops"
tags: [dotfiles, GNU Stow, chezmoi, シンボリックリンク, macOS]
created: 2026-02-09
updated: 2026-04-17
---

# dotfiles管理 ベストプラクティス（2026年版）

## 概要

dotfilesの管理手法を網羅的に調査・比較したドキュメント。ディレクトリ構成パターン、管理ツール、セットアップスクリプト設計、会社設定と個人設定の分離方法など、2026年時点でのベストプラクティスをまとめる。

---

## ディレクトリ構成パターン

### パターン1: トピック別構成（GNU Stow方式）

アプリケーションごとにパッケージ化。各パッケージ内でホームディレクトリからの相対パスを再現する。

```
~/.dotfiles/
├── zsh/
│   └── .zshrc
├── git/
│   └── .gitconfig
├── vim/
│   └── .vimrc
├── nvim/
│   └── .config/
│       └── nvim/
│           └── init.vim
├── tmux/
│   └── .tmux.conf
└── ssh/
    └── .ssh/
        └── config
```

- `stow zsh` → `~/.zshrc` にシンボリックリンク
- `stow */` で一括適用
- **メリット**: ツールごとに独立管理、部分適用が可能
- **デメリット**: ネストが深くなる

### パターン2: home反映型

dotfiles内に`home/`ディレクトリを作り、`$HOME`と対称関係に配置する。設定ファイルとインストールスクリプトの区別が明確。

```
dotfiles/
├── home/
│   ├── .config/
│   │   ├── nvim/
│   │   └── zsh/
│   │       └── .zshrc
│   ├── .gitconfig
│   └── .zshenv
├── scripts/
│   └── install.sh
├── Brewfile
└── README.md
```

- **メリット**: `$HOME`との対応が一目瞭然
- **デメリット**: 1階層深くなる

### パターン3: フラット構成（シンプル）

設定ファイルをそのまま並べ、install.shでシンボリックリンクを張る。

```
dotfiles/
├── zshrc          → ~/.zshrc
├── gitconfig      → ~/.gitconfig
├── vimrc          → ~/.vimrc
├── install.sh
├── Brewfile
└── README.md
```

- **メリット**: 最もシンプル、小規模なら十分
- **デメリット**: ファイルが増えると管理しづらい

### パターン4: 階層構造（マルチ環境対応）

OS・アーキテクチャ・環境ごとに階層を分け、下位→上位の順に適用する。

```
dotfiles/
├── common/          ← 全環境共通
│   ├── .zshrc-common
│   └── .gitconfig
├── Darwin/          ← macOS共通
│   └── .zshrc
├── Darwin--arm64/   ← Apple Silicon Mac
│   └── Brewfile
├── company/         ← 会社環境（非公開）
│   └── .zshrc-work
└── install.sh
```

適用例（会社のMacbook Pro）: `common` → `Darwin` → `Darwin--arm64` → `company`

- **メリット**: 複数マシン・複数環境に柔軟対応
- **デメリット**: 構成が複雑

### パターン5: chezmoi管理

```
~/.local/share/chezmoi/
├── dot_zshrc              → ~/.zshrc
├── dot_gitconfig.tmpl     → ~/.gitconfig（テンプレート）
├── private_dot_ssh/       → ~/.ssh/（暗号化）
├── .chezmoiexternal.toml
└── .chezmoi.toml.tmpl     ← マシン変数定義
```

- **メリット**: テンプレート、暗号化、マルチマシン、パスワードマネージャ連携
- **デメリット**: chezmoi固有の命名規則（`dot_`, `private_`等）の学習コスト

## ファイルの分割指針

### いつ分割するか
- **1500行を超えたら分割**を検討（Qiita yutkat記事より）
- 例: `.vim/rc/` に `base.vim`, `keyconfig.vim`, `pluginconfig.vim` と分割

### 何を管理すべきか / すべきでないか

| 管理すべき | 管理すべきでない |
|-----------|----------------|
| シェル設定（.zshrc等） | 認証ディレクトリ（.ssh, .aws） |
| エディタ設定（.vimrc等） | トークン・API鍵・パスワード |
| Git設定（.gitconfig等） | 動的生成されるファイル |
| ターミナル設定 | アプリが自動生成するキャッシュ |
| Brewfile | 巨大なバイナリ |
| インストールスクリプト | |
| AI設定（CLAUDE.md, .claude/） | |

## .gitignoreの設計

### ホワイトリスト方式（推奨）

プラグイン等が勝手にファイルを作ることがあるため、**全無視→許可リスト**が安全。

```gitignore
# まず全て無視
/*
/.**

# 管理するファイルだけ許可
!/.zshrc
!/.gitconfig
!/.vimrc
!/Brewfile
!/install.sh
!/README.md
```

### ブラックリスト方式（シンプル）

```gitignore
.tmp/
*.local.sh
office.sh
.ssh/
.aws/
```

## 管理ツールの比較

| ツール | 方式 | 向いてるケース |
|--------|------|---------------|
| **シンボリックリンク（自作スクリプト）** | ln -s | 小規模、カスタマイズ自由 |
| **GNU Stow** | シンボリックリンクファーム | トピック別管理、中規模 |
| **chezmoi** | テンプレート + コピー | マルチマシン、シークレット管理 |
| **bare git repo** | $HOME直下をgit管理 | ツール不要主義 |
| **yadm** | git wrapper | bare git repoの使いやすい版 |

## セットアップスクリプトの構成

よくある分割パターン:
```
scripts/
├── install.sh        ← メインエントリポイント
├── brew.sh           ← Homebrew + Brewfile
├── link.sh           ← シンボリックリンク作成
├── macos.sh          ← macOS固有設定（defaults write等）
└── utils.sh          ← 共通ヘルパー関数
```

**冪等性が重要**: 何度実行しても同じ結果になるようにする（存在チェック→スキップ）。

## 会社設定と個人設定の分離

### A. `.local` ファイルパターン（最もシンプル）
```bash
# ~/.zshrc の末尾
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```
- 本体はpublic、`.local`ファイルはgitignore

### B. 階層構造パターン
- `common/` + `company/`（非公開）で分離
- install.shで両方適用

### C. 別リポジトリパターン
```
dotfiles/        ← public（汎用設定）
dotfiles-work/   ← private（会社設定）
```

## Homebrew 5.1.0（2026年3月10日リリース）

- **`brew bundle` の管理範囲拡大**: Rust Cargoパッケージ、uvツール、Flatpakアプリケーションもブundle管理対象に
- **`brew version-install` コマンド**: 古いformulaバージョンを明示的にインストール可能に
- **`-full` formulaバリアント**: `ffmpeg-full` のように全オプション有効のバリアントを提供
- **並列ダウンロード**: インストール前にダウンロードを並列実行（`HOMEBREW_DOWNLOAD_CONCURRENCY=auto` がデフォルト）
- **Portable Ruby 4.0.1にアップグレード**: Ruby 4.0ベースに移行
- **今後の予定**: 2026年9月にmacOS Intel x86_64がTier 3へ移行（ボトルのビルド停止）

## 2026年の傾向

- **AIエージェント設定もdotfilesに含める**（CLAUDE.md、`.claude/`設定等）
- **aqua**（ツールバージョン管理）+ **go-task**（タスクランナー）の組み合わせが台頭
- **セットアップの冪等性**を重視

## 参考リンク

- [ようこそdotfilesの世界へ（Qiita yutkat）](https://qiita.com/yutkat/items/c6c7584d9795799ee164)
- [複数の環境に適応する、階層構造のdotfiles](https://memo.yammer.jp/posts/layered-dotfiles)
- [dotfilesリポジトリの式年遷宮](https://zenn.dev/raki/articles/2026-01-08_dotfiles)
- [A Simple Guide to Organizing Your Dotfiles](https://www.trihargianto.com/blog/a-simple-guide-to-organizing-your-dotfiles/)
- [なぜchezmoiが最強のdotfiles管理ツールなのか?](https://zenn.dev/smasato/articles/e382902ec4aa17)
- [The Ultimate Guide to Mastering Dotfiles](https://www.daytona.io/dotfiles/ultimate-guide-to-dotfiles)
- [GitHub does dotfiles](https://dotfiles.github.io/)
- [awesome-dotfiles](https://github.com/webpro/awesome-dotfiles)
- [Manage Your Dotfiles Like a Superhero](https://www.jakewiesler.com/blog/managing-dotfiles)
