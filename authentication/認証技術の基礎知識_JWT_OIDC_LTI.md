---
title: "認証技術の基礎知識: JWT / OIDC / LTI"
category: "authentication"
tags: [JWT, OIDC, LTI, 認証, 教育プラットフォーム]
created: 2026-01-06
updated: 2026-01-06
---

# 認証技術の基礎知識: JWT / OIDC / LTI

## 概要

LTI連携を理解するための認証技術の基礎知識を整理したドキュメント。JWT、OIDC、LTIの基本概念から実装時の考慮事項までを網羅する。

---

## 1. JWT (JSON Web Token)の基礎

### JWTとは

**JSON Web Token (JWT)** は、JSON形式の情報を安全にやり取りするためのトークン形式。

**読み方**:
- **ジョット** (英語: "jot" /dʒɒt/)
- 一部では「ジェイダブリュティー」と読む人もいるが、業界では「ジョット」が一般的

- **RFC 7519**で標準化
- **署名付き**で改ざん検知が可能
- **コンパクト**でURLやHTTPヘッダーに埋め込みやすい
- 主に**認証・認可**で使用

### JWTの構造

JWTは3つの部分から構成される：

```
[Header].[Payload].[Signature]
```

#### 具体例（Base64エンコード済み）

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2V4YW1wbGUuY29tIiwic3ViIjoidXNlcjEyMyIsImV4cCI6MTcwNDcwMDgwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

#### 各部分の役割

| 部分 | 内容 | 例（デコード後） |
|------|------|-----------------|
| **Header** | アルゴリズム・タイプ情報 | `{"alg":"RS256","typ":"JWT"}` |
| **Payload** | **Claim（主張）が格納される** | `{"iss":"https://example.com","sub":"user123","exp":1704700800}` |
| **Signature** | 改ざん検証用の署名 | （バイナリデータ） |

#### 重要: PayloadとClaimの関係

**JWTのPayloadに入れた情報は、全てClaimとして扱われる**

- Payloadに何かKey-Valueペアを追加したら、それは自動的に「Claim」になる
- 「Claimじゃない普通のKey-Value」をPayloadに入れることは概念的に存在しない
- 標準Claim（iss, sub, exp等）もカスタムClaimも、等しく「Claim」

**理由**: JWTは署名付きなので、Payloadに入れた情報は全て「発行者が保証する主張（Claim）」になる

```
PayloadにKey-Valueを追加
    ↓
署名で保護される
    ↓
発行者が保証する情報になる
    ↓
それが「Claim（主張）」の定義
```

**まとめ**:
- **Payload = Claimの集合**
- Payloadに入れたものは全てClaim扱い

### JWTの検証フロー

```
1. JWTを受け取る
   ↓
2. Signatureを検証（改ざんされてないか）
   ↓
3. Payloadの各Claimを検証（有効期限切れてないか等）
   ↓
4. 検証成功 → 信頼できる情報として使用
```

---

## 2. Claim（クレーム）とは

### Claimの定義

**Claim = 「主張」「請求」**

JWTやOIDCの文脈では：
- **トークンに含まれる情報の断片**
- **発行者が保証する信頼できる情報**
- **Key-Valueペア形式**で表現される

### Key-Valueとの違い

| 観点 | Key-Value | Claim |
|------|-----------|-------|
| **データ構造** | Key-Valueペア | Key-Valueペア（同じ） |
| **意味** | ただの情報 | **信頼できる主張** |
| **検証** | なし | **署名で検証可能** |
| **文脈** | 汎用 | 認証・認可専用 |
| **信頼性** | 不明 | **発行者が保証** |

### 比喩

- **Key-Value**: メモ帳に書かれた情報（誰が書いたか不明）
- **Claim**: 政府発行の身分証明書に書かれた情報（発行者が保証、署名付き）

### 標準的なClaim（RFC 7519）

