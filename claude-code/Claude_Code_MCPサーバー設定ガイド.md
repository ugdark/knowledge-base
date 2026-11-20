---
title: "Claude Code MCPサーバー設定ガイド"
category: "claude-code"
tags: [claude-code, mcp, mcp-server, github, circleci, 設定]
created: 2026-02-13
updated: 2026-07-28
---

# Claude Code MCPサーバー設定ガイド

## 概要

Claude CodeにおけるMCPサーバーの設定方法を解説する。MCPサーバーは `settings.json` ではなく専用ファイルで管理される。

---

## 設定ファイルの構成

MCPサーバーの定義は `settings.json` には書かない。以下の専用ファイルで管理する。

| ファイル | スコープ | 用途 |
|---------|---------|------|
| `~/.claude.json` | user | 全プロジェクト共通の個人用MCPサーバー |
| `~/.claude.json`（プロジェクトパス配下） | local | 特定プロジェクト用の個人MCPサーバー（デフォルト） |
| `プロジェクトルート/.mcp.json` | project | チームで共有するMCPサーバー（git管理） |
| システムディレクトリ/`managed-mcp.json` | managed | IT管理者が強制するMCPサーバー |

### スコープの優先順位

local > project > user（同名サーバーは上位が優先）

### 注意点

- `~/.claude.json` は `~/.claude/` ディレクトリの中ではなく、ホームディレクトリ直下
- `~/.claude.json` はClaude Codeが自動管理するファイルのため、Stowでの管理は非推奨
- グローバルな `.mcp.json` は存在しない。全体共通は `~/.claude.json` のuserスコープが担う

## MCPサーバーの追加方法

### CLIコマンド（推奨）

```bash
# 全プロジェクト共通（userスコープ）
claude mcp add --scope user <サーバー名> \
  -e KEY=value \
  -- npx -y @scope/package@latest

# 特定プロジェクト用・個人（localスコープ、デフォルト）
claude mcp add <サーバー名> \
  -e KEY=value \
  -- npx -y @scope/package@latest

# チーム共有（projectスコープ → .mcp.json に追記）
claude mcp add --scope project <サーバー名> \
  -e KEY=${ENV_VAR} \
  -- npx -y @scope/package@latest
```

### 手動追加（.mcp.json の場合）

プロジェクトルートに `.mcp.json` を作成する。

```json
{
  "mcpServers": {
    "サーバー名": {
      "command": "npx",
      "args": ["-y", "@scope/package@latest"],
      "env": {
        "API_TOKEN": "${ENV_VAR}"
      }
    }
  }
}
```

`.mcp.json` では `${VAR}` や `${VAR:-default}` の環境変数展開が使える。

## projectスコープでのCLI追加パターン

`--scope project` を指定すると `.mcp.json` に追記される。チーム共有用。トークンは `${ENV_VAR}` で環境変数参照にする。

```bash
# GitHub（HTTP方式）
claude mcp add --scope project github \
  --transport http \
  https://api.githubcopilot.com/mcp \
  -H "Authorization: Bearer ${GITHUB_PAT}"

# CircleCI（npx方式）
claude mcp add --scope project circleci-mcp-server \
  -e CIRCLECI_TOKEN=${CIRCLECI_TOKEN} \
  -e CIRCLECI_BASE_URL=https://circleci.com \
  -- npx -y @circleci/mcp-server-circleci@latest
```

各メンバーはトークンをシェル環境変数として設定する（`~/.zshrc.local` に `export` するか `direnv` を使用）。

## 設定例: CircleCI MCPサーバー

パッケージ: `@circleci/mcp-server-circleci`

```bash
claude mcp add --scope user circleci-mcp-server \
  -e CIRCLECI_TOKEN=xxxxx \
  -e CIRCLECI_BASE_URL=https://circleci.com \
  -- npx -y @circleci/mcp-server-circleci@latest
```

| 環境変数 | 必須 | 説明 |
|---------|------|------|
| `CIRCLECI_TOKEN` | 必須 | Personal API Token（Project Tokenは不可） |
| `CIRCLECI_BASE_URL` | 任意 | デフォルト: `https://circleci.com` |

トークンは CircleCI → User Settings → Personal API Tokens で発行する。

## 設定例: GitHub MCPサーバー

