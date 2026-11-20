---
title: "GitHub Projects運用ガイド"
category: "development"
tags: [github, project-management, scrum, iteration, workflow]
created: 2026-06-08
updated: 2026-06-08
---

# GitHub Projects運用ガイド

## 概要

GitHub Projects（v2）の概要と運用方法をまとめたガイド。Issue/PRと密結合な計画ツールとしての特徴、ビュー・フィールド設計、Iteration（スプリント）運用、自動化、移行時のポイントを扱う。

---

## 1. GitHub Projectsとは

GitHubが提供するアダプティブな計画・追跡ツール。Issue/PRと双方向同期するスプレッドシート的データモデルを核に、複数ビューでカンバン・テーブル・ロードマップを切り替えて使う。特定の方法論（Scrum/Kanban等）を強制せず、フィールドとビューの組み合わせで自前のワークフローを組み立てる思想。

**旧Projects（classic）との違い**
- classicはリポジトリ単位のカンバンのみ。v2は組織/ユーザー横断で複数リポジトリのIssue/PRを束ねられる
- カスタムフィールド（最大50個）が追加可能
- Iteration（時間軸の繰り返し）型フィールドがあり、スプリント運用が公式対応
- Insightsでチャート可視化、GraphQL APIで自動化
- classicは段階的に非推奨。新規プロジェクトはv2一択

## 2. データモデル

```
Project
├── Items (Issue / PR / Draft issue)
└── Fields (各Itemに値を持たせる属性)
    ├── Status (Single select)         ← Todo / In Progress / Done
    ├── Priority (Single select)       ← P0 / P1 / P2
    ├── Iteration                       ← Sprint 2026-W23 など
    ├── Estimate (Number)               ← ストーリーポイント
    ├── Target date (Date)
    └── Notes (Text)
```

- **Draft issue**: Projectsだけに存在する仮アイテム。後でIssue化できる。アイデア出し・棚卸し用
- **Item**は1つのProjectに複数のフィールド値を持つ。Issue本体（リポジトリ側）にはこの値は載らない
- 同じIssueを複数のProjectに追加すると、Projectごとに別フィールド値を持つ

## 3. ビュー種類

| ビュー | 用途 | 向いている場面 |
|--------|------|----------------|
| Table | 高密度なスプレッドシート | 棚卸し、一括編集、フィルタ運用 |
| Board | カンバン | デイリーで進捗を可視化、ステータス遷移 |
| Roadmap | タイムライン（ガントライク） | Iteration/日付ベースの長期計画 |

ビューは1つのProjectに何個でも作れて、それぞれフィルタ・グルーピング・ソート・表示フィールドを保存する。「PMはRoadmap、エンジニアはBoard、PdMはTable」のような使い分けが基本。

## 4. フィールド設計

### Single select（カテゴリ系）

- Status, Priority, Type（feature/bug/chore）など
- 選択肢は色付き。Boardの列、Insightsのグループに使われる

### Iteration（スプリント運用の主役）

- 開始日と期間（1週/2週など）を指定するとサイクルが自動生成される
- 「現在のIteration」「次のIteration」というキーワードでフィルタ可能
- 未完了アイテムを次Iterationへ一括移動できる（バックログ整理に便利）
- **Milestoneとの違い**: Milestoneは日付範囲を持たない単発の目標。継続的スプリント運用はIteration一択

### Number（見積もり・実績）

- Story Point、所要時間など。Insightsで合計・平均を出せる

### Date（締切・リリース日）

- Roadmapビューの軸になる

## 5. Iteration（スプリント）運用パターン

### 基本フロー

1. **プランニング**: Backlog（Iteration未設定）からIterationにアイテムを引き上げる
2. **デイリー**: Board ビューを `Iteration = @current` でフィルタし、StatusでGroup by
3. **レビュー/レトロ**: `Iteration = @previous` のTableビューでDoneを確認、ベロシティを記録
4. **ロールオーバー**: Done以外を次Iterationに一括移動

### 注意点

- GitHubはベロシティチャートやキャパシティプランニング機能を**標準では提供しない**。Insightsで簡易的に算出するか、Estimateフィールド合計を手で記録する
- Iterationを後から短くすると過去Iterationの境界がずれる。期間は最初に決めて固定する

