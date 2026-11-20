---
title: "mise 運用マニュアル"
category: "devops"
tags: [mise, バージョン管理, Node.js, Java, yarn, dotfiles]
created: 2026-02-20
updated: 2026-07-28
---

# mise 運用マニュアル

## 概要

mise（mise-en-place）はRust製のランタイムバージョンマネージャ。asdfの上位互換として、複数言語・ツールのバージョンを一元管理する。当環境ではanyenv + volta + SDKMANの3ツール体制から移行済み。

---

## 現在の管理対象

| ツール | グローバルバージョン | 備考 |
|--------|---------------------|------|
| Java | zulu-21.48.17.0 (JDK 21.0.10) | Azul Zulu LTS |
| Node.js | 24.13.1 | プロジェクト用に22.22.0もインストール済み |
| yarn | 4.12.0 | mise管理 |
| safe-chain | latest | npmバックエンド経由 |
| sbt | 1.12.3 | Homebrew管理（miseではない） |

---

## 基本コマンド

### バージョン確認

```bash
# インストール済みの全ツール一覧
mise list

# 現在有効なバージョン
mise current

# リモートの利用可能バージョン一覧
mise ls-remote node
mise ls-remote java | grep zulu
```

### インストール

```bash
# 特定バージョンをインストール
mise install node@22.22.0
mise install java@zulu-21.48.17.0

# npmパッケージをインストール
mise install npm:@aikidosec/safe-chain
```

### グローバルデフォルト設定

```bash
# グローバルに設定（~/.config/mise/config.tomlに記録）
mise use -g node@24.13.1
mise use -g java@zulu-21.48.17.0
mise use -g "npm:@aikidosec/safe-chain@latest"
```

### プロジェクト固有のバージョン設定

```bash
# プロジェクトルートで実行（.mise.tomlが生成される）
cd ~/Works/my-project
mise use node@22.22.0
```

---

## 設定ファイル

### グローバル設定

パス: `~/.config/mise/config.toml`（dotfiles管理、stow経由でシンボリックリンク）

```toml
[tools]
java = "zulu-21.48.17.0"
node = "24.13.1"
yarn = "4.12.0"
"npm:@aikidosec/safe-chain" = "latest"
```

実体: `~/.dotfiles/settings/mise/.config/mise/config.toml`

### プロジェクト設定

プロジェクトルートに `.mise.toml` または `.tool-versions` を配置。

```toml
# .mise.toml（mise独自形式、環境変数やタスクも定義可能）
[tools]
node = "22.22.0"

[env]
DATABASE_URL = "postgres://localhost/mydb"
```

```
# .tool-versions（asdf互換形式、シンプル）
node 22.22.0
java zulu-21.48.17.0
```

### .sdkmanrc互換

既存プロジェクトの `.sdkmanrc` はmiseが自動で読み取る。移行作業不要。

---

## dotfilesとの統合

### ディレクトリ構造

```
~/.dotfiles/settings/mise/
└── .config/
    └── mise/
        └── config.toml    ← stowでシンボリックリンク
```

### stowコマンド

```bash
stow -d ~/.dotfiles/settings -t $HOME mise
```

### gitignore_global

`.mise.toml` と `.tool-versions` はグローバルで除外設定済み。プロジェクトでコミットしたい場合はプロジェクトの `.gitignore` で除外解除する。

---

## 新しいマシンでのセットアップ

```bash
# 1. dotfiles clone & install（Brewfileでmiseがインストールされる）
git clone https://github.com/ugdark/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/scripts/install.sh

# 2. stowでconfig.tomlがリンクされた状態で
mise install
# → config.tomlに記載された全ツールが一括インストール
```

---

## よくある操作

### 言語・ツールの追加

```bash
# 例: Goを追加
mise use -g go@latest

# 例: Python を追加
mise use -g python@3.12
```

`mise use -g` でconfig.tomlに自動記録 → gitで差分管理。

### バージョンのアップグレード

```bash
# 利用可能な最新を確認
mise ls-remote node | tail -5

# インストール&切替
mise use -g node@24.14.0
```

### 不要バージョンの削除

```bash
# 古いバージョンを削除
mise uninstall node@22.14.0

# 使われていないバージョンを一括削除
mise prune
```

---

## トラブルシューティング

### miseが有効にならない

`.zshrc` に以下があるか確認:

```bash
eval "$(mise activate zsh)"
```

### プロジェクトでバージョンが切り替わらない

```bash
# プロジェクトルートで確認
mise current
mise doctor
```

### npmグローバルパッケージの追加

```bash
# npm install -g ではなく mise use -g を使う
mise use -g "npm:package-name@latest"
```

---

## 最近のアップデート（v2026.3.x〜v2026.4.x）

最新バージョン: **v2026.4.15**（2026-04-16リリース）

### v2026.4.x

- **OS/アーキテクチャ複合フィルタリング**: `macos/arm64` のような形式でプラットフォームを指定可能に（v2026.4.12）
- **タスク確認プロンプトのデフォルト変更**: 破壊的操作の確認プロンプトがデフォルト"no"に
- **npm `--min-release-age` サプライチェーン保護**: npmバックエンドで最低リリース経過日数を指定可能。サプライチェーン攻撃対策（v2026.4.12）
- **クロスデバイスツールインストール**: デバイス間のツールインストール時にcopy+removeフォールバックが追加（v2026.4.9）

### v2026.3.x

- **GitHubトークン自動検出**: gh CLIの `hosts.yml` からGitHubトークンを自動取得（v2026.3.11）
- **`mise run --skip-tools`**: タスク実行時にツールの自動インストール/アクティベーションをスキップ可能（v2026.3.11）
- **プリコンパイル済みRubyバイナリが安定版に**: 2026.8.0でデフォルトになる予定

---

## 2026.7系のアップデート（2026-07追記）

- **bootstrap package manager plugins**: vfox Luaプラグインがシステムパッケージマネージャとして動作可能に。`[bootstrap.plugins]` で宣言的に設定
- **HTTP backend強化**: Teraテンプレート完全対応・JSONフィルタでのバージョン抽出・`version_expr` による複雑なバージョンパース
- **並列インストールの改善**: アーカイブ展開やmacOSの hdiutil/pkgutil 待ちが実行スレッドを塞がなくなり、並列インストール時のダウンロード進捗が正常化
- 会社ベースライン環境（`~/.local/bin/mise` 優先・conf.dレイヤ）との共存構成は dotfiles 側で対応済み

## 参考

- [mise公式ドキュメント](https://mise.jdx.dev/)
- [Comparison to asdf](https://mise.jdx.dev/dev-tools/comparison-to-asdf.html)
- [npm Backend](https://mise.jdx.dev/dev-tools/backends/npm.html)
- ADR: `docs/adr/20260220_01_バージョンマネージャをmiseに統一.md`
