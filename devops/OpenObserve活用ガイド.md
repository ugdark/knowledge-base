---
title: "OpenObserve活用ガイド"
category: "devops"
tags: [openobserve, observability, OSS, logs, metrics, traces]
created: 2026-04-21
updated: 2026-04-21
---

# OpenObserve活用ガイド

## 概要

Rust製のオープンソースObservabilityプラットフォーム。ログ/メトリクス/トレースを単一バイナリでカバーし、S3等のオブジェクトストレージに直接書き込むことで**Elasticsearchの約140倍安価**なストレージコストを実現する。Datadog/Splunk/ELKの代替として注目されている。

---

## 1. 特徴

- **Rust製**: 高速・省メモリ・単一バイナリでデプロイ可能
- **Parquet + 列指向**: 圧縮率40倍、クエリは Apache DataFusion
- **S3直書き**: ローカルディスクを介さずS3/GCS/Azure Blob/MinIOに保存
- **Stateless設計**: 水平スケール容易（Ingester/Querier/Compactor分離）
- **OSS + エンタープライズ**: OSS版だけで本番運用可能、SSO/RBAC等が有償版

## 2. 主要機能

| 機能 | 対応状況 |
|---|---|
| Logs | OTLP / Fluent Bit / Vector / Syslog / 任意HTTP POST |
| Metrics | Prometheus remote write / OTLP |
| Traces | OTLP（OpenTelemetry） |
| Frontend (RUM) | 独自SDK / Session Replay |
| Dashboards | 独自ビルトイン（SQL/PromQLベース） |
| Alerts | しきい値 / 予測 / レート |
| Pipelines | 取り込み時変換（VRL風DSL） |
| Query言語 | SQL + PromQL |

## 3. アーキテクチャ

```
[Collectors]         [OpenObserve]              [Storage]
OTel Collector  --->  Router                    Local Disk
Fluent Bit      --->  └─ Ingester  ─── write ─> S3 / GCS /
Vector          --->     Querier   ─── read ──> MinIO / Azure
Prometheus      --->     Compactor
                         (compact Parquet)
```

### デプロイモード

| モード | 用途 |
|---|---|
| Single Node | 開発/小規模本番。単一バイナリで起動 |
| HA Cluster | Ingester/Querier/Compactorを分離してK8sで運用 |

## 4. セットアップ（Single Node）

```bash
# 最小構成: ローカルディスク保存
ZO_ROOT_USER_EMAIL=admin@example.com \
ZO_ROOT_USER_PASSWORD=Complexpass#123 \
  ./openobserve
```

### S3バックエンド構成例

```bash
ZO_ROOT_USER_EMAIL=admin@example.com \
ZO_ROOT_USER_PASSWORD=Complexpass#123 \
ZO_LOCAL_MODE_STORAGE=s3 \
ZO_S3_BUCKET_NAME=my-observe-bucket \
ZO_S3_REGION_NAME=ap-northeast-1 \
ZO_S3_ACCESS_KEY=<AWS_ACCESS_KEY> \
ZO_S3_SECRET_KEY=<AWS_SECRET_KEY> \
  ./openobserve
```

### Docker Compose（HA Cluster）

公式が Helm Chart / Docker Compose を提供。`docker-compose.yml` を `git clone https://github.com/openobserve/openobserve` から取得して `docker compose up -d` で起動。

## 5. 運用のコツ

### データ取り込み構成

最も一般的なパターン：

```
[アプリ] --OTLP--> [OpenTelemetry Collector] --OTLP--> [OpenObserve]
```

OTel Collectorを前段に置き、バッチング・リトライ・フィルタを任せる。OpenObserveは受け取りと保存に専念させるとシンプル。

### ストリームとパーティション

- **Stream**: データの論理単位（例: `nginx_access`, `app_json`）
- **Partition Key**: 時刻(`_timestamp`)に加え任意のカラムを指定可能
- パーティション設計次第でクエリ性能が大きく変わる

### ユーザー定義関数（UDF）

取り込み時に VRL風のパイプラインで変換・エンリッチ・マスキング可能。例：

```
.ip = del(.client_ip)
.level = downcase(.level)
```

### クエリ

```sql
-- エラーログをhost別に集計（直近1時間）
SELECT host, COUNT(*) AS err_count
FROM default
WHERE level = 'ERROR'
  AND _timestamp >= NOW() - INTERVAL 1 HOUR
GROUP BY host
ORDER BY err_count DESC;
```

PromQLも併用可（メトリクスストリームに対して）。

## 6. こんな現場で使うと良い

- ログ量が多く、Elasticsearch/Datadogの**ストレージコストが苦しい**
- Datadogからの**脱ベンダーロックイン**を進めたい
- OSS + クラウドオブジェクトストレージで**自前運用**したい
- OpenTelemetry中心の構成で、統一プラットフォームを探している

## 7. 注意点

- エコシステムはDatadog/Elasticsearchほど成熟していない（特に**サードパーティ統合**）
- APM/RUMは搭載されるが、Datadogレベルの相関分析・機械学習機能はまだ差がある
- OSS版と有償版の機能差（SSO/AdvancedRBAC/Federation等）は事前確認
- 自前運用する以上、**バックアップ・バージョンアップ・キャパシティ計画**は自己責任

---

## 参考リンク

- [OpenObserve公式](https://openobserve.ai/)
- [OpenObserve Docs](https://openobserve.ai/docs/)
- [OpenObserve GitHub](https://github.com/openobserve/openobserve)
- [Observabilityツール比較](Observabilityツール比較.md)