リポジトリ: [github/github-mcp-server](https://github.com/github/github-mcp-server)

### 追加コマンド

```bash
# HTTPリモート方式（推奨）
claude mcp add --scope user github \
  --transport http \
  https://api.githubcopilot.com/mcp \
  -H "Authorization: Bearer YOUR_GITHUB_PAT"

# Docker方式
claude mcp add --scope user github \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT \
  -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server
```

### GitHub PAT の権限設定

#### Fine-grained PAT（推奨）

必要最小限に絞れるため、Classic PATより推奨。

**必須権限:**

| 権限 | アクセスレベル | 理由 |
|------|-------------|------|
| Contents | Read-only | ファイル・ブランチ・コミット取得 |
| Issues | Read & Write | Issue閲覧・作成・コメント |
| Pull requests | Read & Write | PR操作全般 |
| Metadata | Read-only | リポジトリ基本情報（自動付与） |

**あると便利な権限:**

| 権限 | アクセスレベル | 理由 |
|------|-------------|------|
| Actions | Read-only | CI/CDの実行状況確認 |
| Code scanning alerts | Read-only | セキュリティアラート確認 |
| Secret scanning alerts | Read-only | シークレット検知の確認 |

リポジトリ範囲は **All repositories** か **Only select repositories** を選択可能。必要なリポジトリだけに絞る方が安全。

発行先: https://github.com/settings/personal-access-tokens/new

#### Classic PAT

Fine-grainedが使えない場合の代替。粒度が荒い。

| スコープ | 理由 |
|---------|------|
| `repo` | リポジトリ操作全般（これ1つでカバー） |

### 主な機能（51ツール）

| カテゴリ | 主な操作 |
|---------|---------|
| リポジトリ | ファイル取得・作成・削除、ブランチ操作、コード検索 |
| Issue | 作成・更新・検索・コメント |
| PR | 作成・更新・diff取得・レビュー・マージ |
| Code Security | スキャンアラート確認、シークレット検知 |
| 通知 | 一覧・既読管理 |

### Claude Code側のpermissions推奨設定

`settings.json` の `permissions.allow` には読み取り系のみ追加し、書き込み系は都度確認にする。

```json
"mcp__github__get_me",
"mcp__github__get_file_contents",
"mcp__github__search_code",
"mcp__github__search_repositories",
"mcp__github__search_issues",
"mcp__github__list_branches",
"mcp__github__list_tags",
"mcp__github__list_commits",
"mcp__github__get_commit",
"mcp__github__get_issue",
"mcp__github__list_issues",
"mcp__github__get_issue_comments",
"mcp__github__get_pull_request",
"mcp__github__list_pull_requests",
"mcp__github__get_pull_request_diff",
"mcp__github__get_pull_request_files",
"mcp__github__get_pull_request_comments",
"mcp__github__get_pull_request_reviews",
"mcp__github__get_pull_request_status",
"mcp__github__list_notifications",
"mcp__github__get_notification_details",
"mcp__github__list_code_scanning_alerts",
"mcp__github__list_secret_scanning_alerts"
```

allowしない（都度確認）にすべき操作: `create_pull_request`, `merge_pull_request`, `create_issue`, `update_issue`, `add_issue_comment`, `push_files`, `create_or_update_file`, `delete_file`, レビュー系全般（他人から見える操作・元に戻しにくい操作）。

## settings.jsonでのMCP制御

MCPサーバーの定義は `~/.claude.json` や `.mcp.json` で行うが、有効/無効の制御は `settings.json` で行える。

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["github", "circleci-mcp-server"],
  "disabledMcpjsonServers": ["filesystem"]
}
```

| フィールド | 説明 |
|-----------|------|
| `enableAllProjectMcpServers` | `.mcp.json` の全サーバーを自動有効化 |
| `enabledMcpjsonServers` | 有効にするサーバー名の配列 |
| `disabledMcpjsonServers` | 無効にするサーバー名の配列 |

### Managed settings（組織管理者向け）

```json
{
  "allowedMcpServers": [
    { "serverName": "github" }
  ],
  "deniedMcpServers": [
    { "serverName": "filesystem" }
  ],
  "allowManagedMcpServersOnly": false
}
```

`allowManagedMcpServersOnly: true` にすると、Managed settingsの `allowedMcpServers` に含まれるサーバーのみ使用可能になる。

## MCP プロトコル・機能の拡張

### Elicitation（v2.1.76）

MCPサーバーがタスク実行中にユーザーへ構造化入力を要求できるようになった。サーバー側から必要な情報を問い合わせるフローが可能。

### ツール結果サイズの上書き（v2.1.91）

MCPツールの結果に `_meta["anthropic/maxResultSizeChars"]` アノテーションを付与することで、デフォルトの結果サイズ制限を最大500Kまで拡張できる。

### ツール説明・サーバーinstructionsの制限（v2.1.84）

MCPツールのdescriptionおよびサーバーinstructionsは2KBまでに制限された。

### OAuth対応

- RFC 9728 Protected Resource Metadata discoveryに準拠（v2.1.85）
- Client ID Metadata Document（CIMD / SEP-991）をサポート（v2.1.81）

### deniedMcpServersの拡張（v2.1.85）

`deniedMcpServers` がclaude.ai経由のMCPサーバーもブロック対象になった。

### サーバー重複排除（v2.1.84）

ローカル設定とclaude.aiコネクター経由で同一MCPサーバーが設定されている場合、自動的に重複排除される。

### 非同期接続モード（v2.1.89）

`MCP_CONNECTION_NONBLOCKING=true` を設定すると、`-p`（非対話）モードでMCPサーバーの接続完了を待たずに処理を開始できる。

## セキュリティ上の注意

- `.mcp.json` にトークンを直書きしてgitにコミットしない。`${ENV_VAR}` で環境変数を参照する
- トークンの実値は `~/.zshrc.local` など gitignore対象のファイルに記載する
- GitHub PATはFine-grained PATを使い、必要最小限のリポジトリ・権限に絞る

## 2026年6〜7月の変更点（追記）

- **`claude mcp login` / `claude mcp logout`**（6月下旬）: 対話メニュー（`/mcp`）を開かずシェルから設定済みMCPサーバーのOAuth認証・資格情報クリアができる。CI・スクリプトからの認証に有効
- **メモリリーク修正**（7月）: MCP stdioサーバーのstderrがサーバーあたり最大64MB蓄積するリークが修正された。長時間セッションでメモリが膨れる場合はバージョン更新を確認

## 参考リンク

- [Claude Code MCP公式ドキュメント](https://code.claude.com/docs/en/mcp)
- [GitHub MCP Server - GitHub](https://github.com/github/github-mcp-server)
- [CircleCI MCP Server - GitHub](https://github.com/CircleCI-Public/mcp-server-circleci)
- [@circleci/mcp-server-circleci - npm](https://www.npmjs.com/package/@circleci/mcp-server-circleci)
