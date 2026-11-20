---
title: "sbt 2移行ガイド"
category: "development"
tags: [sbt, sbt2, scala, ビルドツール, 移行]
created: 2026-07-28
updated: 2026-07-28
related: ["sbt_マルチプロジェクト設計.md", "sbt_JVM設定ベストプラクティス.md"]
---

# sbt 2移行ガイド

## 概要

sbt 2.0が2026-06-29に正式リリースされた（5年がかりのメジャーバージョン、2026-07-26時点の最新は2.0.4）。sbt 1.xからの主要変更点と移行手順をまとめる。

---

## 1. 主要変更点

| 項目 | sbt 1.x | sbt 2.x |
|---|---|---|
| ビルド定義の言語 | Scala 2.12 | **Scala 3**（3.8.4） |
| 必須JDK | 8+ | **17+** |
| クライアント | sbt（JVM起動） | **sbtn**（native-imageクライアント、高速起動） |
| キャッシュ | インクリメンタルコンパイルのみ | **Bazel互換のローカル/リモートキャッシュ**（compile/testがキャッシュ可能タスク化） |
| クロスビルド | sbt-projectmatrixプラグイン | **project matrixがコア機能化**（JVM/Scala.js/Scala Nativeを単一定義、`%%` 統一記法） |

## 2. 移行手順

1. **JDK 17以上を用意する**（最初に確認。17未満では起動しない）
2. `project/build.properties` を書き換える:
   ```properties
   sbt.version=2.0.4
   ```
   プロジェクト単位で切り替えられるので、リポジトリごとに段階移行できる
3. ビルド定義（build.sbt・project/*.scala）のScala 3非互換を修正する
   - build.sbtのDSLは概ね互換だが、`project/` 配下のカスタムコードはScala 3でコンパイルされる
4. プラグインのsbt 2対応版に更新する
   - **60本以上の主要プラグインが移植済み**（Scala.js・Scala Native・sbt-assembly等）
   - 未対応プラグインが移行のボトルネックになるので、先に依存プラグインの対応状況を洗い出すこと
5. CI・開発環境のsbt起動方法を確認する（sbtnの導入、キャッシュディレクトリの扱い）

## 3. 移行判断の目安

- **新規プロジェクト**: sbt 2で開始してよい（メジャープラグインは対応済み）
- **既存プロジェクト**: 依存プラグインが全部対応してから。JDK 17制約がCI・本番イメージに波及しないかも確認
- **急ぐ理由が無ければ2.0.x系の安定を待つ選択も妥当**（GAから1ヶ月で2.0.4まで出ている＝修正が活発ということ）

## 4. キャッシュシステムの注意

- compile/testの結果がキャッシュされるため、**再現性のないタスク（コード生成・タイムスタンプ埋め込み等）はキャッシュ境界に注意**
- リモートキャッシュはBazel互換。チームでのビルド高速化に使えるが、キャッシュ基盤の運用が別途必要

## 参考リンク

- [sbt 2 is now available!（Scala公式ブログ）](https://www.scala-lang.org/blog/2026/06/29/sbt2.html)
- [Last mile towards sbt 2（Scala公式ブログ）](https://www.scala-lang.org/blog/2026/04/14/last-mile-towards-sbt2.html)
- [sbt Releases（GitHub）](https://github.com/sbt/sbt/releases)