| Claim名 | 意味 | 例 |
|---------|------|-----|
| `iss` | Issuer（発行者） | `"https://platform.example.com"` |
| `sub` | Subject（主体・ユーザーID） | `"user12345"` |
| `aud` | Audience（対象サービス） | `"https://tool.example.com"` |
| `exp` | Expiration（有効期限） | `1704700800` (Unix timestamp) |
| `iat` | Issued At（発行時刻） | `1704697200` (Unix timestamp) |
| `nbf` | Not Before（有効開始時刻） | `1704697200` (Unix timestamp) |
| `jti` | JWT ID（トークンの一意識別子） | `"jwt-abc123"` |

**nbf（Not Before）について**:
- 通常は`iat`と同じ値、または省略される
- 検証時に`nbf > 現在時刻`だと「Token not yet valid」エラーになる
- **時刻ズレ（Clock Skew）に注意**: サーバー間の時刻が数秒ズレてるだけでエラーになる可能性
- まれに、Clock Skew対策として`nbf`を`iat`より数秒前に設定することもある
- 対策: 検証側でClock Skew許容（±30〜60秒）を設定するのが一般的

### カスタムClaim

標準Claim以外に、独自の情報を追加できる：

```json
{
  "iss": "https://example.com",
  "sub": "user123",
  "exp": 1704700800,
  "name": "田中太郎",           // カスタムClaim
  "email": "tanaka@example.com", // カスタムClaim
  "role": "student"              // カスタムClaim
}
```

---

## 3. OIDC (OpenID Connect)の基礎

### OIDCとは

**OpenID Connect (OIDC)** は、OAuth 2.0の上に構築された**認証プロトコル**。

- **OAuth 2.0**: 認可（何ができるか）のプロトコル
- **OIDC**: 認証（誰か）+ 認可のプロトコル

### OIDCの特徴

- **IDトークン**（JWT形式）を使ってユーザー情報を伝達
- **UserInfoエンドポイント**でユーザー属性を取得可能
  - IDトークンに含まれない詳細情報（住所、電話番号等）をHTTP APIで取得
  - エンドポイント例: `https://idp.example.com/userinfo`
  - アクセストークンで認証してユーザー情報を取得
- **標準化された認証フロー**

### OIDC認証フロー（Authorization Code Flow）

```
1. ユーザーがログインボタンをクリック
   ↓
2. IdP（Identity Provider）にリダイレクト
   ↓
3. IdPでユーザーが認証（ログイン）
   ↓
4. 認証コードを持ってアプリにリダイレクト（コールバック）
   ↓
5. アプリが認証コードをIdPに送信
   ↓
6. IdPがIDトークン + アクセストークンを返却
   ↓
7. アプリがIDトークンを検証してログイン完了
```

### OIDCで使われる主要なClaim

IDトークンには以下のClaimが含まれる：

```json
{
  "iss": "https://idp.example.com",     // 発行者（IdP）
  "sub": "user12345",                    // ユーザーID
  "aud": "client_id_abc",                // クライアントID
  "exp": 1704700800,                     // 有効期限
  "iat": 1704697200,                     // 発行時刻
  "auth_time": 1704697100,               // 認証時刻
  "nonce": "random_string",              // リプレイ攻撃防止
  "name": "田中太郎",                     // ユーザー名
  "email": "tanaka@example.com",         // メールアドレス
  "email_verified": true                 // メール確認済み
}
```

---

## 4. LTI (Learning Tools Interoperability)の基礎

### LTIとは

**Learning Tools Interoperability (LTI)** は、教育プラットフォームと外部ツールを連携するための**教育分野特化プロトコル**。

- **IMS Global Learning Consortium**が策定
- Platform（学習管理システム）と外部教材（Tool）をシームレスに連携

### LTI 1.3とOIDCの関係

**LTI 1.3は、OIDCを基盤技術として使用**

```
LTI 1.3 = OIDC + 教育コンテキスト情報
```

- **OIDCは土台**（認証メカニズム）
- **LTIはその上の応用**（教育コンテキスト付き認証）

### LTI 1.3の事前登録（Platform ⇔ Tool連携設定）

LTI 1.3では、PlatformとToolが連携する前に**事前登録**が必要です。

#### 登録の流れ

