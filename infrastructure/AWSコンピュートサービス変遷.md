---
title: "AWSコンピュートサービス変遷"
category: "infrastructure"
tags: [AWS, EC2, ECS, EKS, Fargate, Lambda]
created: 2026-04-16
updated: 2026-04-16
---

# AWSコンピュートサービス変遷

## 概要

AWSコンピュートサービスの変遷と、2026年時点の各サービスの立ち位置・使い分け。EC2からECS Managed Instancesまでの歴史と現状をまとめる。

---

## 変遷サマリ

| 年 | サービス | 単位 | 位置づけ |
|----|---------|------|---------|
| 2006 | **EC2** | 仮想マシン | 基盤。今も全ての土台 |
| 2010 | **Elastic Beanstalk** | アプリ | PaaS的。2026年時点は実質メンテモード |
| 2014 | **Lambda** | 関数 | サーバーレス。AWS顧客の65%が利用 |
| 2014 | **ECS** | コンテナ | AWS独自のコンテナオーケストレーター |
| 2017 | **Fargate** | コンテナ | サーバーレス版コンテナ |
| 2018 | **EKS** | K8s | マネージドKubernetes |
| 2021 | **App Runner** | コンテナ | Heroku的な最もシンプルなデプロイ |
| 2025 | **ECS Managed Instances** | コンテナ | EC2とFargateの中間（新選択肢） |

## ECS以前の時代（コンテナ前）

```
1. EC2インスタンスを立てる
2. Chef/Puppet/Ansibleで環境構築（apache, nginx, Ruby等インストール）
3. Capistrano等でSSH越しにアプリをデプロイ
4. ELB配下に追加
```

Chef社は2020年にProgressに買収され、当時の構成管理ツールは主役を降りた。現在はDockerで「環境ごとコンテナ化」する時代。

---

## 補足: Herokuとは

App Runnerの比較対象として。PaaS（Platform as a Service）の元祖的存在。

- 2007年登場。Salesforceが2010年に買収
- **「git push heroku main」だけでデプロイ完了**。インフラ設定不要
- Ruby on Railsコミュニティで爆発的に普及。その後Python/Node/Java等にも対応
- 無料枠があったが、2022年に**無料プラン廃止**（有料のみに）
- 2026年現在もサービス継続中だが、個人開発やスタートアップは Fly.io / Railway / Render 等の新興PaaSに流れている

AWSにおけるHeroku的ポジション = **Elastic Beanstalk（旧世代）/ App Runner（現行）**

---

## 各サービスの現状（2026年）

### EC2

- Graviton5プロセッサ搭載（re:Invent 2025発表）のM9g/C8id等の新インスタンス
- なくならない。全ての土台
- **用途**: モノリシック、GPU/ML、カスタムカーネル、レガシーアプリ、ベアメタル的な制御が必要なケース
- **典型例**: バッチ処理サーバー、機械学習トレーニング、Windows Server、VPN/踏み台

### Elastic Beanstalk

- 公式に廃止ではないが、**Amazon Linux 2ベースのプラットフォームは2026年6月30日で終了**
- AL2023プラットフォームは継続更新中（直近: 2026年1月）
- **用途**: コードをアップロードするだけで裏でEC2+ELB+Auto Scalingが自動構築される。Heroku的なPaaS体験
- **典型例**: 既存のRails/Django/Spring Bootアプリを最小労力でAWSに載せたい場合
- **現状**: 新規プロジェクトでは非推奨。既存ユーザーはコンテナ化（ECS/App Runner）への移行推奨

### Lambda

- サーバーレスの代表格。**AWS顧客の65%が利用**（Datadog 2025）
- 制約: 15分タイムアウト（昔と同じ）
- **用途**: イベント駆動・短時間処理。「何かが起きた時に少しだけ処理する」
- **典型例**: S3アップロード→画像リサイズ、APIGateway→REST API、SQSメッセージ処理、CloudWatchイベント→定期バッチ、DynamoDB Streams→データ連携
- **不向き**: 常時起動するWebサーバー、長時間バッチ、WebSocket

### ECS

- **2026年時点で最も活発に開発されている**コンテナサービス
- 3つの起動モード:

