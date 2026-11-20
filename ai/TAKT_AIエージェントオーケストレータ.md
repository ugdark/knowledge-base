---
title: "TAKT - AIエージェントオーケストレータ"
category: "ai"
tags: [ai-agents, orchestration, workflow, claude-code, codex]
created: 2026-05-21
updated: 2026-05-21
---

# TAKT - AIエージェントオーケストレータ

## 概要

TAKT (Agent Koordination Topology) は複数のAIエージェントを **事前定義workflow** に従って強制実行するOSSオーケストレータ。AIに自由度を与える既存ツール（AutoGen/CrewAI/Claude Code Swarm）と異なり、**再現性と確実性**を最優先する設計思想。Claude Code / Codex / OpenCode / Cursor Agent / GitHub Copilot CLI を統一インターフェースで叩ける。

---

## 1. 設計思想

### 問題意識
- 複数プロジェクト並行進行時、AIエージェントへの**付きっきり対応**が必要だった
- AIが「言うことを聞かない」: 役割を忘れる、知識が抜け落ちる、指摘内容を再度やらかす
- 既存の subagent / Skill 呼び出しは **使ってくれる時とくれない時があり再現性がない**

### 核心アイデア
> 「AIに『お願い』するのではなく、『強制的に』レビューさせればいい」

決定権をAIから workflow に移し、ステータス判定を仕組みで担保する。

---

## 2. アーキテクチャ

### 5つのコンポーネント

| 層 | 役割 |
|---|---|
| Workflow エンジン | YAML定義の有向グラフ実行 |
| プロンプト構成層 | Faceted Prompting で5要素を組み合わせ |
| プロバイダー抽象層 | 複数AI呼び出しの統一インターフェース |
| ステータス判定エンジン | rules定義から自動生成プロンプトで遷移判定 |
| セッション/ランログ管理 | NDJSON形式で実行履歴を永続化 |

### データフロー

```
タスク入力
  ↓ 対話モード（要件詳細化）
  ↓ workflow選択 + worktree作成
  ↓ step順序実行
    ├─ テンプレート変数注入 ({task}, {previous_response})
    ├─ プロンプト組立 (Persona + Policy + Knowledge + Instruction)
    ├─ プロバイダー経由でAI呼出
    ├─ ステータス判定プロンプト自動生成
    └─ rules照合 → 次step決定
  ↓ 実行レポート → PR作成
```

---

## 3. Faceted Prompting（5要素分離）

一枚岩のプロンプトを5つの独立した関心事に分解し、変更影響を局所化する。

| 要素 | 役割 | 例 |
|---|---|---|
| **Persona** | 誰として振る舞うか | coder / reviewer / architect |
| **Policy** | 何を守るか | コーディング規約・禁止事項 |
| **Instruction** | 何をするか | step固有の手順 |
| **Knowledge** | 何を参照するか | アーキ図・ドメイン知識 |
| **Output Contract** | どう出力するか | JSON / Markdown構造 |

**効果**: Policy を変更すると、それを参照する全 workflow に自動反映。

---

## 4. Workflow 定義（YAML有向グラフ）

```yaml
name: code-review
description: コードを書いてレビューするworkflow
max_steps: 10
initial_step: write-code

personas:
  coder: ../personas/coder.md
  supervisor: ../personas/supervisor.md

steps:
  - name: write-code
    persona: coder
    edit: true
    instruction: 次のタスク実行：{task}
    rules:
      - condition: 実装完了
        next: review
      - condition: 続行不能
        next: ABORT

  - name: review
    persona: supervisor
    edit: false
    instruction: コード確認：{previous_response}
    rules:
      - condition: 問題なし
        next: COMPLETE
      - condition: 改善必要
        next: write-code
```

### 仕様

