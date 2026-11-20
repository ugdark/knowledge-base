---
title: "mise活用ガイド 環境変数・タスク・フック"
category: "devops"
tags: [mise, 環境変数, タスク, hooks, direnv代替]
created: 2026-03-02
updated: 2026-07-28
---

# mise活用ガイド 環境変数・タスク・フック

## 概要

miseのツール管理以外の機能をまとめたガイド。環境変数管理（direnv代替）、タスクランナー（Makefile/just代替）、フック（ディレクトリ連動）の3機能を扱う。

---

## 1. 環境変数管理（direnv代替）

プロジェクトごとの環境変数をmise.tomlで管理できる。`cd`するだけで自動切替。

### 基本設定

```toml
# プロジェクトの mise.toml
[env]
NODE_ENV = "development"
API_BASE = "http://localhost:3000"
```

### .envファイル連携

```toml
[env]
_.file = ".env"

# 複数ファイル・複数形式にも対応
_.file = [".env", ".env.local", "config.json"]
```

### 秘密情報の保護

```toml
[env]
# mise env の出力で値がマスクされる
SECRET_KEY = { value = "actual-value", redact = true }

# ファイルごとredact
_.file = [{ path = ".secrets", redact = true }]
```

### 必須変数の強制

```toml
[env]
DATABASE_URL = { required = "DATABASE_URLを設定してください" }
```

未設定のまま`cd`するとエラーメッセージが表示される。チーム開発で設定漏れを防ぐのに有効。

### シェル展開

```toml
[settings]
env_shell_expand = true

[env]
MY_LIB = "{{config_root}}/lib"
LD_LIBRARY_PATH = "$MY_LIB:$LD_LIBRARY_PATH"
```

サポート構文: `$VAR`、`${VAR}`、`${VAR:-default}`

### CLI操作

```bash
# 環境変数の設定・解除
mise set NODE_ENV=development
mise unset NODE_ENV

# 現在の環境変数を確認
mise env
```

---

## 2. Tasks（タスクランナー）

Makefile/justの代替。プロジェクトのビルド・テスト等をmise.tomlで定義し、`mise run`で実行する。

### 基本定義

```toml
[tasks.test]
description = "テスト実行"
run = "npm test"

[tasks.lint]
description = "Lint実行"
run = "npm run lint"

[tasks.format]
description = "フォーマット"
run = "prettier --write ."
```

### 依存関係（デフォルト並列実行）

```toml
[tasks.check]
description = "lint + test を並列実行"
depends = ["lint", "test"]

[tasks.deploy]
description = "check後にデプロイ"
depends = ["check"]
run = "deploy.sh"
```

`depends`に指定したタスクは**デフォルトで並列実行**される。設定不要。

### ファイルタスク（mise-tasks/）

`mise-tasks/`ディレクトリに実行可能スクリプトを配置する方式もある。

```bash
#!/usr/bin/env bash
#MISE description="Build the CLI"
#MISE depends=["lint"]
cargo build
```

### 実行コマンド

```bash
mise run test           # タスク実行
mise run check          # 依存タスクも含めて実行
mise tasks              # タスク一覧
mise watch -t test      # ファイル変更で自動実行
mise run test -- --verbose  # 引数付き実行
```

### タスク実行時の環境変数

| 変数 | 内容 |
|------|------|
| `MISE_TASK_NAME` | タスク名 |
| `MISE_CONFIG_ROOT` | mise.tomlのあるディレクトリ |
| `MISE_TASK_FILE` | タスクスクリプトのパス |

---

## 3. Hooks（自動実行フック）

ディレクトリ移動やツールインストール時にコマンドを自動実行できる。

### フックイベント一覧

| イベント | 発火タイミング |
|----------|---------------|
| `enter` | プロジェクトに初回進入時 |
| `leave` | プロジェクトから離脱時 |
| `cd` | ディレクトリ変更のたび |
| `preinstall` | ツールインストール前 |
| `postinstall` | ツールインストール後 |

### 基本設定

```toml
[hooks]
enter = "echo 'Welcome to project'"
leave = "echo 'Leaving project'"
```

### タスク連携

```toml
[hooks]
enter = { task = "setup" }

[tasks.setup]
description = "プロジェクト初期セットアップ"
run = "npm install"
```

プロジェクトに`cd`するだけで`npm install`が走る。

### ツール別postinstall

```toml
[tools]
node = { version = "24", postinstall = "npm install -g pnpm" }
```

### ファイル監視

```toml
[[hooks.watch_files]]
patterns = ["src/**/*.rs"]
run = "cargo fmt"
```

---

## プロジェクト別mise.tomlの運用例

グローバル設定とプロジェクト設定を組み合わせて使う。

```
~/.config/mise/config.toml        ← グローバル（ツールのデフォルトバージョン）
~/Works/projectA/mise.toml        ← projectA固有（ツール + 環境変数 + タスク）
~/Works/projectB/mise.toml        ← projectB固有
```

`cd`でプロジェクトに入るだけで、ツールバージョン・環境変数・タスクがすべて切り替わる。

```toml
# ~/Works/projectA/mise.toml の例
[tools]
node = "22.22.0"

[env]
NODE_ENV = "development"
_.file = ".env"

[tasks.dev]
description = "開発サーバー起動"
run = "npm run dev"

[tasks.test]
description = "テスト実行"
run = "npm test"

[hooks]
enter = { task = "setup" }

[tasks.setup]
description = "依存インストール"
run = "npm install"
```

---

## Tasksのmonorepo対応（2026-07追記）

タスクランナーがmonorepoを正式サポートした（本記事執筆後の機能）。

- **`:task` 構文**でパッケージ横断のタスク参照: `mise run :packages/api:build`
- **`...` パターンマッチ**で複数パッケージの一括実行
- Turborepo / Nx に近い使い勝手をmiseのシンプルさのまま実現する位置づけ

## 参考リンク

- [mise公式: Environments](https://mise.jdx.dev/environments/)
- [mise公式: Tasks](https://mise.jdx.dev/tasks/)
- [mise公式: Hooks](https://mise.jdx.dev/hooks.html)
- [mise公式: Task Configuration](https://mise.jdx.dev/tasks/task-configuration.html)
- [mise運用マニュアル](mise運用マニュアル.md)