## 6. 自動化（Built-in workflows）

プロジェクト作成時にデフォルトで有効な2つ：
- Issue/PRがcloseされたら Status を **Done** に
- PRがmergeされたら Status を **Done** に

追加で設定可能な主な自動化：

| ワークフロー | トリガー | 用途 |
|--------------|---------|------|
| Auto-add to project | リポジトリで作成されたIssue/PRがフィルタ条件に合致 | 起票漏れ防止 |
| Item added to project | Itemが追加された | デフォルトStatus付与 |
| Item reopened | closeされたItemが再オープン | StatusをIn Progressに戻す |
| Code review approved | PRがApproveされた | StatusをReady to mergeに |
| Pull request merged | マージ完了 | Doneに |
| Auto-archive items | フィルタ条件 + N日経過 | バックログ肥大化防止 |

足りない自動化はGitHub Actions + GraphQL API（`addProjectV2ItemById` 等）で実装する。

## 7. Insights

Projectデータをチャート化する機能。代表的な使い方：

- **Burn-up / Burn-down**: Iterationごとの完了点数推移
- **Status分布**: 現Iterationのアイテム数をStatus別に
- **担当者別作業量**: AssigneeでGroup by

無料プランではチャート数に制限あり。Team/Enterpriseで上限が増える。

## 8. CLI / API

- **`gh project`**: コマンドラインからProject操作可能（`gh project list`, `gh project item-add`, `gh project field-create` 等）
- **GraphQL API**: Project v2はREST非対応、GraphQL専用。`projectV2` 配下のクエリ/ミューテーション
- **GitHub Actions**: `actions/add-to-project` で自動投入が定番

## 9. ベストプラクティス

### 設計時

- **ステータスは最初は3つ**: Todo / In Progress / Done。増やすのは運用が回ってから
- **Status以外の必須フィールドは3つ以内**: Priority, Iteration, Estimateくらいに絞る。多いと埋まらず腐る
- **Issueに書く情報とProjectフィールドの責務を分ける**: 仕様・議論はIssue、計画メタデータはProject

### 運用時

- **Draft issueを乱用しない**: 採用したら早めにIssue化する。Draftのままだと検索・参照されにくい
- **Auto-add to projectを必ず入れる**: 「Projectへの追加忘れ」が最大の運用負債
- **Auto-archive 30日**: Done後30日でアーカイブ。Tableビューが軽くなる
- **ビューを増やしすぎない**: 1人につき2-3ビューが目安。役割別に作る

### スクラム運用との接続

- Sprint = Iteration、Story Point = Number（Estimate）、Velocity = 手動記録
- レトロ用に「Iteration完了時のDone集計をMarkdownで貼り出す」運用が現実的
- 関連: [[スクラムセレモニー]] / [[スクラムセレモニー_tips]]

## 10. 旧ツールからの移行

### Jira / Asana / Notion からの移行

| 旧ツール概念 | GitHub Projects対応 |
|--------------|---------------------|
| Epic | Issue + サブIssue（GitHub標準機能）or ラベル `epic` |
| Story / Task | Issue |
| Sprint | Iteration |
| Story Point | Number field |
| Assignee | IssueのAssignee（Projectフィールドではない） |
| Component | Single select または Label |

### 移行時の落とし穴

- **履歴は移行できない**: 過去のスプリント実績はCSVエクスポートして別途保管
- **Issueにある情報はリポジトリ単位**: Projectを跨いでも同じ。複数リポジトリ運用なら組織レベルProjectで束ねる
- **権限モデルが違う**: Projectは独自の閲覧/編集権限。リポジトリの権限とは別管理。組織内公開設定を最初に決める

## 参考リンク

- [About Projects - GitHub Docs](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)
- [About iteration fields - GitHub Docs](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-iteration-fields)
- [Using the built-in automations - GitHub Docs](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations)
- [Best practices for Projects - GitHub Enterprise Cloud Docs](https://docs.github.com/en/enterprise-cloud@latest/issues/planning-and-tracking-with-projects/learning-about-projects/best-practices-for-projects)
- [Planning next to your code - GitHub Projects is now generally available (GitHub Blog)](https://github.blog/news-insights/product-news/planning-next-to-your-code-github-projects-is-now-generally-available/)
