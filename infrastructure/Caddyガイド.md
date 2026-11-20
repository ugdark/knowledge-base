---
title: "Caddyガイド"
category: "infrastructure"
tags: [caddy, webserver, HTTPS, reverse-proxy, nginx代替]
created: 2026-04-21
updated: 2026-04-21
---

# Caddyガイド

## 概要

Go製のモダンなHTTP/1-2-3対応Webサーバー。**自動HTTPS**（Let's Encrypt標準統合）と**最小設定**が最大の特徴。nginx / Apache の新世代代替として、特に静的配信・リバースプロキシ用途で選ばれることが増えている。

---

## 1. 基本情報

| 項目 | 内容 |
|---|---|
| 作者 | Matt Holt（Stack Holdings社） |
| 初版リリース | 2015年 |
| 実装言語 | Go（単一バイナリ、依存なし） |
| ライセンス | Apache 2.0 |
| 公式 | <https://caddyserver.com/> |
| GitHub | [caddyserver/caddy](https://github.com/caddyserver/caddy)（Star約6万） |

## 2. 特徴（nginx比較）

| | nginx | Caddy |
|---|---|---|
| 自動HTTPS（Let's Encrypt） | 手動セットアップ | **標準搭載、設定なしで動く** |
| 設定ファイル | nginx.conf（独特文法） | Caddyfile（人間可読）/ JSON |
| 設定のサイズ感 | ベースライン | **nginxの15〜25%** の行数で同等 |
| HTTP/2 | ◯ | ◯ |
| HTTP/3 (QUIC) | 限定対応 | **デフォルト有効** |
| プロセスモデル | master + worker | シングルバイナリ + goroutine |
| 設定更新 | reload必要 | **APIでライブ更新可** |
| ワイルドカード証明書 | 手動 | **2026年以降デフォルト** |

## 3. Caddyfileの基本

人間可読な独自DSL。nginx.confより圧倒的に短い。

### 静的ファイル配信

```caddyfile
example.com {
    root * /var/www/html
    file_server
}
```

### リバースプロキシ

```caddyfile
api.example.com {
    reverse_proxy localhost:8080
}
```

### HTTPS+ロギング+gzip（最小構成）

```caddyfile
example.com {
    root * /var/www/html
    file_server
    encode gzip
    log {
        output file /var/log/caddy/access.log
    }
}
```

**自動HTTPS**: ドメイン名を書くだけでLet's Encryptの証明書が自動取得・自動更新される。

### 設定形式の選択

| 形式 | 特徴 |
|---|---|
| Caddyfile | 手書き推奨、人間可読 |
| JSON | Caddyのネイティブ形式、APIで流し込む時に使用 |
| YAML / TOML | config adapter経由で使用可 |
| nginx.conf | 変換アダプタあり（完全互換ではない） |

## 4. 主な用途

### 4.1 静的サイト配信

`caddy file-server` コマンド1発でカレントディレクトリを配信可能。

```bash
caddy file-server --listen :8080
```

Docker公式イメージは **`/usr/share/caddy` をデフォルト配信**するため、設定ファイルすら不要。

```bash
docker run --rm \
  -p 8080:80 \
  -v "$(pwd):/usr/share/caddy" \
  caddy:alpine
```

### 4.2 リバースプロキシ + 自動HTTPS

アプリサーバー（Node/Go/Rails等）の前段に置くだけで、HTTPS化完了。

```caddyfile
app.example.com {
    reverse_proxy localhost:3000
}
```

これだけで：
- Let's Encryptから証明書取得
- HTTP→HTTPS自動リダイレクト
- HTTP/2, HTTP/3対応
- 証明書自動更新

### 4.3 APIゲートウェイ

ルーティング、認証、レート制限、ヘッダ加工などをCaddyfileで記述可能。プラグイン拡張も豊富。

### 4.4 PHPアプリサーバー（FrankenPHP）

2025年以降、**FrankenPHP**（Caddy + PHPランタイム）という派生が登場。CaddyがPHPアプリサーバーとして機能し、**Swoole/RoadRunnerより約4倍高速**。

## 5. 2026年の主な機能アップデート

- **HTTP/3 (QUIC)** がデフォルト有効
- **ワイルドカード証明書** がサブドメイン向けでデフォルトに（ECH対応の副産物）
- **timberjack** ロガーで時刻ローテーション対応
- **Named socket activation** 対応
- **Caddy L4** (レイヤー4プロキシ) モジュールの成熟

## 6. 導入方法

### macOS

```bash
brew install caddy
```

### Linux (apt/yum)

公式リポジトリを追加してインストール。詳細は[公式ドキュメント](https://caddyserver.com/docs/install)。

### Docker

```bash
# 静的配信
docker run --rm -p 80:80 -v "$(pwd):/usr/share/caddy" caddy:alpine

# Caddyfile持ち込み
docker run --rm -p 80:80 \
  -v "$(pwd)/Caddyfile:/etc/caddy/Caddyfile" \
  -v caddy_data:/data \
  caddy:alpine
```

### Go経由（カスタムビルド）

```bash
go install github.com/caddyserver/caddy/v2/cmd/caddy@latest
```

プラグイン込みでビルドしたい場合は `xcaddy` ツールを使用。

## 7. こんな時に使うと良い

- **個人サイト/ブログ**: 自動HTTPS + 静的配信、設定数行
- **開発環境**: ローカルで本番に近いHTTPS環境を簡単に作れる
- **社内ツール**: リバースプロキシ + 認証の前段
- **PHPアプリ**: FrankenPHPでの高速化

## 8. 注意点

- **エンタープライズ実績**ではまだnginxの圧倒的シェアに及ばない（徐々に増加中）
- **プラグイン開発**にはGoの知識が必要
- **超高負荷環境**でのチューニング事例はnginxほど豊富ではない
- **Windows** でもバイナリ動作するが、UNIX系の方が設定例が豊富

## 9. 対抗ツールとの使い分け

| 用途 | おすすめ |
|---|---|
| 自動HTTPS重視の小〜中規模 | **Caddy** |
| 大規模・高チューニング・実績重視 | nginx |
| 古いApacheからの移行 | Apache継続 or Caddy |
| LB + WAF込みマネージド | AWS ALB / Cloudflare |
| K8sクラスタ内Ingress | ingress-nginx / Traefik / Caddy-ingress |

---

## 参考リンク

- [Caddy公式](https://caddyserver.com/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddy All Features](https://caddyserver.com/features)
- [caddyserver/caddy (GitHub)](https://github.com/caddyserver/caddy)
- [Caddy Docker Hub](https://hub.docker.com/_/caddy)
- [FrankenPHP](https://frankenphp.dev/)
