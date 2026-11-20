---
title: "Terraformベストプラクティス"
category: "infrastructure"
tags: [terraform, iac, ベストプラクティス, destroy, 命名規約]
created: 2026-05-26
updated: 2026-07-28
---

# Terraformベストプラクティス

## 概要

Terraformで「動くだけのコード」と「**運用に耐えるコード**」の差は、ほぼ**「いつでも安全にdestroyできるか」**で決まる。検証→destroy→再構築を気軽に回せない構成は、本番運用でも事故を起こしやすい。

このガイドは **「自分の検証環境を別名で作ってdestroyまで試せる」** という鉄則を中心に、命名・state分離・変数管理・実行フローを実例とともにまとめる。

ツール本体の使い方は [Terraformガイド](Terraformガイド.md) を参照。

---

## 1. 鉄則: 「いつでもdestroyできる」前提で作る

> **destroyまで試せない環境で書いたterraformは信用しない。**

### なぜ重要か

- **手元での検証ループが回る** → planの妥当性を実環境で確認できる
- **冪等性の確認になる** → apply → destroy → apply で同じ結果が得られるか確認できる
- **state破壊事故の被害が小さい** → 検証stateは消えても本番に影響しない
- **「壊して再作成」が選択肢になる** → 本番で運用パスが詰まった時に「最悪作り直せる」と知っているのは強い

### destroyできなくする悪手

- 共有リソースを直接管理下に置く（既存VPCを別チームと共有しているのにimportしてしまう等）
- 本番と同じstateで検証を混ぜる
- リソース名が固定（`bucket = "logs"`）で他環境と衝突する
- `prevent_destroy = true` をデフォルトで付ける（本来は本番DB等の限定用途）

## 2. 命名規約 — 完全に独立した名前空間を持つ

検証環境が**他環境と物理的に共存できる**よう、すべてのリソース名に**識別子prefix**を付ける。

### prefix構造

```
<env>-<owner>-<service>-<resource>
例:
  dev-ugdark-myapp-logs       (S3バケット)
  prd-platform-api-cluster       (ECSクラスタ)
```

| 要素 | 役割 |
|---|---|
| `env` | dev / stg / prd / sbx（sandbox） |
| `owner` | 個人検証なら自分の名前。チーム共用なら省略可 |
| `service` | アプリ/サービス名 |
| `resource` | 種別（任意） |

### Terraformでの表現

```hcl
locals {
  prefix = "${var.env}-${var.owner}-${var.service}"
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.prefix}-logs"
}
```

これで `dev-ugdark-myapp-logs` のように作られ、他人のバケットと絶対に衝突しない＆destroyで完全に消える。

## 3. ディレクトリ構造 — 環境はディレクトリ分割

workspaceは便利だが、**stateの名前空間を分けるだけでProvider設定は共通**。本番をうっかり触る事故が起きうる。

**推奨**: 環境ごとにディレクトリを切る。

```
terraform/
├── modules/                     # 再利用可能なモジュール
│   ├── network/
│   └── app/
└── environments/
    ├── dev/
    │   ├── backend.tf           # dev用state設定
    │   ├── providers.tf         # devアカウントのprofile
    │   ├── main.tf
    │   └── terraform.tfvars
    ├── stg/
    └── prd/
```

- 環境ごとに `terraform init` する
- 本番ディレクトリには別IAM Role/Profileを設定 → 検証中に誤ってprdを触れない
- backendも環境ごとに別bucket/keyにしてstate完全分離

## 4. State管理

| ルール | 理由 |
|---|---|
| stateは**必ずremote**（S3/GCS等） | ローカル消失リスク回避 |
| stateバケットは**versioning有効** | 誤ったapplyから復旧可能 |
| **DynamoDB Lock**（S3 backend時） | 並行apply事故防止 |
| stateバケットは**暗号化** | secretやARNが含まれる |
| `terraform.tfstate*` は**.gitignore** | コミット禁止 |
| state自体を**手編集しない** | `terraform state mv/rm` 等のコマンド経由で |

## 5. 変数管理

### 階層

| ソース | 用途 | git管理 |
|---|---|---|
| `variable "x" { default = ... }` | デフォルト値 | ◯ |
| `terraform.tfvars` | 環境ごとの設定 | △ (機密含むなら除外) |
| `*.auto.tfvars` | 自動読込 | △ |
| `TF_VAR_xxx` 環境変数 | CI/シークレット | × |
| `-var "x=y"` CLI引数 | 一時オーバーライド | - |

### 機密値の扱い

```hcl
variable "db_password" {
  type      = string
  sensitive = true   # planで値が****化される
}
```

実値は **TF_VAR_db_password** 環境変数や **AWS Secrets Manager / Parameter Store** から `data` ブロックで取得。

## 6. Lifecycle / 防衛コード

| 機能 | 用途 |
|---|---|
| `prevent_destroy = true` | 本番DB等、絶対消えてはいけないものに限定 |
| `ignore_changes = [...]` | 手動運用される属性をdriftとして無視 |
| `create_before_destroy = true` | ALB/Listener等の停止許容しないリソース |

**注意**: `prevent_destroy` を多用すると検証ですらdestroyできなくなる。**本番ディレクトリのみ・最小範囲**で。

## 7. 実例: 個人検証用S3バケット構築 → destroyまで

