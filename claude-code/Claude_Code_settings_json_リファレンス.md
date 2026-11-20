---
title: "Claude Code settings.json リファレンス"
category: "claude-code"
tags: [settings-json, permissions, hooks, configuration]
created: 2026-01-01
updated: 2026-07-28
---

# Claude Code settings.json リファレンス

## 概要

Claude Codeの設定ファイル `settings.json` の全フィールドリファレンス。設定ファイルの優先順位、パーミッション構文、Hooks設定、Sandbox設定などを網羅する。

---

## 1. 設定ファイルの優先順位

上位ほど優先度が高い。deny は全レベルで累積される。

| 優先度 | ファイル | スコープ | チーム共有 |
|--------|---------|---------|----------|
| 1（最高） | Managed settings（サーバー管理/plist/registry） | 組織全体 | Yes |
| 2 | コマンドラインオプション（`--allowedTools` 等） | セッション限定 | - |
| 3 | `.claude/settings.local.json` | プロジェクトローカル（gitignore推奨） | No |
| 4 | `.claude/settings.json` | プロジェクト（git管理可） | Yes |
| 5（最低） | `~/.claude/settings.json` | ユーザー全体 | No |

- permissions の allow/deny/ask は**マージ**される（上書きではなく累積）
- deny はどのレベルで設定しても他レベルで上書き不可

## 2. Permissions

### 基本構造

```json
{
  "permissions": {
    "allow": ["Bash(npm run *)"],
    "ask": ["Bash(git push *)"],
    "deny": ["Bash(rm -rf /*)"],
    "defaultMode": "default",
    "additionalDirectories": ["../docs/"]
  }
}
```

| キー | 説明 |
|------|------|
| `allow` | 確認なしで自動許可 |
| `ask` | 都度ユーザーに確認 |
| `deny` | 実行を完全に拒否 |
| `defaultMode` | パーミッションモード（後述） |
| `additionalDirectories` | 追加のアクセス先ディレクトリ |
| `disableBypassPermissionsMode` | `"disable"` で bypassPermissions を禁止（Managed only） |

評価順序: **deny → ask → allow**（最初にマッチしたルールが適用）

### パーミッションモード

```json
{ "permissions": { "defaultMode": "default" } }
```

| モード | 説明 |
|--------|------|
| `default` | 標準動作。初回使用時に確認 |
| `acceptEdits` | ファイル編集を自動承認 |
| `plan` | 読み取り専用（変更・実行不可） |
| `dontAsk` | 事前許可されたツール以外は自動拒否 |
| `bypassPermissions` | 全確認スキップ（隔離環境のみ） |

### パーミッション構文

基本形: `Tool` または `Tool(specifier)`

#### Bash

```
Bash                     # 全Bashコマンド
Bash(npm run build)      # 完全一致
Bash(npm run *)          # ワイルドカード（スペース+* でワード境界あり）
Bash(npm*)               # スペースなし（lsof等もマッチ）
Bash(git * main)         # 中間ワイルドカード
```

**注意**: 旧 `:*` 構文は非推奨。`Bash(git status *)` を使うこと。

#### Read / Edit

gitignore仕様に準拠。

| パターン | 意味 | 例 |
|---------|------|-----|
| `//path` | ファイルシステムルートからの絶対パス | `Read(//Users/alice/secrets/**)` |
| `~/path` | ホームディレクトリからのパス | `Read(~/.zshrc)` |
| `/path` | プロジェクトルートからの相対パス | `Edit(/src/**/*.ts)` |
| `path` or `./path` | カレントディレクトリからの相対パス | `Read(*.env)` |

**注意**: `/Users/alice/file` は絶対パスではなくプロジェクトルート相対。絶対パスは `//Users/alice/file`。

#### WebFetch / MCP / Agent

```
WebFetch(domain:example.com)       # ドメイン指定
mcp__puppeteer__puppeteer_navigate # MCP特定ツール
mcp__puppeteer                     # MCPサーバーの全ツール
Agent(Explore)                     # 特定サブエージェント
Skill(deploy *)                    # 特定スキル（プレフィックスマッチ）
```