**ステップ1: Tool管理者がPlatformに登録申請**
```
Tool管理者 → Platform管理者
「うちのツールを連携させたいので登録してください」

提供情報:
- Tool名
- /oidc/login のURL
- /lti/launch のURL
- 公開鍵（JWKS URL）
```

**ステップ2: Platform管理者がToolを登録**
```
Platform管理画面で登録:
- Tool名: "数学ドリル"
- client_id: "tool_client_id_abc123" ← Platform側が発行
- deployment_id: "deployment_1" ← Platform側が発行
- Tool側のエンドポイント情報を保存
```

**ステップ3: Platform管理者がTool側に情報を伝える**
```
Platform管理者 → Tool管理者
「登録完了しました。以下の情報を設定してください」

提供情報:
- Platform発行者URL (iss): https://platform.example.com
- client_id: tool_client_id_abc123
- deployment_id: deployment_1
- Platformの /authorize URL
- Platform の公開鍵（JWKS URL）
```

**ステップ4: Tool管理者がPlatform情報を登録**
```
Tool管理画面で登録:
- Platform名: "○○学校LMS"
- iss: https://platform.example.com
- client_id: tool_client_id_abc123
- deployment_id: deployment_1
- Platform の /authorize URL
- Platform の JWKS URL
```

#### Platform側が管理する情報

| 項目 | 説明 | 例 |
|------|------|-----|
| Tool名 | 表示名 | "数学ドリル" |
| client_id | Platform側が発行 | "tool_123" |
| deployment_id | Platform側が発行（学校・環境単位） | "school_001" |
| Tool の /oidc/login URL | Tool側エンドポイント | `https://tool.example.com/oidc/login` |
| Tool の /lti/launch URL | Tool側エンドポイント | `https://tool.example.com/launch` |
| Tool の JWKS URL | Tool側の公開鍵 | `https://tool.example.com/.well-known/jwks.json` |

#### Tool側が管理する情報

| 項目 | 説明 | 例 |
|------|------|-----|
| Platform名 | 表示名 | "○○学校LMS" |
| iss | Platform識別子 | `https://platform.example.com` |
| client_id | Platformから受け取る | "tool_123" |
| deployment_id | Platformから受け取る | "school_001" |
| Platform の /authorize URL | Platform側エンドポイント | `https://platform.example.com/authorize` |
| Platform の JWKS URL | Platform側の公開鍵 | `https://platform.example.com/.well-known/jwks.json` |

#### 事前登録が必要な理由

**セキュリティ**:
- 信頼できるPlatform/Toolだけと連携
- 公開鍵を事前交換してJWT検証
- 不正なアクセスを防止

**相互運用性**:
- お互いのエンドポイントURLを知る必要がある
- 標準に準拠していれば、どのPlatform/Toolでも連携可能

### マルチテナント環境での`iss`と`deployment_id`

マルチテナント型のPlatform（各テナントでサブドメインが異なる等）では、`iss`と`deployment_id`の使い分けが重要です。

#### アプローチの選択肢

**パターン1: 共通のissを使う（推奨）**
```
全テナント共通:
iss = "https://auth.platform.example.com"

各テナントはdeployment_idで識別:
- テナントA: deployment_id = "tenant_a"
- テナントB: deployment_id = "tenant_b"
- 学校A: deployment_id = "school_a"
```

**パターン2: テナント別のissを使う（非推奨）**
```
テナントごとに異なる:
- テナントA: iss = "https://tenant-a.platform.example.com"
- テナントB: iss = "https://tenant-b.platform.example.com"
```

#### 推奨アプローチ（パターン1）の利点

**Tool側の管理が簡単**:
- Tool側の登録が1回で済む
- 新しいテナントが増えても再登録不要
- Platform側の公開鍵（JWKS）が1つで済む

**LTI標準の設計思想に準拠**:
- `iss`: Platform全体を識別
- `deployment_id`: Platform内の「デプロイ単位」を識別
  - テナント識別
  - 学校識別
  - 環境識別（本番/ステージング）

