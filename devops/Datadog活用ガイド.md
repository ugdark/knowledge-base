---
title: "Datadog活用ガイド"
category: "devops"
tags: [datadog, observability, APM, monitoring, SaaS]
created: 2026-04-21
updated: 2026-04-21
---

# Datadog活用ガイド

## 概要

米Datadog社が提供するSaaS型の統合Observabilityプラットフォーム。インフラ監視・APM・ログ管理・RUM・セキュリティまで1プロダクトでカバーする商用デファクト。機能は最強クラス、ただし料金設計が複雑で高くつきやすい。

---

## 1. 特徴

- **フルスタック統合**: メトリクス/ログ/トレース/RUM/セキュリティを1UIで相関分析
- **統合数が桁違い**: 公式インテグレーションが700以上
- **高機能APM**: 分散トレース、Continuous Profiler、Service Mapなど業界トップクラス
- **AI機能**: Watchdog（異常検知）、Bits AI（自然言語クエリ）
- **料金の複雑さ**: プロダクトごとに課金単位が違い、想定外コストが発生しやすい

## 2. 主要プロダクト

| カテゴリ | プロダクト例 |
|---|---|
| インフラ | Infrastructure Monitoring / Container Monitoring / Network Performance |
| アプリケーション | APM / Continuous Profiler / Serverless Monitoring |
| ログ | Log Management（ingest + index分離課金） |
| フロントエンド | Real User Monitoring / Session Replay / Synthetic Monitoring |
| セキュリティ | Cloud SIEM / Cloud Security / Application Security |
| AI/Ops | Watchdog / Bits AI / Incident Management |

## 3. 料金体系（2026年時点の概算）

| プロダクト | 料金 | 課金単位 |
|---|---|---|
| Infrastructure Pro | $15/ホスト/月 | ホスト数（年契約） |
| APM | $31/ホスト/月 | ホスト数（Infra契約も必須） |
| Log Ingestion | $0.10/GB | 取り込み容量 |
| Log Indexing | $1.70/百万イベント | 検索可能期間（15日） |
| Custom Metrics | 別途課金 | メトリック数 |

※詳細は[公式料金ページ](https://www.datadoghq.com/pricing/)参照。請求は**High Watermark**方式（月内上位1%除いた最大値）。

## 4. セットアップ

### Datadog Agent（Linux）

```bash
DD_API_KEY=<your-api-key> DD_SITE="datadoghq.com" \
  bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"
```

### 主要設定（/etc/datadog-agent/datadog.yaml）

```yaml
api_key: <your-api-key>
site: datadoghq.com  # EUの場合 datadoghq.eu
env: production
tags:
  - service:web-app
  - team:platform

# ログ収集を有効化
logs_enabled: true

# APM を有効化
apm_config:
  enabled: true
```

### Kubernetes

```bash
helm repo add datadog https://helm.datadoghq.com
helm install datadog-agent datadog/datadog \
  --set datadog.apiKey=<your-api-key> \
  --set datadog.site=datadoghq.com \
  --set datadog.logs.enabled=true \
  --set datadog.apm.portEnabled=true
```

## 5. 運用のコツ

### タグ設計が命

Datadogは **タグで全てを横断検索** する設計。以下は全テレメトリに付与すべき標準タグ。

| タグ | 例 |
|---|---|
| `env` | production / staging / dev |
| `service` | web-app / batch-worker |
| `version` | v1.2.3 |
| `team` | platform / payment |
| `cost_center` | product-a |

**Unified Service Tagging** を適用すると、Metrics/Logs/Tracesが自動リンクされる。

### コスト爆発ポイント

| 原因 | 対策 |
|---|---|
| カスタムメトリクス過多 | 不要タグ組合せを削減（タグの基数に課金） |
| ログ Indexing 全量 | Exclusion Filter で低価値ログは ingest のみ |
| 非本番のAPM常時稼働 | 開発/ステージングはサンプリング率を下げる |
| ホスト増加 | コンテナ環境は per-container 課金プランを確認 |
| Synthetic テスト | 実行頻度と分散ロケーションを見直す |

### 監視の組み立て方

1. **Monitor**: 閾値ベースのアラート（静的/異常検知/予測）
2. **SLO**: SLIとエラーバジェット管理
3. **Dashboard**: チーム/サービス別の可視化
4. **Notebook**: インシデント調査メモ・RCA
5. **Incident Management**: オンコール連携・タイムライン

## 6. こんな現場で使うと良い

- **予算に余裕がある**中〜大規模組織
- APM・分散トレースを本格活用したい
- ログ/メトリクス/トレースを1つのUIで相関させたい
- インフラ/アプリ/セキュリティ/ビジネスKPIを横断で見たい

## 7. 注意点

- **料金が読みにくい**。導入前にCost Explorerで予測必須
- 機能が多すぎて、**必要なものだけ選ぶ判断**がつきにくい
- ベンダーロックインの度合いは高い。移行コストも大きい
- 代替検討の候補: Grafana Cloud, New Relic, SigNoz, OpenObserve

---

## 参考リンク

- [Datadog公式](https://www.datadoghq.com/)
- [Datadog料金](https://www.datadoghq.com/pricing/)
- [Datadog Docs: Pricing](https://docs.datadoghq.com/account_management/billing/pricing/)
- [Unified Service Tagging](https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/)
- [Observabilityツール比較](Observabilityツール比較.md)
