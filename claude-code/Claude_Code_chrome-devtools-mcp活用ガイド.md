---
title: "Claude Code chrome-devtools-mcp活用ガイド"
category: "claude-code"
tags: [claude-code, mcp, chrome-devtools, ブラウザ操作, パフォーマンス, デバッグ]
created: 2026-06-05
updated: 2026-06-05
---

# Claude Code chrome-devtools-mcp活用ガイド

## 概要

`chrome-devtools-mcp` は Google公式が提供する MCPサーバーで、Chrome DevTools Protocol 経由でブラウザを操作できる。Claude Code から自然言語で「サイトを開いてスクショ取って」「パフォーマンス計測して」のような指示が通る。

ツール数は43個に及び、Webオートメーション・パフォーマンス分析・デバッグ・テストの全方位をカバーする。

詳細な MCP設定の前提知識は [[Claude_Code_MCPサーバー設定ガイド]] を参照。

---

## 1. インストール

### user スコープ（全プロジェクト共通）

```bash
claude mcp add chrome-devtools --scope user -- npx chrome-devtools-mcp@latest
```

### 動作確認

```bash
claude mcp list | grep chrome
# → chrome-devtools: npx chrome-devtools-mcp@latest - ✓ Connected
```

ブラウザは **ツール呼び出し時に自動起動** する。接続だけでは起動しない。

### 前提

- Node.js LTS以上
- Chrome（stable以上、安定版推奨）
- npm

---

## 2. 提供ツール一覧（43個 / 10カテゴリ）

| カテゴリ | 件数 | 代表ツール | 用途 |
|---------|------|-----------|------|
| Input Automation | 10 | `click`, `fill`, `fill_form`, `type_text`, `upload_file`, `press_key` | フォーム入力・クリック等のユーザー操作再現 |
| Navigation | 6 | `navigate_page`, `new_page`, `wait_for`, `list_pages` | ページ遷移・ライフサイクル管理 |
| Emulation | 2 | `emulate`, `resize_page` | デバイス/ビューポート模擬 |
| Performance | 3 | `performance_start_trace`, `performance_stop_trace`, `performance_analyze_insight` | パフォーマンストレース計測・分析 |
| Network | 2 | `list_network_requests`, `get_network_request` | HTTP通信モニタリング |
| Debugging | 8 | `take_screenshot`, `evaluate_script`, `list_console_messages`, `lighthouse_audit`, `screencast_start` | スクショ・コンソールログ・JS評価・Lighthouse |
| Memory | 5 | `take_heapsnapshot`, `get_heapsnapshot_summary` ほか | ヒープスナップショット分析 |
| Extensions | 5 | install/reload/trigger/uninstall/list | Chrome拡張機能の操作 |
| Third-party / WebMCP | 4 | - | ページが公開するdevtoolsの呼び出し |

---

## 3. 設定フラグ

`claude mcp add` の `--` 以降に渡せる。よく使うもの:

| フラグ | 用途 | デフォルト |
|--------|------|-----------|
| `--headless` | UI非表示で起動 | false |
| `--isolated` | 一時プロファイル使用（実行後自動削除） | false |
| `--channel` | Chromeバージョン (stable/beta/dev/canary) | stable |
| `--executable-path` | Chromeバイナリパス指定 | - |
| `--viewport` | 初期ビューポート (例: `1280x720`) | - |
| `--proxy-server` | プロキシ設定 | - |
| `--log-file` | デバッグログ出力先 | - |
| `--browser-url` | 既存Chromeに接続 | - |
| `--user-data-dir` | プロファイル保存先 | `~/.cache/chrome-devtools-mcp/` |
| `--accept-insecure-certs` | SSLエラー無視 | false |
| `--slim` | 最小ツールセット (3ツールのみ) | false |

### 設定例: headless + 隔離プロファイルで CI 向け

```bash
claude mcp add chrome-devtools --scope user -- \
  npx chrome-devtools-mcp@latest --headless --isolated
```

---

## 4. 環境変数

| 変数 | 効果 |
|------|------|
| `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1` | テレメトリ無効化 |
| `CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1` | 更新チェック無効化 |
| `CI=1` | usage statistics自動無効化 |
| `DEBUG=*` | 詳細ログ出力（`--log-file` 併用） |

`~/.zshrc.local` 等に書いておくとよい:

```sh
export CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1
export CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1
```

---

## 5. ユースケース

### 5.1 サイトのパフォーマンス計測

> "https://example.com のパフォーマンスをチェックして"

`performance_start_trace` → ページ操作 → `performance_stop_trace` → `performance_analyze_insight` で
LCP / CLS / 主要メトリクスとボトルネックレポートが返ってくる。

### 5.2 Lighthouse 監査

> "https://example.com で Lighthouse 監査して"

`lighthouse_audit` で performance / accessibility / SEO / best-practices のスコアを取得。

### 5.3 フォーム自動入力テスト

> "ログイン画面開いてダミー情報入れてエラーになるか確認"

`navigate_page` → `fill_form` → `click` → `list_console_messages` で E2E相当のチェックができる。

### 5.4 スクリーンショット取得

> "このページの全画面スクショ撮って"

`take_screenshot`（ビューポート / フルページ切替可能）。視覚的回帰の起点に使える。

### 5.5 ネットワーク通信の調査

> "このページが叩いてるAPI全部リストアップして"

`list_network_requests` で送信されたリクエスト一覧、`get_network_request` で個別の詳細取得。

### 5.6 メモリリーク調査

`take_heapsnapshot` → `get_heapsnapshot_summary` で保持されたオブジェクトの種類別集計、
`get_heapsnapshot_retainers` で参照チェーンを追える。

---

## 6. 既存Chromeに接続する運用

開発中のChromeを **Remote Debugging モード** で起動しておき、MCPからそこに接続させると、ログイン状態や拡張機能を引き継いだまま自動操作できる。

```bash
# Chrome側
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222

# MCP側設定（--browser-url 指定）
claude mcp add chrome-devtools --scope user -- \
  npx chrome-devtools-mcp@latest --browser-url http://127.0.0.1:9222
```

---

## 7. 注意点

- **ブラウザは MCP プロセスの子プロセスとして起動** する。ツール呼び出しの度に立ち上がるわけではないが、Claude Code終了時に閉じる場合あり
- 業務サイトに対して使う場合、**プロファイル分離（`--isolated` or `--user-data-dir`）** を推奨。普段使いのプロファイルを汚染しない
- 認証情報を含むサイトで使う場合は、認証画面のスクショ・スクリプト評価結果に **トークンが含まれないか** 確認すること
- CDP経由なので Chromium系（Edge等）でも `--executable-path` 指定で動作する可能性あり

---

## 参考リンク

- [chrome-devtools-mcp (GitHub)](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [[Claude_Code_MCPサーバー設定ガイド]]