**実装例**:
```
ユーザーアクセス: https://tenant-a.platform.example.com
↓
Tool側にリダイレクト（iss付き）
iss = "https://auth.platform.example.com"  ← 認証専用の共通ドメイン
deployment_id = "tenant_a"  ← テナント識別

JWT検証用の公開鍵も共通:
https://auth.platform.example.com/.well-known/jwks.json
```

#### deployment_idの役割

`deployment_id`は**LTI 1.3で標準的に用意されたマルチテナント対応の仕組み**です：

**用途例**:
- 同じPlatformが複数の学校にサービス提供
- 本番環境とステージング環境の区別
- 企業内の部門ごとの分離

**Tool側の対応**:
- 全deployment_idを許可（ワイルドカード）
- 特定のdeployment_idのみ許可（個別登録）

#### パターン2（テナント別iss）の問題点

**管理コストが高い**:
- Tool側が各テナントごとに登録が必要
- テナント追加のたびに再登録
- 公開鍵管理が複雑化
- スケーラビリティが低い

**標準からの逸脱**:
- `deployment_id`の本来の目的を無視
- 相互運用性が低下

### LTI 1.3の起動フロー

```
1. OIDC Login (第三者起動フロー)
   [ユーザー] Platformで教材リンクをクリック
   ↓ GET /oidc/login
   [Tool API] リクエストを受信・検証

2. OIDC認証リクエスト
   [Tool API] Platform認証エンドポイントにリダイレクト（302等）
   ↓ Redirect to /authorize
   [Platform API] 認証・JWT生成

3. LTI Launch (JWT with LTI Claims)
   [Platform API] JWTを含むPOSTリクエストをToolに送信
   ↓ POST /lti/launch (id_token=JWT)
   [Tool API] JWTを受信

4. IDトークンを検証
   [Tool] JWTの署名検証・Claim検証
   ↓
5. 教材・ツールを起動
   [Tool] ユーザーに教材画面を表示
```

**ポイント**:
- ステップ1: ユーザーのブラウザアクション → Tool側API呼び出し
- ステップ2: **Tool側API**がPlatform側にリダイレクト
- ステップ3: **Platform側API**がJWTを生成してTool側にPOST

### LTI 1.3の起動フロー（詳細版：実データ付き）

#### ステップ1: ユーザーがPlatformで教材リンクをクリック

**Platform側HTMLの例**:
```html
<a href="https://tool.example.com/oidc/login?iss=https://platform.example.com&login_hint=user123&target_link_uri=https://tool.example.com/launch&lti_message_hint=abc123&client_id=tool_client_id&lti_deployment_id=deployment_1">
  数学の問題を開く
</a>
```

**必須パラメータ**:

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `iss` | 必須 | Platformの発行者URL | `https://platform.example.com` |
| `login_hint` | 必須 | ユーザー識別子 | `user123` |
| `target_link_uri` | 必須 | 最終的な起動先URL | `https://tool.example.com/launch` |
| `client_id` | オプション | クライアントID | `tool_client_id` |
| `lti_message_hint` | オプション | Platform側が任意の情報を渡せる | `abc123` |
| `lti_deployment_id` | オプション | デプロイメントID | `deployment_1` |

#### ステップ2: Tool側が`/oidc/login`でリクエスト受信してリダイレクト

**Tool側が受け取るリクエスト**:
```http
GET /oidc/login?iss=https://platform.example.com&login_hint=user123&target_link_uri=https://tool.example.com/launch&client_id=tool_client_id&lti_message_hint=abc123&lti_deployment_id=deployment_1 HTTP/1.1
Host: tool.example.com
```

**Tool側の処理**:
1. `iss`を見て「どのPlatformから来たか」判断
2. 事前登録されたPlatform設定を取得
3. Platformの`/authorize`エンドポイントURLを特定
4. OIDC認証リクエストパラメータを生成してリダイレクト

**Tool側のレスポンス例**:
```http
HTTP/1.1 302 Found
Location: https://platform.example.com/authorize?response_type=id_token&response_mode=form_post&scope=openid&client_id=tool_client_id&redirect_uri=https://tool.example.com/launch&state=state_xyz&nonce=nonce_abc&prompt=none&login_hint=user123&lti_message_hint=abc123
```

