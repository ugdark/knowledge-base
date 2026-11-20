---
title: "sbt マルチプロジェクト設計：build.sbt 複数配置の是非"
category: "development"
tags: [sbt, Scala, マルチプロジェクト, ビルド設計, モノリポジトリ]
created: 2026-01-27
updated: 2026-07-28
---

# sbt マルチプロジェクト設計：build.sbt 複数配置の是非

## 概要

大規模なScalaプロジェクトでは、マルチプロジェクト構成を取ることが多い。
その際、build.sbtの配置方法には複数のアプローチがある。
本ドキュメントでは、ルート集約・各サブプロジェクト配置・ハイブリッドの3パターンを比較し、推奨アプローチを示す。

---

## アプローチ1: ルートに build.sbt を集約 ⭐推奨

### 構成

```
project/
├── build.sbt                     ← すべてのプロジェクト定義をここに集約
├── project/
│   ├── Dependencies.scala        ← 依存関係を管理
│   └── build.properties
├── module-a/
│   └── src/
├── module-b/
│   └── src/
└── module-c/
    └── src/
```

### build.sbt の例

```scala
lazy val moduleA = (project in file("module-a"))
  .settings(
    name := "module-a",
    libraryDependencies ++= Seq(
      Dependencies.cats,
      Dependencies.circe
    )
  )

lazy val moduleB = (project in file("module-b"))
  .settings(
    name := "module-b",
    libraryDependencies ++= Seq(
      Dependencies.akka,
      Dependencies.slick
    )
  )
  .dependsOn(moduleA)

lazy val root = (project in file("."))
  .aggregate(moduleA, moduleB)
```

### メリット

✅ **全体像が一目で分かる**
- すべてのプロジェクト定義が1ファイル
- 依存関係が明確
- 新しいメンバーが理解しやすい

✅ **依存関係の管理が容易**
- どのモジュールがどれに依存しているか一目瞭然
- 循環依存を発見しやすい
- リファクタリングしやすい

✅ **設定の一貫性**
- 共通設定を統一的に適用できる
- 設定の衝突が起きにくい

✅ **ビルドが高速**
- sbtが1回のロードで全プロジェクトを把握
- キャッシュが効きやすい

✅ **IDEサポートが良い**
- IntelliJ IDEAなどが正しくプロジェクト構造を認識
- コード補完が効く

### デメリット

❌ build.sbtが巨大化する
- 100+モジュールだと数千行になる可能性

❌ マージコンフリクトが起きやすい
- 複数人が同時にモジュール追加すると衝突

---

## アプローチ2: 各サブプロジェクトに build.sbt を配置 ❌非推奨

### 構成（大規模プロジェクトの実例）

```
project-root/
├── build.sbt                     ← ルート：プロジェクト定義
├── platform/
│   ├── common/
│   │   ├── build.sbt             ← サブプロジェクト固有設定
│   │   └── src/
│   ├── db/
│   │   ├── build.sbt
│   │   └── src/
│   └── ...（60個以上のbuild.sbt）
└── qm/
    └── ...
```

### ルートの build.sbt

```scala
lazy val common = (project in file("platform/common"))
  .settings(commonSettings)
  .dependsOn(commonDomain)
```

### サブプロジェクトの build.sbt

```scala
name := "common"
libraryDependencies ++= Seq(
  Dependencies.RedisClient,
  Dependencies.Poi
)
```

### デメリット

❌ **全体像が見えない**
- どのモジュールがあるのか分からない
- ルートのbuild.sbtを見ても、各サブプロジェクトの詳細設定が分からない
- 60個のbuild.sbtを見て回る必要がある

❌ **依存関係が追いづらい**
```
moduleAがmoduleBに依存しているか調べるには:
1. ルートのbuild.sbtでdependsOnを確認
2. moduleA/build.sbtで詳細確認
3. moduleB/build.sbtで詳細確認
→ 3箇所見る必要がある
```

❌ **設定の重複・不整合**
```
各サブプロジェクトのbuild.sbtで:
- scalaVersionを個別に設定？
- テスト設定を個別に設定？
→ 不整合が起きやすい
```

❌ **IDEサポートが不安定**
- IntelliJ IDEAがプロジェクト構造を誤認識することがある
- sbtプロジェクトのリロードに時間がかかる

❌ **ビルドが遅くなる可能性**
- sbtが複数のbuild.sbtを順番に読み込む
- キャッシュが効きにくい場合がある

❌ **新しいメンバーが混乱**
```
新人: 「このプロジェクトにはどんなモジュールがあるんですか？」
先輩: 「えっと...60個くらいあって...」
新人: 「全部どこで定義されてるんですか？」
先輩: 「ルートのbuild.sbtと、各ディレクトリのbuild.sbtを見てください」
新人: 「😵‍💫」
```

### メリット（一応ある）

✅ **モジュール単位で設定が完結**
- そのモジュールの設定だけ見ればいい（理論上）

✅ **マージコンフリクトが起きにくい**
- 異なるモジュールを同時に編集してもコンフリクトしない

✅ **大規模プロジェクトでルートbuild.sbtが巨大化しない**
- 各サブプロジェクトに分散される

---

## アプローチ3: ハイブリッド（折衷案）⚠️

### 構成

```
project/
├── build.sbt                     ← 主要なプロジェクト定義
├── project/
│   ├── Dependencies.scala
│   ├── CommonSettings.scala      ← 共通設定
│   └── Projects.scala            ← プロジェクト定義を分割
└── modules/
    ├── core/
    │   └── src/
    ├── api/
    │   └── src/
    └── admin/
        ├── build.sbt             ← 特殊な設定が必要な場合のみ
        └── src/
```

