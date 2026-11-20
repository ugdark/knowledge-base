---
title: "Observabilityツール比較"
category: "devops"
tags: [observability, monitoring, 比較, mackerel, datadog, openobserve, elasticsearch]
created: 2026-04-21
updated: 2026-04-21
---

# Observabilityツール比較

## 概要

Mackerel / Datadog / OpenObserve / Elasticsearch(ELK) の4ツールを、用途・コスト・運用負荷の観点で比較する。それぞれ得意領域が違うため、「どれが最強か」ではなく「**どの悩みを解くか**」で選ぶのが正解。

---

## 1. 一覧比較

| 観点 | Mackerel | Datadog | OpenObserve | Elasticsearch(ELK) |
|---|---|---|---|---|
| 形態 | SaaS | SaaS | OSS / SaaS | OSS / SaaS |
| 提供元 | はてな（日本） | Datadog（米国） | OpenObserve（OSS） | Elastic（米国） |
| 得意領域 | インフラ監視 | フルスタック | ログ基盤 | ログ検索 |
| メトリクス | ◎ | ◎ | ◎ | △（Metricbeat） |
| ログ | △ | ◎ | ◎ | ◎ |
| APM/分散トレース | ○ | ◎ | ○ | ○ |
| RUM / Synthetic | × | ◎ | ○ | ○ |
| 初期導入の容易さ | ◎ | ○ | △（自己運用） | ×（重い） |
| 運用負荷 | ほぼゼロ | ほぼゼロ | 中 | 高 |
| コスト | 中 | 高 | 低（自己運用） | 中〜高 |
| 日本語サポート | ◎ | ○ | × | × |

## 2. 「なぜElasticsearchが比較対象に入るか」

OpenObserveの主戦場が **ログ基盤** だから。

- **Elasticsearch (ELK)**: 長年ログ分析のデファクト。全文検索と分析が強い。ただし**ストレージコスト**と**クラスタ運用負荷**が重い
- **OpenObserve**: 「ELKを140倍安く置き換える」を明確にマーケティング
- **Mackerel**: メトリクス監視が主戦場で、ログは弱い → 直接競合ではない

比較対象は「**何を置き換えたいか**」で変わる：

| 置き換えたいもの | 有力候補 |
|---|---|
| メトリクス監視SaaS | Mackerel / Datadog / CloudWatch |
| ログ基盤 | OpenObserve / Elasticsearch / Loki / Splunk |
| APM・分散トレース | Datadog / New Relic / SigNoz |
| フルスタック統合 | Datadog / New Relic / Grafana Cloud |

## 3. コスト感（参考）

仮に **ホスト100台 + ログ1TB/月** のワークロードで概算（2026年時点・為替レートで変動）：

| ツール | 月額の目安 | 備考 |
|---|---|---|
| Mackerel | 約22万円 | Standardホスト100台。ログ別途 |
| Datadog | 約150〜300万円 | Infra+APM+Log Index込み。設定次第で大差 |
| OpenObserve (Self-Host) | 約5〜15万円 | EC2/EKS + S3費用。人件費別 |
| Elasticsearch (Self-Host) | 約30〜60万円 | 3-node ESクラスタ + ストレージ。人件費別 |

**注意**: OpenObserve/ESは「自己運用の人件費」が最大コスト。小規模ならSaaSの方が総コストは安いケースが多い。

## 4. 選定ガイド

### Mackerelを選ぶとき

- 日本国内の中小〜中堅規模、運用人員が少ない
- **日本語サポート・請求書払い**が必須
- まずはインフラ監視から始めたい
- AWS統合監視を軽く使いたい

### Datadogを選ぶとき

- 予算に余裕がある中〜大規模組織
- **APM/分散トレース**を本格活用したい
- メトリクス/ログ/トレース/RUMを1つのUIで相関させたい
- マイクロサービス運用で横断可視化が必須

### OpenObserveを選ぶとき

- **ログ量が多く、SaaSの従量課金が苦しい**
- Datadog/Elasticsearchの**脱ベンダーロックイン**
- OpenTelemetry中心の構成
- オブジェクトストレージを活用したOSS運用体制がある

### Elasticsearch(ELK)を選ぶとき

- 既に ES 運用ノウハウがある
- **全文検索・複雑クエリ**が必要（ログ以外に検索用途も兼ねる）
- セキュリティ(SIEM)ログとアプリログを同居させたい
- 商用サポートが必要なら Elastic Cloud も選択肢

## 5. 併用パターン

現場では単独ではなく **役割分担** で組合せるケースが多い。

### パターンA: Mackerel + OpenObserve

- Mackerel: インフラ監視・アラート・外形監視
- OpenObserve: アプリケーションログ・APM
- 安価に一通り揃う。日本企業で人気パターン

### パターンB: Datadog中心 + ログだけOpenObserve

- Datadog: メトリクス/APM/RUM/セキュリティ
- OpenObserve: ログ（Datadog Log Indexingのコスト圧縮）
- Datadogの**ログコスト爆発問題**をOSSで回避

### パターンC: Grafana LGTM + Mackerel

- Grafana + Loki + Tempo + Mimir: OSSで構築
- Mackerel: 外形監視・基本アラート（SaaSの安定性を担保）

## 6. 判断フローチャート

```
運用人員は潤沢か？
├─ No → SaaSを選ぶ
│   ├─ 日本語サポート必須？
│   │   ├─ Yes → Mackerel
│   │   └─ No  → Datadog（予算あり）/ Grafana Cloud
│   └─ ログ量が多くコスト心配？
│       └─ ログだけ OpenObserve を併用
└─ Yes → OSSを選ぶ選択肢あり
    ├─ ログ主体 → OpenObserve / Elasticsearch
    ├─ フルスタック → Grafana LGTM / SigNoz
    └─ 既存ES運用あり → Elasticsearch継続
```

---

## 参考リンク

- [Mackerel活用ガイド](Mackerel活用ガイド.md)
- [Datadog活用ガイド](Datadog活用ガイド.md)
- [OpenObserve活用ガイド](OpenObserve活用ガイド.md)
- [OpenObserve: Datadog Competitors 2026](https://openobserve.ai/blog/datadog-competitors/)
- [OpenObserve: Log Management Tools 2026](https://openobserve.ai/blog/log-management-tools/)
