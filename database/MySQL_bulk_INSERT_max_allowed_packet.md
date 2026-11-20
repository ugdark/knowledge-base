---
title: "MySQL bulk INSERT と max_allowed_packet"
category: "database"
tags: [MySQL, bulk-INSERT, max_allowed_packet, JDBC, rewriteBatchedStatements, ScalikeJDBC, Slick, パフォーマンス]
created: 2026-06-10
updated: 2026-06-10
---

# MySQL bulk INSERT と max_allowed_packet

## max_allowed_packet のバージョン別デフォルト値

| バージョン | デフォルト値 |
|-----------|------------|
| MySQL 5.6 以前 | 4 MB |
| MySQL 5.7 以降 | 64 MB |
| MySQL 8.0 / 8.4 | 64 MB（サーバー）/ 16 MB（クライアント） |

---

## bulk INSERT のサイズ試算

行サイズが小さいテーブルは意外と余裕がある。

例：`binary(16) × 2 + int × 2 + varchar(16)` 構成の場合

- 1行あたり約 50〜100 bytes
- 5,000行 × 100 bytes = **500 KB**
- MySQL 5.6 以前の 4 MB 制限に対しても 1/8 以下

→ 小さい行サイズなら 5,000 件を1本の multi-row INSERT に収めても問題ない。

大きなデータが絡む場合の目安：

| 1行のサイズ | 4 MB に収まる行数 | 64 MB に収まる行数 |
|-----------|-----------------|------------------|
| 100 bytes | 約 40,000 行 | 約 640,000 行 |
| 1 KB | 約 4,000 行 | 約 65,000 行 |
| 10 KB | 約 400 行 | 約 6,500 行 |

---

## rewriteBatchedStatements=true が必要なケース

### ScalikeJDBC / JDBC の addBatch()

ScalikeJDBC の batch 系メソッドは内部で JDBC の `addBatch()` / `executeBatch()` を使うため、
この設定がないと **N 本の個別 INSERT** がそのまま発行される。

```
jdbc:mysql://host:3306/db?rewriteBatchedStatements=true
```

設定することで複数の INSERT が **1本の multi-row INSERT** に書き換えられる。
ベンチマークでは最大 **7倍の性能改善** が報告されている。

### Slick / PreparedStatement で SQL を直接組み立てる場合

```scala
// VALUES (?,?,...),(?,?,...),... と組み立てる場合
SimpleJdbcAction + PreparedStatement.executeUpdate()
```

最初から 1 本の multi-row INSERT なので `rewriteBatchedStatements` は不要。

---

## 分割が必要になるケース

- **TEXT/BLOB に大きなデータを格納する行**（1行 10 KB なら 4 MB で約 400 行）
- **レプリケーション遅延を抑えたい環境**（大きなトランザクションは binlog が膨らむ）
- **古い MySQL 5.6 以前の環境**（max_allowed_packet = 4 MB がデフォルト）

---

## net_buffer_length との関係

- `net_buffer_length`：初期バッファサイズ（最大 1 MB、デフォルトは小さい）
- `max_allowed_packet`：動的拡張の上限

接続バッファは `net_buffer_length` で初期化され、必要に応じて `max_allowed_packet` まで自動拡張される。
各ステートメント完了後、バッファは `net_buffer_length` サイズに縮小される。

---

## binlog と大きなトランザクション

MySQL 8.0 以降は `log_bin=ON` がデフォルト。大きな INSERT は binlog が膨らむ。

- `binlog_row_image=MINIMAL`（デフォルト）：必要な列のみ記録。サイズ削減に有効
- `sync_binlog=1`（デフォルト）：SSD/NVMe なら影響軽微。HDD では大きな遅延要因

---

## 参考

- [MySQL 8.4 Reference - max_allowed_packet](https://dev.mysql.com/doc/refman/8.4/en/replication-features-max-allowed-packet.html)
- [MySQL JDBC Performance Extensions](https://dev.mysql.com/doc/connectors/en/connector-j-connp-props-performance-extensions.html)
- [rewriteBatchedStatements パフォーマンス検証](https://vladmihalcea.com/mysql-rewritebatchedstatements/)
