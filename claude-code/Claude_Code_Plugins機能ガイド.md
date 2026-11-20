---
title: "Claude Code Plugins機能ガイド"
category: "claude-code"
tags: [Claude-Code, Plugins, 配布, 拡張機能]
created: 2026-03-06
updated: 2026-07-28
---

# Claude Code Plugins機能ガイド

## 概要

Pluginsは、Skills・Sub-agents・Hooks・MCPサーバーをパッケージ化して配布する仕組み。チームや外部への共有が必要な時に使う。個人用やプロジェクト固有なら`.claude/`直置きで十分。

---

## 1. Standalone vs Plugin

| 方式 | スキル名 | 適したケース |
|------|---------|-------------|
| **Standalone** (`.claude/`) | `/hello` | 個人ワークフロー、プロジェクト固有、実験 |
| **Plugin** | `/plugin-name:hello` | チーム共有、コミュニティ配布、バージョン管理 |

→ まず `.claude/` で作り、共有が必要になったらPluginに変換するのが推奨。

## 2. ディレクトリ構造

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      # マニフェスト（必須）
├── skills/              # Agent Skills
│   └── review/
│       └── SKILL.md
├── agents/              # Sub-agents
│   └── reviewer.md
├── commands/            # コマンド（Skills形式）
├── hooks/
│   └── hooks.json       # Hooks設定
├── .mcp.json            # MCPサーバー設定
├── .lsp.json            # LSPサーバー設定
└── settings.json        # デフォルト設定
```

**注意**: `skills/`, `agents/` 等はプラグインルートに置く。`.claude-plugin/` の中には `plugin.json` だけ。

## 3. マニフェスト（plugin.json）

```json
{
  "name": "my-plugin",
  "description": "プラグインの説明",
  "version": "1.0.0",
  "author": {
    "name": "Your Name"
  }
}
```

`name` がスキルの名前空間になる（例: `/my-plugin:review`）。

## 4. ローカルテスト

```bash
claude --plugin-dir ./my-plugin
```

複数プラグインの同時ロードも可能。

```bash
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two
```

## 5. 配布方法

- **Plugin Marketplace**: 公式マーケットプレイスに提出
- **チームマーケットプレイス**: リポジトリレベルでプラグインを共有
- **`/plugin install`**: マーケットプレイスからインストール

## 6. Standaloneからの移行

```bash
mkdir -p my-plugin/.claude-plugin
# plugin.json を作成
cp -r .claude/skills my-plugin/
cp -r .claude/agents my-plugin/
# hooks は hooks/hooks.json に移動
```

## 7. Plugin機能の拡張

### 実行バイナリの同梱（v2.1.91）

プラグインの `bin/` ディレクトリに実行ファイルを配置して配布できるようになった。

### Pluginオプションの外部公開（v2.1.83）

`manifest.userConfig` で定義したプラグインオプションが外部から参照可能になった。

### 永続データディレクトリ（v2.1.78）

`${CLAUDE_PLUGIN_DATA}` 変数でプラグイン固有の永続ストレージパスを取得できる。

### Agentフロントマター拡張（v2.1.78）

プラグイン内のエージェント定義で `effort`, `maxTurns`, `disallowedTools` フロントマターが使用可能になった。

### スキル宣言の改善（v2.1.94）

`"skills": ["./"]` で宣言されたプラグインスキルが、フロントマターの `name` を使用するようになった。

### settings.jsonでのプラグイン宣言（v2.1.80）

`source: 'settings'` により、マーケットプレイスを経由せず `settings.json` 内にプラグインをインラインで宣言できる。

### Channels（v2.1.80 research preview）

MCPサーバーからセッションにメッセージをプッシュできるChannels機能がresearch previewとして追加された。

### Managed settings拡張

- `allowedChannelPlugins`: Channelsの利用を許可するプラグインの制御
- `blockedMarketplaces`: 特定マーケットプレイスのブロック
- `managed-settings.d/` ドロップインディレクトリによる設定分割が可能（v2.1.83）

## 8. 2026年5〜6月の変更点（追記）

- **.zip / URL からのロード**（5月上旬）: `--plugin-dir` が `.zip` アーカイブを受け付け、`--plugin-url` でリモートのプラグインアーカイブをセッション単位で取得できる。git repo経由以外の配布経路が増えた
- **`/plugin list`**（6月上旬）: インストール済みプラグインの一覧をインライン表示
- **security-guidance プラグイン**（5月下旬）: Claudeの変更を作業中に脆弱性レビューする公式プラグイン

## 参考リンク

- [Create plugins](https://code.claude.com/docs/en/plugins)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