**OIDC認証リクエストの必須パラメータ**:

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `response_type` | 必須 | `id_token` | `id_token` |
| `response_mode` | 必須 | `form_post` | `form_post` |
| `scope` | 必須 | `openid` | `openid` |
| `client_id` | 必須 | クライアントID | `tool_client_id` |
| `redirect_uri` | 必須 | Tool側のコールバックURL | `https://tool.example.com/launch` |
| `state` | 必須 | CSRF対策の一意な文字列 | `state_xyz` |
| `nonce` | 必須 | リプレイ攻撃防止 | `nonce_abc` |
| `prompt` | 必須 | `none`（再認証させない） | `none` |
| `login_hint` | 必須 | ステップ1から引き継ぎ | `user123` |
| `lti_message_hint` | オプション | ステップ1から引き継ぎ | `abc123` |

#### ステップ3: Platform側が`/authorize`でJWT生成してPOST

**Platform側が受け取るリクエスト**:
```http
GET /authorize?response_type=id_token&response_mode=form_post&scope=openid&client_id=tool_client_id&redirect_uri=https://tool.example.com/launch&state=state_xyz&nonce=nonce_abc&prompt=none&login_hint=user123&lti_message_hint=abc123 HTTP/1.1
Host: platform.example.com
```

**Platform側のレスポンス（form_post）**:
```http
HTTP/1.1 200 OK
Content-Type: text/html

<html>
<body onload="document.forms[0].submit()">
  <form method="POST" action="https://tool.example.com/launch">
    <input type="hidden" name="id_token" value="eyJhbGc...（JWT）" />
    <input type="hidden" name="state" value="state_xyz" />
  </form>
</body>
</html>
```

**id_token（JWT）の中身（デコード後）**:
```json
{
  "iss": "https://platform.example.com",
  "sub": "user123",
  "aud": "tool_client_id",
  "exp": 1704707200,
  "iat": 1704703600,
  "nonce": "nonce_abc",

  "https://purl.imsglobal.org/spec/lti/claim/message_type": "LtiResourceLinkRequest",
  "https://purl.imsglobal.org/spec/lti/claim/version": "1.3.0",
  "https://purl.imsglobal.org/spec/lti/claim/deployment_id": "deployment_1",
  "https://purl.imsglobal.org/spec/lti/claim/target_link_uri": "https://tool.example.com/launch",
  "https://purl.imsglobal.org/spec/lti/claim/resource_link": {
    "id": "resource_123",
    "title": "数学の問題"
  },
  "https://purl.imsglobal.org/spec/lti/claim/roles": [
    "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
  ],
  "https://purl.imsglobal.org/spec/lti/claim/context": {
    "id": "course_456",
    "label": "中学3年 数学",
    "title": "2024年度 数学コース"
  }
}
```

**LTI Launch JWTの主要Claim**:

| Claim | 必須 | 説明 | 例 |
|-------|------|------|-----|
| `iss` | 必須 | 発行者（Platform） | `https://platform.example.com` |
| `sub` | 必須 | ユーザーID | `user123` |
| `aud` | 必須 | 対象（Tool） | `tool_client_id` |
| `exp` | 必須 | 有効期限 | `1704707200` |
| `iat` | 必須 | 発行時刻 | `1704703600` |
| `nonce` | 必須 | ステップ2から引き継ぎ | `nonce_abc` |
| `message_type` | 必須 | メッセージタイプ | `LtiResourceLinkRequest` |
| `version` | 必須 | LTIバージョン | `1.3.0` |
| `deployment_id` | 必須 | デプロイメントID | `deployment_1` |
| `target_link_uri` | 必須 | 起動先URI | `https://tool.example.com/launch` |
| `resource_link` | 必須 | リソース情報 | `{"id":"resource_123"}` |
| `roles` | オプション | ユーザーロール | `["Learner"]` |
| `context` | オプション | コース情報 | `{"id":"course_456"}` |