| モード | 説明 |
|--------|------|
| **EC2起動タイプ** | 自前でインスタンス管理 |
| **Fargate** | サーバーレス |
| **Managed Instances** | AWSが自動プロビジョン・スケール・パッチ（2025年9月新登場） |

- AWSオンリーで完結するならEKSより推奨
- **用途**: Dockerコンテナを本番運用する標準的な方法
- **典型例**: Webアプリケーション、APIサーバー、マイクロサービス群、バックグラウンドワーカー、定期バッチ（Scheduled Task）

### Fargate

- ECSとEKS両方で使えるサーバーレスコンテナ
- 新規コンテナワークロードのデフォルト選択肢
- **用途**: コンテナを動かしたいがインスタンス管理はしたくない
- **典型例**: 中小規模のWebサービス、API、定期バッチ、開発/ステージング環境
- **不向き**: GPU、大量のCPU/メモリが必要なケース、コスト最適化を極めたい場合

### EKS

- マネージドK8s
- **用途**: Kubernetes専門知識がチームにある、マルチクラウド移植性が必要、CNCFエコシステム（Istio, ArgoCD, Prometheus等）を使いたい
- **典型例**: 大規模マイクロサービス、マルチクラウド戦略、AI/ML基盤、社内プラットフォーム
- **不向き**: AWSオンリーで完結する小中規模プロジェクト（ECSの方がシンプル）

### App Runner

- **最もシンプル**なコンテナデプロイ。Heroku的な使い勝手
- コンテナイメージかソースコード（GitHub連携）を指定するだけでデプロイ完了
- 特徴: アイドル時はコンテナを停止（メモリ課金のみ）、リクエスト時に即復帰
- **用途**: インフラを極力触りたくない。デプロイだけしたい
- **典型例**: 社内ツール、MVP、プロトタイプ、シンプルなREST API、個人プロジェクト
- **不向き**: バックグラウンド処理、WebSocket、複雑なネットワーク構成、HTTP同期以外の通信

### ECS Managed Instances（2025年新機能）

- EC2とFargateの**中間**の選択肢
- AWSがインスタンス管理を自動化（プロビジョン・スケール・パッチ）
- Bottlerocket OS上で動作、Spotインスタンス対応
- **用途**: Fargateのように管理は任せたいが、コストを抑えたい。またはFargateでは対応できないインスタンスタイプが必要
- **典型例**: トラフィックが安定している本番サービス、Fargateからのコスト削減移行
- **Fargateから30-50%のコスト削減**の可能性あり

---

## 使い分けガイド

| やりたいこと | 推奨 | 理由 |
|-------------|------|------|
| 社内ツール・MVP・プロトタイプを最速で公開 | App Runner | インフラ設定ほぼゼロ。アイドル時停止でコストも安い |
| S3イベントやSQS処理などの非同期ジョブ | Lambda | イベント駆動に最適。常時起動不要 |
| 定期バッチ（数分〜数時間の処理） | Lambda or ECS Scheduled Task | 15分以内ならLambda、超えるならECS |
| WebアプリやAPIを本番運用（数サービス） | ECS + Fargate | インスタンス管理不要で運用が楽 |
| 本番運用でコストを最適化したい | ECS + Managed Instances | Fargateより30-50%安、管理はAWSに任せられる |
| マイクロサービスが数十〜数百ある | EKS | Helm/ArgoCD/Istio等で統一管理。ECSでは管理が辛い |
| マルチクラウドでの移植性が必要 | EKS | K8sならGKE/AKSに移植可能。ECSはAWSロックイン |
| GPU/ML、カスタムカーネル、Windows | EC2 | OS制御が必要な場面はEC2一択 |
| レガシーアプリのリフト＆シフト | EC2 or Beanstalk | そのまま載せるならEC2、最小労力でPaaSにするならBeanstalk |

---

## 参考リンク

- [AWS Compute Services 2026](https://group107.com/blog/aws-compute-services/)
- [ECS Managed Instances発表](https://aws.amazon.com/about-aws/whats-new/2025/09/amazon-ecs-managed-instances/)
- [ECS at AWS re:Invent 2025](https://aws.amazon.com/blogs/containers/amazon-ecs-at-aws-reinvent-2025/)