## 3. Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "./scripts/validate.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write" }
        ]
      }
    ]
  }
}
```

| イベント名 | タイミング |
|-----------|-----------|
| `PreToolUse` | ツール実行前 |
| `PostToolUse` | ツール実行後 |
| `Stop` | 応答完了時 |
| `SubagentStart` | サブエージェント開始時 |
| `SubagentStop` | サブエージェント完了時 |
| `InstructionsLoaded` | 指示ファイル読み込み時 |

**注意**: イベント名はPascalCase。旧 `preToolUse` / `postToolUse` / `notification` は非推奨。

関連フィールド:

```json
{
  "disableAllHooks": false,
  "allowManagedHooksOnly": false,
  "allowedHttpHookUrls": ["https://hooks.example.com/*"],
  "httpHookAllowedEnvVars": ["CI", "NODE_ENV"]
}
```

| フィールド | 説明 |
|-----------|------|
| `disableAllHooks` | 全Hooksを無効化 |
| `allowManagedHooksOnly` | `true` でManaged/SDK hookのみ読み込み（User/Project hookを無視） |
| `allowedHttpHookUrls` | HTTP hook のターゲットURLを制限（ワイルドカード可） |
| `httpHookAllowedEnvVars` | HTTP hook 内で `$ENV_VAR` 補間を許可する環境変数名の配列 |

## 4. Sandbox

Bashコマンドに対するOS レベルのファイルシステム・ネットワーク隔離。macOSではSeatbelt、LinuxではBubblewrapを使用。Permissionsが「Claudeに何を許可するか」なのに対し、Sandboxは「Bashプロセスが何にアクセスできるか」を制御する。

### 有効化

```
/sandbox
```

### サンドボックスモード

| モード | 説明 |
|--------|------|
| **Auto-allow** | サンドボックス内のBashコマンドを自動許可。境界外アクセスは通常のpermission flowにフォールバック |
| **Regular permissions** | サンドボックス内でも全Bashコマンドに確認を要求 |

### 全フィールド

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "git"],
    "allowUnsandboxedCommands": true,
    "failIfUnavailable": false,

    "filesystem": {
      "allowWrite": ["//tmp/build", "~/.kube"],
      "denyWrite": ["//etc", "//usr/local/bin"],
      "denyRead": ["~/.aws/credentials"],
      "allowRead": ["~/.aws/config"]
    },

    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org"],
      "allowUnixSockets": ["~/.ssh/agent-socket"],
      "allowAllUnixSockets": false,
      "allowLocalBinding": true,
      "allowManagedDomainsOnly": false,
      "httpProxyPort": 8080,
      "socksProxyPort": 8081
    },

    "enableWeakerNestedSandbox": false,
    "enableWeakerNetworkIsolation": false
  }
}
```

### フィールド説明

| フィールド | 説明 |
|-----------|------|
| `enabled` | サンドボックス有効化 |
| `autoAllowBashIfSandboxed` | サンドボックス内Bashを自動許可 |
| `excludedCommands` | サンドボックス外で実行するコマンド（docker等の非互換ツール用） |
| `allowUnsandboxedCommands` | `false` でサンドボックス外実行のエスケープハッチを無効化 |
| `failIfUnavailable` | `true` でサンドボックス起動失敗時にClaude Codeを終了する（v2.1.83） |

#### filesystem

| フィールド | 説明 |
|-----------|------|
| `allowWrite` | 書き込み許可パス（デフォルト: cwdのみ） |
| `denyWrite` | 書き込み拒否パス |
| `denyRead` | 読み取り拒否パス（`Read(...)`のdenyルールとマージされる） |
| `allowRead` | `denyRead` 領域内で再許可する読み取りパス（v2.1.77） |

#### network

| フィールド | 説明 |
|-----------|------|
| `allowedDomains` | アクセス許可ドメイン（ワイルドカード可: `*.npmjs.org`） |
| `allowUnixSockets` | 許可するUnixソケットパス |
| `allowAllUnixSockets` | 全Unixソケットを許可（危険） |
| `allowLocalBinding` | ローカルポートバインドを許可 |
| `allowManagedDomainsOnly` | `true` でManaged settingsのドメインのみ許可（Managed only） |
| `httpProxyPort` / `socksProxyPort` | カスタムプロキシポート |

#### その他

| フィールド | 説明 |
|-----------|------|
| `enableWeakerNestedSandbox` | Docker内等で名前空間が使えない場合の弱いサンドボックス（セキュリティ低下） |
| `enableWeakerNetworkIsolation` | 弱いネットワーク隔離 |

### パス接頭辞

| 接頭辞 | 意味 | 例 |
|--------|------|-----|
| `//` | ファイルシステムルート | `//tmp/build` → `/tmp/build` |
| `~/` | ホームディレクトリ | `~/.kube` → `$HOME/.kube` |
| `/` | 設定ファイルのディレクトリ相対 | `/build` → `$SETTINGS_DIR/build` |
| `./` or なし | 相対パス | `./output` |

`allowWrite`/`denyWrite`/`denyRead` は複数settingsスコープ間で**マージ**される（上書きではなく累積）。

### Permissionsとの関係

| 層 | 対象 | 制御レベル |
|----|------|-----------|
| **Permissions** | 全ツール（Bash, Read, Edit, WebFetch, MCP等） | Claudeの判断レベル |
| **Sandbox** | Bashコマンドとその子プロセスのみ | OSレベル（プロンプトインジェクション耐性あり） |

