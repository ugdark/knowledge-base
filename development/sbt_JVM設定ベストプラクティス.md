---
title: "sbt JVM設定ベストプラクティス"
category: "development"
tags: [scala, sbt, jvm, sbtopts, jvmopts]
created: 2026-03-17
updated: 2026-07-28
---

# sbt JVM設定ベストプラクティス

## 概要

sbt/ScalaプロジェクトのJVM設定には `.sbtopts`、`.jvmopts`、環境変数の3つの方法がある。それぞれの役割・スコープ・優先順位を整理し、チームでの運用ベストプラクティスをまとめる。

---

## 1. 設定方法の比較

| 設定方法 | 対象 | スコープ | git管理 |
|---------|------|---------|---------|
| `.sbtopts` | sbtランチャーオプション + JVMオプション（`-J`prefix） | プロジェクト単位 | **する（推奨）** |
| `.jvmopts` | 純粋なJVMオプション | プロジェクト単位 | **しない（推奨）** |
| 環境変数 | JVM/sbtオプション | ユーザー/セッション単位 | N/A |

## 2. `.sbtopts`（プロジェクト共有設定）

sbtランチャーに渡すオプション。JVMオプションは `-J` プレフィックスが必要。

```
-J-Xmx4G
-J-Xms1G
-J-Xss2M
-J--add-opens=java.base/java.util=ALL-UNNAMED
-J--add-opens=java.base/java.lang=ALL-UNNAMED
-Dsbt.task.timings=true
```

### 特徴

- **gitにコミットすべき**: チーム全員・CIで統一したい設定を置く
- sbt固有オプション（`-Dsbt.*`）を設定できる
- JDK 17+で必要な `--add-opens` フラグの配置に最適
- `/etc/sbt/sbtopts` でシステムワイドのフォールバックも可能

### 注意点

- JVMオプションには必ず `-J` プレフィックスが必要
- 公式sbtランチャー専用。coursierの `cs launch sbt` では認識されない場合がある

## 3. `.jvmopts`（マシン固有設定）

純粋なJVMオプションを記述する。プレフィックス不要。

```
-Xms512M
-Xmx4096M
-Xss2M
-XX:MaxMetaspaceSize=1024M
-Dfile.encoding=UTF-8
-XX:+UseG1GC
```

### 特徴

- **gitignore推奨**: ヒープサイズやGC設定はマシンのRAMに依存する
- `.jvmopts` の内容は `JAVA_OPTS` に追記される
- 開発者がローカルで自由にチューニングできる

### 注意点

- `.jvmopts` が存在すると `-mem` オプションが無視される既知の問題がある
- sbtプロセスのJVMにのみ影響。fork先（test/run）には影響しない

## 4. 環境変数

| 変数 | 認識元 | 用途 |
|------|-------|------|
| `JAVA_OPTS` | sbtランチャースクリプト | sbt JVMへのオプション渡し |
| `SBT_OPTS` | sbtランチャースクリプト | sbt固有オプション + JVMオプション |
| `JDK_JAVA_OPTIONS` | JVM自体（Java 9+） | 全`java`コマンドに適用 |
| `JAVA_TOOL_OPTIONS` | JVM/JVMTIエージェント | 全JVMツールに適用 |

### 注意点

- `JAVA_OPTS` はJVM標準ではなくラッパースクリプトの慣習
- `JDK_JAVA_OPTIONS` はJava 9+でJVM自体が認識する公式変数
- 環境変数はプロジェクト間で共有されるため、プロジェクト固有設定には不向き

## 5. 優先順位（後勝ち）

```
JAVA_OPTS デフォルト（最低）
  ↓
.jvmopts（JAVA_OPTSに追記）
  ↓
SBT_OPTS 環境変数
  ↓
.sbtopts（SBT_OPTSに追記）
  ↓
/etc/sbt/sbtopts（SBT_OPTSに追記）
  ↓
コマンドライン引数（最高）
```

`-Xmx` のように「最後の値が勝つ」フラグは後の設定で上書きされる。`-D` プロパティのように加算されるフラグは全て蓄積される。

## 6. 推奨構成

### チームプロジェクト

```
project-root/
├── .sbtopts          # git管理: --add-opens, sbt設定, 共通メモリ設定
├── .jvmopts          # gitignore: 個人のヒープ/GCチューニング
└── .gitignore        # .jvmopts を含める
```

### `.sbtopts` に入れるもの

- JDK 17+のモジュールアクセスフラグ（`-J--add-opens=...`）
- sbt診断設定（`-Dsbt.task.timings=true`）
- チーム共通のメモリベースライン（`-J-Xmx4G`）

### `.jvmopts` に入れるもの（個人用）

- マシンのRAMに応じたヒープサイズ
- GCアルゴリズムの選択
- エンコーディング設定

### CI環境

- `SBT_OPTS` 環境変数でパイプライン固有のオーバーライドを行う
- 例: `SBT_OPTS="-J-Xmx8G" sbt test`

## 7. sbt 1.x vs 2.x

`.jvmopts`、`.sbtopts`、環境変数の動作はsbt 1.xと2.xで変更なし。同じ設定ファイルがそのまま使える。

## 8. 最近のsbtアップデート

### sbt 2.0.0（RC開発中）

- **sbt 2.0.0-RC12**（2026-04-13）: アクティブなRC開発中。Scala 3.8.1対応、JDK 17+必須
- **主な新機能**: XDGディレクトリサポート、依存関係ロック（dependency locking）、Maven BOMサポート

### sbt 1.x 最新

- **sbt 1.12.9**（2026-04-07）: 依存関係解決の修正
- **sbt 1.12.7 セキュリティ修正**: CVE-2026-32948 — Windows環境でVCS URL処理を介した任意コード実行の脆弱性を修正

---

## 9. sbt 2.0 正式リリース（2026-07追記）

- **sbt 2.0.0 が2026-06-29にGA**（2026-07-26時点で2.0.4）。5年がかりのメジャーバージョン
- **最低JDK 17**。JVM設定の前提が変わるので、`.jvmopts` を書く前にJDKバージョンを確認すること
- **sbtn（native-imageクライアント）**で起動が高速化。sbtサーバーへのシンクライアント接続になる
- ビルド定義・プラグインはScala 3（3.8.4）ベース
- 移行は `project/build.properties` の `sbt.version=2.0.x` 指定で段階的に可能。詳細は[sbt 2移行ガイド](development/sbt2移行ガイド.md)

## 参考リンク

- [sbt 1.x Command Line Reference](https://www.scala-sbt.org/1.x/docs/Command-Line-Reference.html)
- [sbt 2.x - The Book of sbt](https://www.scala-sbt.org/2.x/docs/en/reference/sbt.html)
- [SoftwareMill - New Scala Project Checklist](https://softwaremill.com/new-scala-project-checklist/)
- [GitHub official SBT.gitignore](https://github.com/github/gitignore/blob/main/Global/SBT.gitignore)
- [sbt-launcher-package issue #256](https://github.com/sbt/sbt-launcher-package/issues/256)
