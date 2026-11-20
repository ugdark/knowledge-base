---
title: "Mackerel活用ガイド"
category: "devops"
tags: [mackerel, observability, monitoring, SaaS, hatena]
created: 2026-04-21
updated: 2026-04-21
---

# Mackerel活用ガイド

## 概要

株式会社はてな提供の国産SaaS型監視サービス。エージェント型で導入が容易、日本語UI・日本語サポート・日本円決済が揃う。「育てる監視」をコンセプトに、運用しながら監視項目を拡張していくスタイル。

---

## 1. 特徴

- **SaaS型**: 監視基盤の構築・運用が不要
- **エージェント型**: `mackerel-agent` をサーバーに入れるだけで開始
- **国産**: 日本語UI/日本語サポート/請求書払い可
- **AWS/Azure/GCP統合**: IAM連携でクラウドリソースのメトリクスを自動取得
- **育てる監視**: まずは基本監視から始め、サービスメトリクスや外形監視を段階的に追加

## 2. 主要機能

| 機能 | 内容 |
|---|---|
| ホストメトリクス | CPU/メモリ/ディスク/ロードアベレージ等、エージェントが自動収集 |
| サービスメトリクス | アプリから任意のメトリクスを投稿（API経由） |
| 外形監視 | URLに対するHTTP/HTTPS死活監視 |
| 式による監視 | 複数メトリクスの演算結果で閾値判定 |
| 異常検知 | 機械学習でメトリクスの異常を検出 |
| アラート通知 | Slack/Teams/PagerDuty/Webhook/メール 等 |
| AWSインテグレーション | RDS/ELB/Lambda等のCloudWatchメトリクスを取り込み |

## 3. 料金プラン（2026年時点の概算）

| プラン | 料金 | 対象 |
|---|---|---|
| Free | 無料 | 5ホストまで |
| Standard | 2,180円/ホスト | 本番運用向け |
| Micro | 660円/ホスト | 軽量ホスト向け |
| メトリック | 11円/メトリック | カスタムメトリクス |
| トレース | 330円/百万スパン | APM用 |

※すべて税込。最新は[公式料金ページ](https://ja.mackerel.io/pricing)を参照。

## 4. セットアップ

### エージェントインストール（Linux）

```bash
# Amazon Linux / RHEL系
curl -fsSL https://mackerel.io/file/script/setup-all-yum.sh \
  | MACKEREL_APIKEY='<your-api-key>' sh

# Ubuntu/Debian系
curl -fsSL https://mackerel.io/file/script/setup-all-apt.sh \
  | MACKEREL_APIKEY='<your-api-key>' sh
```

### 設定ファイル（/etc/mackerel-agent/mackerel-agent.conf）

```toml
apikey = "your-api-key"

# ロール付与（後述）
roles = [ "web-app:app-server" ]

# プラグイン例（nginx監視）
[plugin.metrics.nginx]
command = ["/opt/mackerel-agent/plugins/bin/mackerel-plugin-nginx"]
```

## 5. 運用のコツ

### サービスとロールの設計

Mackerelは「**サービス** > **ロール** > **ホスト**」の3階層でリソースを整理する。

- **サービス**: アプリケーション単位（例: `web-app`, `batch-system`）
- **ロール**: サービス内の役割（例: `app-server`, `db`, `redis`）
- **ホスト**: 実サーバー。複数ロールに所属可

ロール単位でグラフ・アラート・ダッシュボードを組むのが基本。

### 監視ルールの順序

1. **基本リソース監視**: CPU/メモリ/ディスク/ロードアベレージの閾値
2. **外形監視**: HTTP 200応答とレスポンスタイム
3. **サービスメトリクス**: アプリ側から業務指標を投稿（例: キュー長、エラー率）
4. **異常検知**: 定常パターンから外れた挙動を検出

### よくある使い方

- **プラグイン豊富**: `mackerel-plugin-*` でMySQL/Redis/Nginx等を即時監視
- **check-plugin**: `check-log` でログ監視、`check-file-age` でファイル更新監視
- **メンテナンスウィンドウ**: デプロイ中はアラートを抑制
- **Terraform Provider**: 監視ルールをコード管理

## 6. こんな現場で使うと良い

- 日本のエンタープライズ/中堅企業で、**日本語サポートと請求書払い**が必須
- 監視基盤を運用する余力がない小〜中規模チーム
- まずは軽く監視を始め、段階的に拡張したい
- AWSリソースを統合監視したい

## 7. 注意点

- APM（分散トレース）機能は後発で、Datadogほどの成熟度はない
- ログ管理機能は弱い（`check-log` で行マッチ検知程度）。ログ分析基盤は別途必要
- 海外拠点が多い場合、**東京リージョンのみ**なのでレイテンシ・データ主権を要確認

---

## 参考リンク

- [Mackerel公式](https://ja.mackerel.io/)
- [Mackerel料金](https://ja.mackerel.io/pricing)
- [Mackerel公式ドキュメント](https://mackerel.io/ja/docs/)
- [Observabilityツール比較](Observabilityツール比較.md)