両方を組み合わせることで多層防御になる。Permissionsで「Claudeが試みること」をフィルタし、Sandboxで「Bashプロセスが実際にアクセスできるもの」を強制する。

### 非互換ツールへの対処

- `docker`: サンドボックス非互換 → `excludedCommands` に追加
- `watchman` (jest): 非互換 → `jest --no-watchman` を使用
- ネットワークアクセスが必要なCLIツール: 初回アクセス時にドメイン許可を求められる

### プラットフォーム対応

| プラットフォーム | 対応状況 |
|----------------|---------|
| macOS | Seatbelt（標準搭載） |
| Linux | Bubblewrap + socat（要インストール） |
| WSL2 | Bubblewrap（Linux同様） |
| WSL1 | 非対応 |
| Windows | 今後対応予定 |

## 5. その他のフィールド

### モデル・認証

```json
{
  "model": "claude-sonnet-4-6",
  "availableModels": ["sonnet", "haiku"],
  "modelOverrides": {
    "opus": "provider/custom-opus-model"
  },
  "apiKeyHelper": "security find-generic-password -s 'claude-api-key' -w",
  "alwaysThinkingEnabled": true,
  "effortLevel": "high"
}
```

| フィールド | 説明 |
|-----------|------|
| `model` | デフォルトモデル。省略時は最新推奨モデル |
| `availableModels` | モデル切替で選択可能なモデル一覧を制限 |
| `modelOverrides` | モデルピッカーのエントリをプロバイダーのモデルIDにマッピング（v2.1.73） |
| `apiKeyHelper` | APIキーを動的取得するシェルコマンド（macOS Keychain, 1Password等と連携） |
| `alwaysThinkingEnabled` | extended thinking を常時有効化 |
| `effortLevel` | デフォルトのeffortレベル（`"low"`, `"medium"`, `"high"`） |

### 環境変数

```json
{
  "env": {
    "NODE_ENV": "development"
  }
}
```

Bash等の子プロセスに渡す環境変数。シークレットの管理には不向き（プレーンテキスト保存のため）。

### Git・Attribution

```json
{
  "attribution": {
    "commit": "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>",
    "pr": "Generated with Claude Code"
  },
  "includeGitInstructions": true
}
```

| フィールド | 説明 |
|-----------|------|
| `attribution.commit` | コミットメッセージに付与するテキスト |
| `attribution.pr` | PR説明文に付与するテキスト |
| `includeGitInstructions` | gitの使い方をシステムプロンプトに含めるか |

`includeCoAuthoredBy` は非推奨。`attribution` に移行。

### UI/UX

```json
{
  "language": "japanese",
  "outputStyle": "Explanatory",
  "showTurnDuration": true,
  "spinnerTipsEnabled": true,
  "terminalProgressBarEnabled": true,
  "prefersReducedMotion": false,
  "showThinkingSummaries": false,
  "showClearContextOnPlanAccept": true,
  "tui": "default",
  "statusLine": {
    "refreshInterval": 30000
  }
}
```

| フィールド | 説明 |
|-----------|------|
| `language` | 応答言語（`"japanese"`, `"english"` 等） |
| `outputStyle` | 出力スタイル（`"Explanatory"` 等） |
| `showTurnDuration` | ターンの所要時間を表示 |
| `spinnerTipsEnabled` | スピナー中のTipsを表示 |
| `terminalProgressBarEnabled` | ターミナルのプログレスバーを表示 |
| `showThinkingSummaries` | extended thinkingの要約を表示（v2.1.89、デフォルト: `false`） |
| `showClearContextOnPlanAccept` | Plan承認時にclear context選択肢を表示（v2.1.81） |
| `tui` | ターミナルUIレンダラー（`"fullscreen"` or `"default"`）（v2.1.89+） |
| `statusLine.refreshInterval` | ステータスラインの再実行間隔（ミリ秒）（v2.1.97） |

### Plugin

```json
{
  "enabledPlugins": {
    "formatter@acme-tools": true,
    "analyzer@security-plugins": false
  },
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": { "source": "github", "repo": "acme-corp/plugins" }
    }
  }
}
```

| フィールド | 説明 |
|-----------|------|
| `enabledPlugins` | プラグインの有効/無効を `プラグイン名@マーケットプレイス` で制御 |
| `extraKnownMarketplaces` | 追加のプラグインマーケットプレイス定義 |
| `allowedChannelPlugins` | チャネルプラグインの許可リスト（v2.1.84、Managed only） |
| `channelsEnabled` | Team/Enterprise向けチャネル機能の有効化（v2.1.84、Managed only） |