### LTI独自のClaim

LTI 1.3では、OIDC標準Claimに加えて**LTI独自のClaim**が追加される：

```json
{
  // OIDC標準のClaim
  "iss": "https://platform.example.com",
  "sub": "user123",
  "aud": "client_id_123",
  "exp": 1704700800,

  // LTI独自のClaim（教育コンテキスト情報）
  "https://purl.imsglobal.org/spec/lti/claim/message_type": "LtiResourceLinkRequest",
  "https://purl.imsglobal.org/spec/lti/claim/version": "1.3.0",
  "https://purl.imsglobal.org/spec/lti/claim/deployment_id": "deployment-123",
  "https://purl.imsglobal.org/spec/lti/claim/target_link_uri": "https://tool.example.com/launch",
  "https://purl.imsglobal.org/spec/lti/claim/resource_link": {
    "id": "resource-123",
    "title": "数学の問題"
  },
  "https://purl.imsglobal.org/spec/lti/claim/roles": [
    "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
  ],
  "https://purl.imsglobal.org/spec/lti/claim/context": {
    "id": "course-456",
    "label": "中学3年 数学",
    "title": "2024年度 数学コース"
  }
}
```

### LTI Deep Linkingとは

**LTI Deep Linking** は、LTI 1.3の機能の一つ。

- **教材選択・登録フロー**を提供
- 教師がPlatformから外部Toolの教材を選択
- 選択した教材情報をPlatformに返却して登録

---

## 5. 実装時の考慮事項

### OIDCを実装する場合

**必要なエンドポイント**:
- **ログインエンドポイント**: ユーザーがIdPへリダイレクトされる起点
- **コールバックエンドポイント**: IdPから戻ってくる先（例: `/oidc/callback`）
- **ログアウトエンドポイント**: セッションを破棄

**実装時の注意点**:
- IDトークンの署名検証を必ず行う
- `exp`（有効期限）Claimの検証
- `aud`（Audience）が自サービスのクライアントIDと一致するか確認
- `nonce`によるリプレイ攻撃防止

### LTIを実装する場合

#### Platform側（LMS側）が用意すべきエンドポイント

| エンドポイント | 役割 | HTTPメソッド | 呼び出し元 |
|-------------|------|------------|-----------|
| **OIDC認証エンドポイント** | 認証リクエストを受け取りJWTを生成 | GET | Tool（ブラウザ経由） |
| 例: `/authorize` | | | |
| **JWKS（公開鍵配信）** | JWTの署名検証用の公開鍵を配信 | GET | Tool |
| 例: `/.well-known/jwks.json` | | | |
| **Tokenエンドポイント**（オプション） | アクセストークン発行 | POST | Tool |
| 例: `/token` | LTI Advantage使用時に必要 | | |

#### Tool側（教材アプリ側）が用意すべきエンドポイント

| エンドポイント | 役割 | HTTPメソッド | 呼び出し元 |
|-------------|------|------------|-----------|
| **OIDC Loginエンドポイント** | 第三者起動の開始点 | GET | Platform（ブラウザ経由） |
| 例: `/oidc/login` | | | |
| **LTI Launchエンドポイント** | JWTを受け取り教材を起動 | POST | Platform（ブラウザ経由） |
| 例: `/lti/launch` | | | |
| **JWKS（公開鍵配信）** | JWTの署名検証用の公開鍵を配信 | GET | Platform |
| 例: `/.well-known/jwks.json` | | | |
| **Deep Linkエンドポイント**（オプション） | 教材選択・登録 | POST | Platform（ブラウザ経由） |
| 例: `/lti/deep_link` | Deep Linking使用時 | | |

#### 標準LTI 1.3のフロー（エンドポイント付き）

