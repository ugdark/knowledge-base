---
title: "Claude Code statusLineコスト表示ガイド"
category: "claude-code"
tags: [claude-code, statusline, settings-json, cost]
created: 2026-06-26
updated: 2026-06-26
---

# Claude Code statusLineコスト表示ガイド

## 概要

Claude Code のターミナル下部（statusLine）に、セッション累計コスト・経過時間・コンテキスト使用率・トークン数・コード変更行数を常時表示する手順。追加のAPI呼び出しは発生しない。

---

## 表示イメージ

```
[Claude Sonnet 4.6] | 🌿 main
💰 ¥138.1 | ⏱️ 13m 2s (API: 8m 30s) | ctx: 20% (in: 45673, out: 89) | +42 -7
```

## 手順

### 1. スクリプト作成

`~/.claude/statusline.sh` を作成して実行権限を付与する。

```bash
cat > ~/.claude/statusline.sh << 'EOF'
#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
COST_USD=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_JPY=$(echo "$COST_USD * 160" | bc -l | xargs printf '%.1f')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
API_DURATION_MS=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))
API_MINS=$((API_DURATION_MS / 60000)); API_SECS=$(((API_DURATION_MS % 60000) / 1000))
BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"
echo "[$MODEL]$BRANCH"
echo "💰 ¥${COST_JPY} | ⏱️ ${MINS}m ${SECS}s (API: ${API_MINS}m ${API_SECS}s) | ctx: ${PCT}% (in: ${INPUT_TOKENS}, out: ${OUTPUT_TOKENS}) | +${LINES_ADDED} -${LINES_REMOVED}"
EOF
chmod +x ~/.claude/statusline.sh
```

### 2. settings.json に追記

`~/.claude/settings.json` に以下を追加する。

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh"
}
```

## 表示項目

| 項目 | 内容 |
|------|------|
| `¥138.1` | セッション累計コスト（USD×160円換算） |
| `⏱️ 13m 2s` | セッション経過時間（APIの待ち時間も内訳表示） |
| `ctx: 20%` | コンテキストウィンドウの使用率 |
| `in / out` | 入出力トークンの累計 |
| `+42 -7` | このセッションで変更したコード行数 |

## 補足

- **コストはかからない**。Claude Code が持つセッション情報を標準入力でスクリプトに流し込む仕組みのため、追加のAPI呼び出しは発生しない。
- 円換算レートはスクリプト内の `* 160` を編集して調整する。
- `jq` と `bc` が必要（macOS なら `brew install jq` 等）。

## 参考リンク

- [Claude Code settings.json リファレンス](Claude_Code_settings_json_リファレンス.md)