マーケットプレイスソース: `github`, `git`, `npm`, `url`, `file`, `directory`

### MCP制御

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["github"],
  "disabledMcpjsonServers": ["filesystem"]
}
```

| フィールド | 説明 |
|-----------|------|
| `enableAllProjectMcpServers` | `.mcp.json` の全サーバーを自動有効化 |
| `enabledMcpjsonServers` | 有効にするサーバー名の配列 |
| `disabledMcpjsonServers` | 無効にするサーバー名の配列 |

MCPサーバーの定義自体は `~/.claude.json` や `.mcp.json` で行う。settings.jsonでは有効/無効の制御のみ。

### セッション・クリーンアップ

```json
{
  "cleanupPeriodDays": 30,
  "fastModePerSessionOptIn": true,
  "autoMemoryDirectory": "~/.claude/memory",
  "autoUpdatesChannel": "stable",
  "fileSuggestion": "./scripts/suggest-files.sh"
}
```

| フィールド | 説明 |
|-----------|------|
| `cleanupPeriodDays` | セッショントランスクリプトの保持日数（デフォルト: 30日） |
| `fastModePerSessionOptIn` | Fast modeをセッション開始時にオプトイン方式にする |
| `autoMemoryDirectory` | auto-memoryの保存ディレクトリパス（v2.1.74） |
| `autoUpdatesChannel` | 自動更新チャネル（`"stable"` or `"latest"`） |
| `fileSuggestion` | `@` ファイル補完のカスタムスクリプトパス |

### 企業向け（Managed only）

組織管理者がManaged settingsでのみ設定できるフィールド。

```json
{
  "companyAnnouncements": ["社内ガイドラインを確認してください"],
  "allowManagedPermissionRulesOnly": false,
  "allowManagedHooksOnly": false,
  "allowManagedMcpServersOnly": false,
  "disableBypassPermissionsMode": "disable",
  "disableAutoMode": false,
  "disableSkillShellExecution": false,
  "disableDeepLinkRegistration": false,
  "forceRemoteSettingsRefresh": false,
  "autoMode": {
    "environment": ["CI=true"],
    "allow": ["Bash(npm test *)"],
    "soft_deny": ["Bash(rm *)"]
  }
}
```

| フィールド | 説明 |
|-----------|------|
| `companyAnnouncements` | セッション開始時に表示する社内告知 |
| `allowManagedPermissionRulesOnly` | `true` でUser/Projectのpermissionルールを無視 |
| `allowManagedHooksOnly` | `true` でManaged以外のHooksを無効化 |
| `allowManagedMcpServersOnly` | `true` で許可されたMCPサーバーのみ有効化 |
| `disableBypassPermissionsMode` | `"disable"` で bypassPermissions モードを禁止 |
| `autoMode` | autoモードの分類ルール設定。`environment`（環境条件）、`allow`（許可ルール）、`soft_deny`（ソフト拒否ルール）の配列（v2.1.83） |
| `disableAutoMode` | `true` でautoモードの有効化を阻止（v2.1.83） |
| `disableSkillShellExecution` | `true` でスキル/コマンド内のシェル実行を無効化（v2.1.91） |
| `forceRemoteSettingsRefresh` | `true` でManaged settings取得失敗時にClaude Codeの起動をブロック（fail-closed）（v2.1.92） |
| `disableDeepLinkRegistration` | `true` で `claude-cli://` URIスキームの登録を阻止（v2.1.83） |

## 6. 設定の確認方法

```
/status           # 有効な設定ソースを表示
/permissions      # パーミッションルール一覧
/memory           # CLAUDE.md / rules / auto memory の一覧
```

## 7. 2026年5〜7月の変更点（追記）

- **パラメータ条件付きルール**: deny/askルールで `Tool(param:value)` 形式が使える（例: `Agent(model:opus)`）
- **`fallbackModel`**: フォールバックモデルを最大3つまで順に試行する設定が追加
- **`worktree.baseRef`**: 新規worktreeの分岐元をリモートデフォルト/ローカルHEADから選択可能
- **バージョン要求**: managed deployments で許可するClaude Codeバージョン範囲を強制できる
- **`/config key=value`**: プロンプトから任意の設定を直接変更可能（`-p` モードでも）
- **権限まわりの修正（重要）**: 単一セグメントの `dir/**` allowルールがネストした書き込みまで自動許可していた問題が修正された。既存のallowルールが「思ったより広く許可していた」可能性があるので棚卸し推奨。Bashチェックは1万字超のコマンドや複雑なリダイレクトでfail closed（拒否側に倒す）になった

## 参考リンク

- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Configure permissions](https://code.claude.com/docs/en/permissions)
- [Sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog)
