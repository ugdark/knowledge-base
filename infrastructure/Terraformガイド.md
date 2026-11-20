---
title: "Terraformガイド"
category: "infrastructure"
tags: [terraform, iac, hashicorp, opentofu, devops]
created: 2026-05-26
updated: 2026-07-28
---

# Terraformガイド

## 概要

**Terraform**はHashiCorp製のInfrastructure as Code(IaC)ツール。`.tf` ファイル（HCL: HashiCorp Configuration Language）で**望ましい状態**を宣言すると、`plan` → `apply` で実際のクラウドリソースを作成・更新・削除する。AWS/GCP/Azureなど数百のProviderを経由してマルチクラウド対応。

---

## 1. 基本情報

| 項目 | 内容 |
|---|---|
| 作者 | HashiCorp（2025年2月にIBMが買収完了） |
| 初版 | 2014年 |
| 設定言語 | HCL（HashiCorp Configuration Language）/ JSON |
| 公式 | <https://www.terraform.io/> |
| Registry | <https://registry.terraform.io/>（Provider/Module公開リポジトリ） |
| 主な競合 | OpenTofu, Pulumi, AWS CDK, Crossplane |

## 2. ライセンス事情（重要）

2023年8月にライセンスが**MPL 2.0 → BSL 1.1**に変更され話題になったが、結論：**ほとんどの利用者は今も無料で使える**。

| 時期 | ライセンス | 影響 |
|---|---|---|
| 〜2023/08 | MPL 2.0（OSS） | 完全オープンソース |
| 2023/08〜 | **BSL 1.1** | OSI定義のOSSではないが、個人・社内利用は引き続き無料 |
| 4年経過版 | MPL 2.0に自動復帰（遅延OSS） |  |

**BSLで禁止される行為**:
- Terraformと競合する商用サービスを提供すること（例: Terraform Cloud対抗のSaaS提供）

**禁止されない行為**:
- 個人利用、社内利用、業務でのIaC運用、SI案件での顧客環境構築 → **すべて無料**

### OpenTofu — OSSフォーク

BSL移行に反発したコミュニティが作った**Terraformの完全OSS（MPL 2.0）フォーク**。

| 項目 | Terraform | OpenTofu |
|---|---|---|
| ライセンス | BSL 1.1 | MPL 2.0 |
| 運営 | HashiCorp/IBM | Linux Foundation |
| CLI名 | `terraform` | `tofu` |
| 設定ファイル | `.tf` | `.tf`（互換） |
| Provider | Terraform Registry | OpenTofu Registry + Terraform Registry |
| state互換性 | ◯ | ◯（既存stateそのまま使える） |

**使い分け**:
- 業務即戦力・資料の豊富さ重視 → **Terraform**
- ライセンス不安回避・思想的にOSS → **OpenTofu**
- 既存terraform資産があれば両対応は容易（コマンド名を変えるだけ）

## 3. インストール（macOS）

BSL化後にhomebrew-coreから外れたため、`hashicorp/tap` 経由でインストール。

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

このdotfilesでは `Brewfile` 経由で管理：

```ruby
tap "hashicorp/tap"
brew "hashicorp/tap/terraform"
```

### OpenTofuを使う場合

```bash
brew install opentofu
```

### バージョン確認

```bash
terraform version
# Terraform v1.15.4 on darwin_arm64
```

### バージョン管理（mise等）

複数プロジェクトでバージョンを切り替えたい場合は **mise** や **tfenv** が便利：

```bash
mise use -g terraform@1.15.4
```

## 4. 基本コマンド

| コマンド | 用途 |
|---|---|
| `terraform init` | Provider/Moduleダウンロード、backend初期化。**最初に1回必須** |
| `terraform plan` | 差分プレビュー。実環境に変更を加えない |
| `terraform apply` | planの内容を実環境に適用 |
| `terraform destroy` | 管理下リソースを**すべて削除** |
| `terraform fmt` | `.tf` ファイルをフォーマット |
| `terraform validate` | 構文・型チェック（クラウドAPIには問い合わせない） |
| `terraform show` | 現在のstate表示 |
| `terraform state list` | state内のリソース一覧 |
| `terraform import` | 既存リソースをstateに取り込む |
| `terraform refresh` | 実環境とstateを同期 |
| `terraform output` | output値を表示 |
| `terraform workspace` | workspace（環境）切替 |

### 典型フロー

```bash
terraform init           # 初回 or providerバージョン変更時
terraform fmt            # コード整形
terraform validate       # 構文チェック
terraform plan           # 差分確認
terraform apply          # 適用（実際に変更が起こる）
# ... 検証 ...
terraform destroy        # 後始末
```

## 5. 構成ファイル

### ファイル分割の慣習

| ファイル | 役割 |
|---|---|
| `providers.tf` | provider定義（aws, googleなど） |
| `versions.tf` | terraform本体・providerのバージョン制約 |
| `main.tf` | 主要リソース定義 |
| `variables.tf` | 入力変数定義 |
| `outputs.tf` | 出力値定義 |
| `terraform.tfvars` | 変数の値（**gitignoreで除外**することが多い） |
| `backend.tf` | state保存先（S3, GCS等） |
| `.terraform.lock.hcl` | provider版固定（**commit対象**） |
| `terraform.tfstate` | state本体（**絶対にcommitしない**、リモート管理推奨） |

### コードの基本構造