```
1. ユーザーがPlatformで教材リンクをクリック
   Platform HTML: <a href="https://tool.example.com/oidc/login?...">
   ↓ GET /oidc/login

2. Tool側がOIDC Login受付
   [Tool API] /oidc/login
   ↓ 302 Redirect
   Location: https://platform.example.com/authorize?...

3. PlatformがJWT生成してToolに送信
   [Platform API] /authorize → JWT生成
   ↓ POST /lti/launch (id_token=JWT)
   [Tool API] /lti/launch

4. ToolがJWT検証
   Tool → Platform: GET /.well-known/jwks.json（公開鍵取得）
   Tool: JWT署名検証・Claim検証
   ↓
5. 教材画面を表示
```

#### 実装時の注意点

- LTI JWTの署名検証（Platform公開鍵を使用）
- 必須Claimの検証（message_type, version, deployment_id等）
- `exp`（有効期限）の検証
- LTI独自Claimの取得と活用（roles, context等）
- **相互運用性**: 標準に準拠しないと他のPlatform/Toolと接続できない

#### HTTPリダイレクトとキャッシュ問題（重要）

**問題**: LTI 1.3のOIDC Login（ステップ2）でのリダイレクトレスポンスがブラウザにキャッシュされ、古いJWTが再利用される問題

##### 発生メカニズム

```
1回目のアクセス:
  GET /oidc/login → Tool側が新しいJWT生成
  ↓ 301 Redirect（JWTをURLパラメータに含む）
  ブラウザがこの301レスポンスをキャッシュ

2回目以降のアクセス（数時間後）:
  GET /oidc/login → ブラウザがキャッシュから301レスポンスを取得
  ↓ サーバーにリクエストせず、キャッシュされた古いJWTで遷移
  ↓ JWTが有効期限切れ（通常60秒）
  → 401 Unauthorized エラー
```

##### HTTPメソッドによる違い

| HTTPメソッド | ブラウザのキャッシュ動作 | 問題発生 |
|------------|---------------------|---------|
| **GET** | 301レスポンスを積極的にキャッシュする | 発生する |
| **POST** | 301レスポンスをキャッシュしない傾向 | 発生しない |

**理由**: HTTPの仕様上、GETは「べき等」（何度実行しても同じ結果）とされるため、ブラウザは積極的にキャッシュする。POSTは「副作用がある」とされ、キャッシュされない。

##### 正しいHTTPステータスコードの選択

**301 Moved Permanently（使用禁止）**:
- 「永続的なリダイレクト」を意味する
- ブラウザが積極的にキャッシュする
- 動的なパラメータ（JWT等）を含むリダイレクトには不適切

**302 Found（推奨）**:
- 「一時的なリダイレクト」を意味する
- OpenID Connect仕様の例で使用されている
- LTI実装例でも一般的に使用されている
- 最も広くサポートされている

**307 Temporary Redirect（代替案）**:
- 一時的なリダイレクト（HTTPメソッドを保持）
- 302より厳密な仕様
- 問題なし

##### 必須対応: Cache-Controlヘッダーの設定

**どのステータスコードを使う場合でも、Cache-Controlヘッダーは必須**:

```http
HTTP/1.1 302 Found
Location: https://platform.example.com/authorize?...
Cache-Control: no-cache, no-store, must-revalidate
Pragma: no-cache
Expires: 0
```

**各ヘッダーの意味**:
- `Cache-Control: no-cache, no-store`: キャッシュを禁止
- `must-revalidate`: キャッシュがある場合でも必ず再検証
- `Pragma: no-cache`: HTTP/1.0互換性のため
- `Expires: 0`: 即座に期限切れ

##### 実装例（Scala + Pekko HTTP）

**悪い例（301 + Cache-Control無し）**:
```scala
HttpResponse.apply(
  status = StatusCodes.MovedPermanently,  // NG: 301
  headers = Seq(
    Location(uri.withQuery(Query(params*)))
  )
)
```

**良い例（302 + Cache-Control）**:
```scala
import org.apache.pekko.http.scaladsl.model.headers.`Cache-Control`
import org.apache.pekko.http.scaladsl.model.CacheDirectives

HttpResponse.apply(
  status = StatusCodes.Found,  // OK: 302
  headers = Seq(
    Location(uri.withQuery(Query(params*))),
    `Cache-Control`(CacheDirectives.`no-cache`, CacheDirectives.`no-store`)
  )
)
```

