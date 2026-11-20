---
title: "MySQL 9.7 LTS新機能まとめ"
category: "database"
tags: [MySQL, MySQL9, LTS, アップグレード, レプリケーション]
created: 2026-07-28
updated: 2026-07-28
related: ["MySQL_5x_から_8x_設定変更まとめ.md"]
---

# MySQL 9.7 LTS新機能まとめ

## 概要

2026-04-21にGAとなったMySQL 9.7.0 LTSの新機能まとめ。8.4 LTS以来の新LTS系列で、9.x innovation系列の成果を安定版として標準化できるようになった。8.4からのアップグレード判断の材料を整理する。

---

## 1. リリースの位置づけ

- **8.4 LTS（2024年）以来の新しいLTS**。9.0〜9.6のinnovationリリースの集大成
- LTSはOracle Lifetime Support Policyに従い、**Premier Support 5年＋Extended Support 3年**
- 8.4系は引き続きサポートされるので、慌てて上げる必要はない

## 2. Community Editionへの機能開放

これまでEnterprise Edition専用だった機能がCEで使えるようになった（9.7の目玉）:

- **Replication Applier Metrics** — レプリケーション適用の可観測性
- **Group Replication Flow Control Statistics / Resource Manager / Primary Election** — グループレプリケーションの統計・制御
- **Telemetry** — テレメトリ

レプリケーション運用の可視性が課金なしで手に入るのは大きい。

## 3. その他の新機能

- **Hypergraphオプティマイザ**の強化 — 複雑なJOINの最適化
- **OpenID認証** — OIDCでのDB認証
- **MySQL Server REST Service** の拡張
- **In-database JavaScript** — DB内でのJavaScriptプログラミング
- **JSON duality** — JSONとリレーショナルの双方向ビュー
- **Dynamic Data Masking**（こちらはEnterprise Edition向け）

## 4. アップグレード判断の目安

- **8.4で困っていなければ急がない**。LTS→LTSの移行はサポート期限と必要機能で判断する
- **レプリケーション/Group Replicationの運用可視性が欲しいなら9.7の価値が高い**（CE開放機能が直撃）
- 5.x/8.0系からの移行なら、まず[MySQL 5.x → 8.x 設定変更まとめ](database/MySQL_5x_から_8x_設定変更まとめ.md)で8系の変更を消化してから

## 参考リンク

- [MySQL 9.7 LTS Is Here（Oracle公式ブログ）](https://blogs.oracle.com/mysql/mysql-9-7-lts-is-here-upgrade-and-modernize-on-a-stronger-community-edition)
- [MySQL 9.7.0 LTS Is Now Available（Oracle公式ブログ）](https://blogs.oracle.com/mysql/mysql-9-7-0-lts-is-now-available-expanded-community-capabilities-and-dynamic-data-masking-for-enterprise)
- [MySQL 9.7: First Major LTS Since 8.4（InfoQ）](https://www.infoq.com/news/2026/05/mysql-97-lts/)
- [Inside MySQL 9.7 LTS Features（Percona）](https://www.percona.com/blog/inside-mysql-9-7-lts-features/)
- [MySQL Releases: Innovation and LTS（公式マニュアル）](https://dev.mysql.com/doc/refman/9.7/en/mysql-releases.html)
