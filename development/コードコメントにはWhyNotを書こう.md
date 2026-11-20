---
title: "コードコメントには Why not を書こう"
category: "development"
tags: [code-comment, t_wada, clean-code, best-practice]
created: 2026-06-25
updated: 2026-06-25
---

# コードコメントには Why not を書こう

## 概要

t_wada（和田卓人）による、コードの各要素に何を書くべきかを整理した格言。  
出典: https://x.com/t_wada/status/904916106153828352 （2017年9月4日）

---

## 格言

| 場所 | 書くべき内容 |
|------|-------------|
| コード | **How**（どのように実装するか） |
| テストコード | **What**（何をすべきか） |
| コミットログ | **Why**（なぜこの変更をするのか） |
| コードコメント | **Why not**（なぜこうしなかったのか） |

---

## 解説

### コードには How

コード自体がすでに「どのように動作するか」を語っている。  
WHATをコメントで繰り返す必要はない。

```kotlin
// NG: リストをソートする（コードを読めばわかる）
list.sortedBy { it.createdAt }

// OK: コードで十分
list.sortedBy { it.createdAt }
```

### テストコードには What

テストは仕様書の役割を持つ。「何をすべきか」を明示することで、実装の意図が伝わる。

### コミットログには Why

変更の背景・理由をコミットメッセージに残す。  
「何を変えたか」はdiffを見ればわかるので不要。

```
# NG
fix NullPointerException

# OK
ユーザーが未登録の場合にnullが返る仕様のため、Optional.emptyに統一
```

### コードコメントには Why not

コメントで最も価値が高いのは「なぜそうしなかったのか」。  
意図的に避けた実装・制約・トレードオフを残しておくことで、後から読む人が同じ過ちを繰り返さない。

```kotlin
// ConcurrentHashMapを使わない理由: このコードはシングルスレッドで動作するため、
// 同期コストを避けてHashMapを使用している
val cache = HashMap<String, Result>()
```

---

## 関連リンク

- [一次ソース（X）](https://x.com/t_wada/status/904916106153828352)
- [解説記事（Zenn）](https://zenn.dev/never_be_a_pm/articles/69d204df1a8c4a)
