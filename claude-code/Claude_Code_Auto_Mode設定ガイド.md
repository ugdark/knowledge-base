---
title: "Claude Code Auto Mode設定ガイド"
category: "claude-code"
tags: [Claude Code, Auto Mode, パーミッション, セキュリティ]
created: 2026-04-17
updated: 2026-07-28
---

# Claude Code Auto Mode設定ガイド

## 概要

Auto Mode（Research Preview、v2.1.83〜）は、ツール実行の許可判断を自動化する機能。安全なアクションは中断なしで実行し、リスクのあるアクションはブロックする。`--dangerously-skip-permissions`と手動承認の中間に位置する。

---

## 1. Auto Modeとは

従来のパーミッションモデル:

| モード | 動作 |
|--------|------|
| 通常 | ツール実行のたびにユーザー承認を求める |
| `--dangerously-skip-permissions` | 全てのツール実行を無条件で許可（危険） |
| **Auto Mode** | パーミッション分類器が自動判断。安全→実行、危険→ブロック |

## 2. 有効化

### インタラクティブに有効化

セッション中に切り替え可能（具体的なUIは今後変更の可能性あり）。

### settings.jsonで設定

```json
{
  "permissions": {
    "defaultMode": "auto"
  }
}
```

### 無効化（管理者向け）

```json
{
  "disableAutoMode": "disable"
}
```

## 3. autoMode設定

`autoMode`オブジェクトで分類器のルールをカスタマイズできる。

```json
{
  "autoMode": {
    "environment": ["..."],
    "allow": ["..."],
    "soft_deny": ["..."]
  }
}
```

| フィールド | 説明 |
|-----------|------|
| `environment` | 環境に関する追加コンテキスト |
| `allow` | 自動許可するツールパターン |
| `soft_deny` | ブロックするが、ユーザーが手動で許可可能 |

## 4. 通常のパーミッションとの関係

| 設定 | 優先度 |
|------|--------|
| `permissions.deny` | 最優先。Auto Modeでもブロック |
| `permissions.allow` | Auto Modeより先に評価 |
| Auto Mode分類器 | allow/denyに該当しないツール実行を判断 |

つまり`deny`で明示的にブロックしているものはAuto Modeでも実行されない。

## 5. 関連フック

- **`PermissionDenied`フック**（v2.1.89）— Auto Modeがブロックした際に発火。`{retry: true}`を返すとリトライ可能

## 6. 注意事項

- **Research Preview** — 今後仕様が変更される可能性がある
- パーミッション分類器の判断は完璧ではない。本番環境では`deny`ルールとの併用を推奨
- `disableAutoMode`はManaged設定（組織管理者が設定）

## 7. 2026年5〜7月の変更点（追記）

- **Proプランで利用可能に**（5月中旬）。Opusに加えSonnetでも動作
- **サードパーティプロバイダ対応**（6月上旬〜）: Amazon Bedrock / Google Cloud Agent Platform / Microsoft Foundry で利用可能。7月中旬からopt-in環境変数も不要に
- **hard denyルール**（5月上旬）: allow例外に関係なく無条件でブロックするルールを書ける
- **破壊的git操作のブロック**（6月中旬）: ユーザーが指示していないローカル変更の破棄（reset --hard等）をブロック
- **安全性強化**（7月上旬）: transcript改ざんをブロック、未解決変数を含む `rm -rf` は実行前に確認を挟む

## 参考リンク

- [Claude Code Changelog v2.1.83](https://code.claude.com/docs/en/changelog)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