| キー | 意味 |
|---|---|
| `max_steps` | 無限ループ防止の上限 |
| `rules` | 条件→遷移先の宣言的マッピング |
| `edit: true/false` | そのstepでファイル編集を許可するか |
| テンプレート変数 | `{task}`, `{previous_response}`, `{iteration}` |
| 終端 | `COMPLETE`（成功）/ `ABORT`（中止） |

---

## 5. 複数プロバイダー対応

### 対応プロバイダ
Claude Code / Codex / OpenCode / Cursor Agent / GitHub Copilot CLI

### 認証
環境変数で各プロバイダーのAPIキーを設定：
- `TAKT_ANTHROPIC_API_KEY`
- `TAKT_OPENAI_API_KEY`
- その他プロバイダーごと

### step別の model 指定

```yaml
steps:
  - name: design
    model: opus      # 設計は高性能モデル
  - name: implement
    model: sonnet    # 実装は軽量モデル
```

**Hybrid Codex バリアント**: コーディングを Codex、レビューを Claude にする等、step ごとにプロバイダーをミックス可能。

---

## 6. 強制ワークフロー実行の仕組み

「AIが自分の判断で使う」ことを前提にせず「仕組みとして強制」する。

| メカニズム | 実装方法 |
|---|---|
| 決定権の移譲 | step 遷移判定を AI ではなく workflow に移す |
| ステータス判定の自動生成 | rules から「実装完了なら次へ、問題ならループ」と明記したプロンプトを生成 |
| コンテキスト配信 | 各step が文脈を記憶できなくても、workflow がテンプレート変数で情報を運ぶ |
| 形式照合 | AIの出力に対し「条件 condition に合致するか」を形式的に照合 |

---

## 7. インタラクティブモード

```
takt 起動
  ↓ 要件入力 → AIが質問返し（認証方式は？等）
  ↓ Read/Glob/Grep/Bash でコードベース調査
  ↓ 要件詳細化
  ↓ /go → workflow選択UI → worktree作成 → 実行
```

### スラッシュコマンド
- `/go`: 要件確定後に実行開始
- `/cancel`: 中止
- `/play <タスク>`: 即時実行

---

## 8. 既存ツールとの差別化

| ツール | 特徴 | TAKTとの差 |
|---|---|---|
| AutoGen / CrewAI | AI同士の自律協調 | AIの自由度を「制限」→再現性重視 |
| Claude Code Swarm | 動的協調エージェント | 事前定義 workflow→確実な実行 |
| 単独 agent | スケール限界 | workflow でレビュー段階を強制挿入 |

差別化ポイント: **「マルチエージェント開発の再現性と品質を強制力で担保」**

---

## 9. 制限事項・トレードオフ

### できないこと
- 最終的な人間による目視レビューは自動化されない（著者も言及）
- workflow 設計を誤ると期待通り動かない
- 探索的タスクには不向き（定型業務向き）

### トレードオフ
- 柔軟性 ↔ **再現性**
- 自由度 ↔ **確実性**

→ いずれも後者を選択した設計。

---

## 10. 想定ユースケース

- **複数プロジェクトの並行開発**: AIの世話が減る
- **定型的なコード実装→レビュー→修正サイクル**
- **CI/CDパイプラインでの自動化**
- **GitHub Issue単位のタスク処理**

向いていない:
- 探索的タスク
- 創造的問題解決
- workflow を都度変えたい case

---

## 11. インストール・利用

```bash
npm install -g takt
```

### 設定ファイル配置

| パス | 役割 |
|---|---|
| `~/.takt/config.yaml` | グローバル設定 |
| `~/.takt/workflows/` | カスタム workflow |
| `~/.takt/personas/` | カスタム persona |
| `~/.takt/runs/` | 実行ログ（NDJSON） |
| `~/.takt/tasks.yaml` | タスクキュー |

---

## 参考リンク

- [TAKT GitHub リポジトリ (nrslib/takt)](https://github.com/nrslib/takt)
- [作者解説記事 (Zenn / nrs)](https://zenn.dev/nrs/articles/c6842288a526d7)