##### 根拠となる仕様

**OpenID Connect Core 1.0**:
- Section 3.1.2.1（Authentication Response）で302リダイレクトの例が記載

**IMS Security Framework 1.0**:
- LTI 1.3が使用するセキュリティフレームワーク
- Section 5.1.1でOpenID Connect Third Party Initiated Loginを説明

**注意**: LTI 1.3仕様では明示的に「302を使え」という記載はないが、OpenID Connect仕様の例や各種実装で302が使用されている。301（永続的リダイレクト）は明らかに不適切。

### よくあるエラーと対処

#### Invalid claim headerエラー

**原因**:
- JWTの検証に失敗
- 特に`exp`（有効期限）Claimが期限切れ
- 必須Claimが欠けている
- Claimの形式が不正

**対処**:
1. JWTをデコードして内容確認（[jwt.io](https://jwt.io/)等を利用）
2. `exp`のタイムスタンプを確認（現在時刻と比較）
3. 必須Claimが全て含まれているか確認
4. 署名検証に使用する公開鍵が正しいか確認

**LTIでの特有の問題**:
- Platform側のJWT有効期限が短すぎる設定になっている
- ネットワーク遅延でJWTが期限切れになる
- 時刻同期（NTP）のズレ

#### Audience mismatchエラー

**原因**:
- `aud` ClaimがクライアントIDと一致しない

**対処**:
- IdP/Platformに登録したクライアントIDを確認
- 複数のクライアントIDが必要な場合は`aud`を配列で受け取る

---

## 6. 用語集

| 用語 | 英語 | 意味 |
|------|------|------|
| JWT | JSON Web Token | JSON形式の署名付きトークン |
| Claim | Claim | トークンに含まれる信頼できる情報 |
| OIDC | OpenID Connect | OAuth 2.0ベースの認証プロトコル |
| LTI | Learning Tools Interoperability | 教育分野の連携プロトコル |
| Platform | Platform | LTI 1.3での学習管理システム（LMS）側。教材を配信・管理する側 |
| Tool | Tool | LTI 1.3での外部教材・アプリケーション側。Platformから起動される側 |
| LMS | Learning Management System | 学習管理システム（LTI 1.3ではPlatformと呼ぶ） |
| IdP | Identity Provider | 認証プロバイダー（認証サービス提供者） |
| iss | Issuer | 発行者 |
| sub | Subject | 主体（ユーザーID） |
| aud | Audience | 対象サービス |
| exp | Expiration | 有効期限 |
| iat | Issued At | 発行時刻 |

## 参考リンク

### JWT / OIDC
- [RFC 7519 - JWT公式仕様](https://datatracker.ietf.org/doc/html/rfc7519)
- [OpenID Connect 公式](https://openid.net/connect/)
- [JWT.io - JWT Debugger](https://jwt.io/)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)

### LTI 1.3（公式）
- [IMS Global LTI 1.3 Core仕様](https://www.imsglobal.org/spec/lti/v1p3/)
- [LTI 1.3 Implementation Guide](https://www.imsglobal.org/spec/lti/v1p3/impl)
- [Security Framework - OIDC Third Party Login](https://www.imsglobal.org/spec/security/v1p0/#step-1-third-party-initiated-login)
- [LTI Deep Linking 2.0](https://www.imsglobal.org/spec/lti-dl/v2p0/)
- [LTI参考実装 - PHP Library](https://github.com/IMSGlobal/lti-1-3-php-library)
- [IMS Security Framework 1.0](https://www.imsglobal.org/spec/security/v1p0/)

### LTI 1.3（日本語解説）
- [Qiita - LTI Coreの通信フロー](https://qiita.com/Hiroki_Kobari/items/c9054769efad0f6b2822) - ResourceLinkRequestによるツール起動フローを3パートで詳しく解説
- [L-Gate管理者マニュアル - LTI接続フロー](https://www.info.l-gate.net/admin_manual/lti1-3-connect-flow/) - 実システムでの3ステップ解説
