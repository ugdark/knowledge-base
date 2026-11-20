---
title: "MySQL 5.x → 8.x 設定変更まとめ"
category: "database"
tags: [MySQL, MySQL8, 設定変更, デフォルト値, 廃止パラメータ, アップグレード]
created: 2026-06-10
updated: 2026-07-28
---

# MySQL 5.x → 8.x 設定変更まとめ

MySQL 5.5〜5.6 時代の知識からのアップデート。8.0/8.4 で変わったデフォルト値・廃止パラメータを整理する。

---

## デフォルト値の主要変更（5.7 → 8.0）

| パラメータ | MySQL 5.7 | MySQL 8.0+ |
|-----------|----------|-----------|
| `log_bin` | OFF | **ON**（バイナリログがデフォルト有効） |
| `character_set_server` | latin1 | **utf8mb4** |
| `collation_server` | latin1_swedish_ci | **utf8mb4_0900_ai_ci** |
| `explicit_defaults_for_timestamp` | OFF | **ON** |
| `innodb_undo_tablespaces` | 0 | **2** |
| `innodb_undo_log_truncate` | OFF | **ON**（undo ログ自動truncate） |
| `innodb_flush_neighbors` | 1 | **0**（SSD 最適化） |
| `innodb_max_dirty_pages_pct` | 75% | **90%** |
| `default_authentication_plugin` | mysql_native_password | **caching_sha2_password** |
| `max_allowed_packet` | 4 MB | **64 MB** |

---

## 8.0 で廃止されたパラメータ

5.5〜5.6 時代に使っていた設定が消えている可能性がある。

| 廃止パラメータ | 代替 / 備考 |
|-------------|-----------|
| `innodb_stats_sample_pages` | `innodb_stats_persistent_sample_pages` |
| `innodb_locks_unsafe_for_binlog` | 廃止（ROW ベース binlog が前提） |
| `innodb_support_xa` | 廃止（XA は常に有効） |
| `innodb_checksums` | `innodb_checksum_algorithm` |
| `sync_frm` | `.frm` ファイル自体が廃止 |
| `innodb_file_format` | 廃止（Barracuda 形式のみ） |
| `innodb_file_format_check` | 同上 |
| `innodb_large_prefix` | 廃止（デフォルトで有効） |

---

## 注意が必要な変更点

### 1. バイナリログがデフォルト ON

MySQL 8.0 から `log_bin=ON` がデフォルト。意識せずとも binlog が生成されている。
大きな INSERT/UPDATE はバイナリログのサイズに注意。

### 2. 認証プラグインの変更

`caching_sha2_password` がデフォルトになったため、古い JDBC ドライバや古いクライアントから接続できない場合がある。

```sql
-- 既存ユーザーを mysql_native_password に戻す場合
ALTER USER 'user'@'host' IDENTIFIED WITH mysql_native_password BY 'password';
```

MySQL 8.4 では `mysql_native_password` が**無効化**された（`--mysql-native-password=ON` で再有効化可能）。

### 3. utf8mb4 標準化

`utf8`（実は 3 バイト、絵文字非対応）は実質非推奨。`utf8mb4` を使うこと。
MySQL 8.0 からサーバーデフォルトが `utf8mb4` になったため、新規DBは意識不要。

### 4. InnoDB のみサポート

MyISAM は事実上非推奨（廃止はされていないが新機能追加なし）。
`bulk_insert_buffer_size` は MyISAM 専用で InnoDB には無効。

---

## innodb_buffer_pool_size のベストプラクティス

デフォルト値は 128 MB だが実運用には不十分。

- **推奨**: 専用DBサーバーで物理メモリの 50〜80%
- MySQL 5.7.5+ からオンラインリサイズ可能（再起動不要）
- 複数インスタンス使用時は各インスタンス最低 1 GB 推奨

```sql
-- 現在値確認
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- オンライン変更（MySQL 5.7.5+）
SET GLOBAL innodb_buffer_pool_size = 2147483648; -- 2 GB
```

---

## MySQL 9.7 LTS の登場（2026-07追記）

2026-04-21に **MySQL 9.7.0 LTS** がGAとなり、8.4以来の新しいLTS系列が始まった。8.4 LTSは引き続きサポートされるが、新規標準化の選択肢として9.7が加わった。8.4→9.7の差分は[MySQL 9.7 LTS新機能まとめ](database/MySQL_9.7_LTS新機能まとめ.md)を参照。

## 参考

- [MySQL 8.0 New Defaults](https://dev.mysql.com/blog-archive/new-defaults-in-mysql-8-0/)
- [MySQL 8.0 Added, Deprecated, or Removed Variables](https://dev.mysql.com/doc/refman/8.0/en/added-deprecated-removed.html)
- [MySQL 8.4 Reference Manual](https://dev.mysql.com/doc/refman/8.4/en/)
