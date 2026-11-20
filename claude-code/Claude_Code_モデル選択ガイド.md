---
title: "Claude Code モデル選択ガイド"
category: "claude-code"
tags: [Claude-Code, モデル, Opus, Sonnet, Haiku, Fast-mode, 価格]
created: 2026-06-08
updated: 2026-07-28
---

# Claude Code モデル選択ガイド

## 概要

Claude Code で使用するモデルは `/model` コマンドで切り替えられる。賢さ・速さ・コストのトレードオフに応じて選択する。

---

## 1. 利用可能なモデル一覧

`/model` を実行すると選択肢が複数表示される。

| モデル | 賢さ | 速さ | Input $/1M | Output $/1M | 向いている作業 |
|--------|------|------|-----------|------------|----------------|
| **Opus 4.8** | ◎ 最高 | △ 遅め | $5.00 | $25.00 | 設計、難しいデバッグ、複雑なリファクタ、調査 |
| **Sonnet 4.6** | ○ 高い | ○ 速い | $3.00 | $15.00 | 日常の実装、コードレビュー、PR作成、大半の作業 |
| **Haiku 4.5** | △ そこそこ | ◎ 最速 | $1.00 | $5.00 | 単純な編集、定型作業、軽い質問、ファイル整理 |

選択したモデルは**次回セッションのデフォルト**として保存される。

---

## 2. 選び方の目安

### Opus 4.8 を使う場面
- アーキテクチャ判断、原因不明のバグ調査
- 複数ファイルにまたがる複雑な変更
- 「頭を使う」タスク全般

### Sonnet 4.6 を使う場面（普段使いの主力）
- 日常的な実装・コードレビュー・PR作成
- 十分賢くて速く、コストも手頃
- 多くの開発作業はこれで足りる

### Haiku 4.5 を使う場面
- typo修正、import追加、リネーム
- 「考える必要がほぼない」定型作業

---

## 3. Fast モード

`/fast` でトグルできる高速モード（Research Preview）。

- Opus 4.8 のまま出力が速くなる（モデルのダウングレードではない）
- クレジット消費が通常より高い（割高）
- **組織によって無効化されている場合がある**（`Fast mode has been disabled by your organization`）

Fast モードが使えない場合の代替策：
- 普段は Sonnet 4.6 を使い、難しい場面だけ Opus に上げる
- 指示を具体的にする（Opus 4.8 は曖昧な指示で長考しやすい）

---

## 4. Opus 4.8 の長考について

Opus 4.8 は 4.7 より「考えるべきと判断したときに、より深く考える」方向にチューニングされている。曖昧なタスクや選択肢が多い場面で思考が長くなりやすい。

対処法：
- **指示を具体的にする** — 「やること」が明確なら思考を短く切り上げる
- 「考えすぎず進めて」と添える — 定型作業で効果的
- Sonnet 4.6 に切り替える — 速さとコストのバランスが良い

---

## 5. 価格詳細

| モデル | Model ID | コンテキスト | Input $/1M | Output $/1M |
|--------|----------|------------|-----------|------------|
| Claude Opus 4.8 | `claude-opus-4-8` | 1M | $5.00 | $25.00 |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | 1M | $3.00 | $15.00 |
| Claude Haiku 4.5 | `claude-haiku-4-5` | 200K | $1.00 | $5.00 |

**Opus 4.8 は Sonnet 4.6 の約 1.7 倍（入力）〜 1.7 倍（出力）のコスト。** 普段の作業は Sonnet 4.6 で足りることが多い。

> ※ 価格は 2026-05-26 時点。最新は [Anthropic Pricing](https://www.anthropic.com/pricing) を確認。

---

## 6. 2026年6〜7月の変更（追記）

- **Sonnet 5 が登場し、Pro / Team Standard / Enterprise サブスクのデフォルトに**（6月末）。Sonnet価格のままコーディング・ツール使用がトップ級、ネイティブ1Mトークンコンテキスト、adaptive thinking標準ON。上の一覧表のSonnet 4.6の位置づけは実質Sonnet 5に置き換わった
- **Claude 5ファミリー（Fable 5 / Mythos 5）が発表**。Opusの上に位置する新ティア（Mythosクラス）。詳細: [Anthropic公式](https://www.anthropic.com/news/claude-fable-5-mythos-5)
- **`fallbackModel`** で最大3つのフォールバックモデルを設定可能に
- Fast モードは引き続き Opus 系（$10/$50 per MTok）。モデルを小さくするのではなく出力を高速化する仕組み

## 参考リンク

- [Fast mode ドキュメント](https://code.claude.com/docs/en/fast-mode)
- [Anthropic Pricing](https://www.anthropic.com/pricing)