### メリット

✅ 基本はルートに集約
✅ 特殊な設定が必要なモジュールだけ個別build.sbt

### デメリット

❌ ルールが曖昧
- 「どのモジュールが個別build.sbtを持つべきか」の判断が難しい

---

## 比較表

| 項目 | ルート集約 | 各サブPJに配置 | ハイブリッド |
|------|----------|--------------|-------------|
| **全体像の把握** | ⭐⭐⭐ | ❌ | ⭐⭐ |
| **依存関係の追跡** | ⭐⭐⭐ | ❌ | ⭐⭐ |
| **設定の一貫性** | ⭐⭐⭐ | ❌ | ⭐⭐ |
| **IDEサポート** | ⭐⭐⭐ | ⭐ | ⭐⭐ |
| **ビルド速度** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **マージコンフリクト** | ❌ | ⭐⭐⭐ | ⭐⭐ |
| **新人の理解しやすさ** | ⭐⭐⭐ | ❌ | ⭐⭐ |
| **大規模化への対応** | ⭐ | ⭐⭐⭐ | ⭐⭐ |

---

## 大規模プロジェクトの評価

### 現状

```
❌ 60個以上のbuild.sbtが散在
❌ 全体像が見えにくい
❌ 新しいメンバーが理解しづらい
❌ 依存関係が追いづらい
```

### 大規模プロジェクトで採用されてる理由（推測）

1. **歴史的経緯**
   - 最初は小規模だった
   - モジュールが増えていった
   - リファクタリングのコストが高い

2. **マージコンフリクト回避**
   - 複数チームが並行開発
   - ルートのbuild.sbtでコンフリクトしたくない

3. **モジュールの独立性重視**
   - 各チームが自分のモジュールだけ管理したい

### 改善案

#### 短期（すぐできる）

```scala
// project/AllProjects.scala を作成
// ルートのbuild.sbtから分離

object AllProjects {
  lazy val platformCommon = (project in file("platform/common"))
    .settings(
      name := "common",
      libraryDependencies ++= Seq(...)
    )

  // 他のプロジェクトも同様に定義
}
```

```scala
// build.sbt
import AllProjects._

lazy val root = (project in file("."))
  .aggregate(
    platformCommon,
    platformDb,
    // ...
  )
```

→ 各サブプロジェクトのbuild.sbtを削除して、AllProjects.scalaに集約

#### 中期（計画的に）

```
1. ドメイン別にプロジェクトをグループ化
   - platform系
   - qm系
   - qs系
   - am系

2. 各ドメインごとにbuild.sbtを作成
   - platform/projects.sbt
   - qm/projects.sbt
   - qs/projects.sbt

3. ルートのbuild.sbtで読み込み
```

#### 長期（理想）

```
モノリポジトリを分割検討:
- platform → 独立リポジトリ（ライブラリとして公開）
- am → 独立リポジトリ
- qm, qs → メインリポジトリ

各リポジトリは「アプローチ1: ルート集約」を採用
```

---

## 結論

### 質問：「複数のbuild.sbtって設計としていいの？」

**回答**: ❌ **あまり良くない**

理由：
1. 全体像が見えにくい
2. 依存関係が追いづらい
3. 新しいメンバーが理解しづらい
4. IDEサポートが不安定になりがち

### 推奨アプローチ

**小〜中規模（〜50モジュール）**: アプローチ1（ルート集約）⭐

**大規模（50+モジュール）**:
- アプローチ1 + project/配下に分割
- またはモノリポジトリ分割を検討

### 大規模プロジェクトへの提案

現状（60+のbuild.sbt散在）は改善の余地あり。

ただし**リファクタリングコストが高い**ので：
- 新規モジュールは project/Projects.scala に集約
- 既存は段階的に移行
- または「そのまま」も選択肢（変更リスクを取らない）

---

## 補足：他のプロジェクトの実例

### Play Framework（大規模）
```
単一のbuild.sbtで全モジュールを管理
```

### Akka（大規模）
```
単一のbuild.sbtで全モジュールを管理
```

### cats（中規模）
```
単一のbuild.sbtで全モジュールを管理
```

→ **OSSプロジェクトはほぼ全て「ルート集約」を採用**

---

## sbt 2 時代の補足（2026-07追記）

sbt 2.0 が2026-06-29に正式リリースされた（本記事執筆時はsbt 1.x前提）。マルチプロジェクト設計への影響:

- **設計論自体は変わらない**（単一build.sbt推奨の結論は維持）
- **Bazel互換のローカル/リモートキャッシュ**が入り、compile/testがキャッシュ可能タスク化。マルチモジュール構成のビルド効率が向上する
- **project matrixがコア機能化**。JVM/Scala.js/Scala Nativeのクロスビルドを単一定義で書けるため、プラットフォーム別にサブプロジェクトを切る設計は不要になる
- ビルド定義はScala 3（3.8.4）・JDK 17必須。移行手順は[sbt 2移行ガイド](development/sbt2移行ガイド.md)を参照

## 参考リンク

- [Play Framework - build.sbt](https://github.com/playframework/playframework/blob/main/build.sbt)
- [Akka - build.sbt](https://github.com/akka/akka/blob/main/build.sbt)
- [cats - build.sbt](https://github.com/typelevel/cats/blob/main/build.sbt)