「自分専用の検証用S3バケット（バージョニング+ライフサイクル+暗号化）を作って、用が済んだらdestroyで完全に消す」最小実例。

### ディレクトリ

```
sandbox-s3/
├── versions.tf
├── providers.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars        # gitignore対象
└── .gitignore
```

### `.gitignore`

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
```

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### `providers.tf`

```hcl
provider "aws" {
  region  = var.region
  profile = var.aws_profile   # 検証用AWSアカウントのprofile
}
```

### `variables.tf`

```hcl
variable "env" {
  type    = string
  default = "sbx"
}

variable "owner" {
  description = "リソース所有者識別子（個人名等）"
  type        = string
}

variable "service" {
  type    = string
  default = "tfsandbox"
}

variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "aws_profile" {
  type = string
}
```

### `locals.tf`

```hcl
locals {
  prefix = "${var.env}-${var.owner}-${var.service}"

  common_tags = {
    Env        = var.env
    Owner      = var.owner
    Service    = var.service
    ManagedBy  = "terraform"
    Disposable = "true"   # 検証用＝destroyしてよい印
  }
}
```

### `main.tf`

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "${local.prefix}-logs"
  tags   = local.common_tags

  # 検証用なので force_destroy で中身ごと消せるようにする
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### `outputs.tf`

```hcl
output "bucket_name" {
  value = aws_s3_bucket.logs.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
```

### `terraform.tfvars`（自分用、gitignore）

```hcl
owner       = "ugdark"
aws_profile = "my-sandbox"
```

### 実行フロー

```bash
# 初期化
terraform init

# フォーマット & 構文チェック
terraform fmt
terraform validate

# 差分確認
terraform plan
# → +5リソース予定が表示される

# 適用
terraform apply
# → sbx-ugdark-tfsandbox-logs が作成される

# 確認
terraform output bucket_name
aws s3 ls --profile my-sandbox | grep sbx-ugdark

# === 検証 ===
# バケットに何か上げる、ライフサイクルを試す等

# 後始末
terraform destroy
# → "Destroy complete! Resources: 5 destroyed."
```

**ここで重要**: destroyが**1コマンドで完了**するように設計してある。
- `force_destroy = true` でバージョン付きオブジェクトも含めて削除可能
- prefix命名で他人の環境と衝突しない
- localstateだが個人検証なのでOK（チーム運用ならremote backend追加）

apply→destroy→apply で同じ結果が再現できる構成は、**本番に持っていける品質**の最低ライン。

## 8. CI/CD連携の指針

- **plan**は全PRで自動実行（差分をPRコメントに）
- **apply**は手動承認 or 限定branchのみ
- **本番applyにはレビュー必須**（atlantis / Terraform Cloud / GitHub Actions+manual approval）
- state破壊系コマンド（`state rm`, `import`）はCIで実行せず手動

## 9. アンチパターン

| アンチパターン | なぜダメか | 対策 |
|---|---|---|
| リソース名ハードコード（`bucket = "logs"`） | 環境間衝突 | `${local.prefix}` で名前空間化 |
| `terraform.tfstate` をgit commit | secret漏洩、競合 | remote backend |
| 全環境を1workspaceで管理 | 本番事故 | 環境ごとにディレクトリ分離 |
| 巨大な単一 `main.tf` | レビュー困難・blast radius大 | module分割 |
| Provider版を固定しない | 突然のbreaking change | `~> 5.0` で上限制約 |
| destroy禁止リソースを検証環境にも入れる | 検証で詰む | `prevent_destroy` は本番のみ |
| 手作業で変えてdrift放置 | 次回applyで意図しない変更 | import or refresh |
| 検証用に本番AWSアカウント使う | 全員の検証で本番汚染 | sandbox AWSアカウント分離 |

## 10. チェックリスト

新規Terraformコード作成時の確認項目：

- [ ] リソース名にprefix（env/owner/service）が付いている
- [ ] state はremote backend、versioning＋暗号化＋lockあり（本番）
- [ ] `terraform.tfstate*` と `*.tfvars` が `.gitignore` 入り
- [ ] `.terraform.lock.hcl` はcommit対象に入っている
- [ ] Provider版に上限制約あり（`~> X.Y`）
- [ ] `terraform fmt` / `validate` がCIで走る
- [ ] **検証環境でapply→destroy→applyが通る**
- [ ] tagsに `ManagedBy = "terraform"` 等の識別あり
- [ ] secretは変数経由（`.tf` 直書き禁止）、`sensitive = true`
- [ ] 本番ディレクトリは別IAM Role/Profile

## 11. OpenTofu 1.12の防衛コード強化（2026-07追記）

OpenTofuを使う場合、1.12（2026年5月）で `prevent_destroy` に変数を渡せるようになった（dynamic prevent_destroy）。「本番だけdestroy禁止」を1つのモジュールで表現できる:

```hcl
lifecycle {
  prevent_destroy = var.environment == "production"
}
```

Terraform本家は静的値のみなので、この書き方はOpenTofu専用。

## 参考リンク

- [Terraformガイド](Terraformガイド.md) — ツール基礎・コマンド
- [Terraform Style Guide（公式）](https://developer.hashicorp.com/terraform/language/style)
- [Terraform Best Practices (community)](https://www.terraform-best-practices.com/)
- [モダンAWS構築ガイド2026](モダンAWS構築ガイド2026.md)