```hcl
# versions.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# providers.tf
provider "aws" {
  region = var.region
}

# variables.tf
variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "env" {
  type    = string
}

# main.tf
resource "aws_s3_bucket" "logs" {
  bucket = "${var.env}-app-logs"
  tags = {
    Env = var.env
  }
}

# outputs.tf
output "bucket_name" {
  value = aws_s3_bucket.logs.bucket
}
```

## 6. State管理

Terraformは**state**（`.tfstate`）で「自分が作ったリソース」を記憶する。stateと実環境の差分が `plan`。

### Local vs Remote

| | Local state | Remote state |
|---|---|---|
| 保存先 | `./terraform.tfstate` | S3, GCS, Terraform Cloud等 |
| 向く用途 | 個人実験 | チーム開発、本番運用 |
| Lock | なし | あり（DynamoDB等で並行apply防止） |
| 機密性 | 平文ファイル | 暗号化+IAM保護可 |

### S3 backend例

```hcl
terraform {
  backend "s3" {
    bucket         = "my-tf-state"
    key            = "prod/network/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "tf-lock"
    encrypt        = true
  }
}
```

> 本番stateは**必ずremote**＋**ロック付き**。チーム間でのstate破壊事故を防ぐ。

## 7. Modules

`.tf` の集合を再利用可能な単位にしたもの。

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "prod-vpc"
  cidr = "10.0.0.0/16"
  # ...
}
```

- **Public Module Registry**: 公式・コミュニティ製の既製品が多数（VPC, EKS, RDS等）
- **自前module**: `modules/<name>/` ディレクトリに切り出し、`source = "./modules/foo"` で参照

## 8. Workspaces

同一コードベースで複数環境（dev/stg/prd等）を切り替える機能。

```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
terraform apply  # devのstateに対して適用
```

リソース名で `terraform.workspace` を参照して名前を分ける。

> **注意**: workspaceは「stateの名前空間」を分けるだけ。Provider設定（AWSアカウント等）は同一になる。**完全に分離したい本番環境はディレクトリ分割の方が安全**。

## 9. Import / 既存リソースの取り込み

手作業で作ったリソースをstateに取り込む。

```bash
# v1.5+ ではimport blockが推奨（plan/applyで実行できる）
terraform import aws_s3_bucket.existing my-existing-bucket
```

```hcl
# import block（推奨）
import {
  to = aws_s3_bucket.existing
  id = "my-existing-bucket"
}
```

## 10. 主要Provider

| Provider | 用途 |
|---|---|
| `hashicorp/aws` | AWS |
| `hashicorp/google` | GCP |
| `hashicorp/azurerm` | Azure |
| `cloudflare/cloudflare` | Cloudflare DNS/CDN |
| `integrations/github` | GitHubリポジトリ・チーム管理 |
| `datadog/datadog` | Datadogモニター |
| `hashicorp/kubernetes` | K8sリソース |
| `hashicorp/helm` | Helm chart |
| `hashicorp/random` | ランダム値生成（命名等） |
| `hashicorp/null` | ダミーリソース |

## 11. 周辺ツール

| ツール | 用途 |
|---|---|
| **terragrunt** | Terraformのラッパー。DRY化・複数環境管理 |
| **tflint** | linter |
| **tfsec / checkov** | セキュリティスキャン |
| **terraform-docs** | `.tf` からREADME自動生成 |
| **infracost** | terraform planからコスト見積もり |
| **atlantis** | PR連携でterraform plan/apply自動化 |
| **Terraform Cloud / Enterprise** | HashiCorp公式SaaS（state管理、CI、ポリシー） |

## 12. 注意点・落とし穴

- **stateを消すと終わり**: stateを失うと管理リソースを把握できなくなる。remote + バージョニング必須
- **手作業で変えるとdrift**: コンソールでの手動変更とstateがズレる。`terraform refresh` か import で対処
- **destroy事故**: 本番でうっかり `destroy` → 復元困難。`prevent_destroy` lifecycle、IAM分離、workspace隔離で防ぐ
- **plan結果は再applyで変わりうる**: planで「変更なし」でも、Provider側API変動でapply時に差分が出ることはある
- **Provider versionは固定**: `~> 5.0` などで上限を切らないと、突然のbreaking changeで詰む

→ **より実践的な作り方は [Terraformベストプラクティス](Terraformベストプラクティス.md) を参照**

## 13. OpenTofu 1.12（2026-07追記）

OpenTofu 1.12（2026年5月）でTerraform本家に無い機能が入った:

- **dynamic prevent_destroy**: lifecycleブロックの `prevent_destroy` が同一モジュール内の変数等を参照可能に（本家は静的値のみ）
- **`destroy = false`** オプション、**`-json-into`** 出力フラグ
- **checksumの自動backfill**: `tofu init` が全プラットフォーム分のハッシュ（zh:/h1:）を自動で含めるため、`tofu providers lock` の手動実行がほぼ不要に
- 1.12系にはセキュリティ修正が出ている（7月）ので、使うなら1.12系の最新を追うこと

## 参考リンク

- [Terraform 公式](https://www.terraform.io/)
- [Terraform Docs](https://developer.hashicorp.com/terraform/docs)
- [Terraform Registry](https://registry.terraform.io/)
- [OpenTofu 公式](https://opentofu.org/)
- [Terraform Best Practices (公式)](https://developer.hashicorp.com/terraform/intro/core-workflow)
- [モダンAWS構築ガイド2026](モダンAWS構築ガイド2026.md) — BSL/OpenTofu採用判断
- [Terraformベストプラクティス](Terraformベストプラクティス.md) — 具体例付きの実践ガイド
