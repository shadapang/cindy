#!/usr/bin/env bash
# sync-upstream.sh — 一键同步上游 makecindy/cindy 并推 CNB（流水线自动镜像 fork）
#
# 用法:  bash sync-upstream.sh
# 行为:  fetch upstream → 合并到 main（纯落后快进 / 有自有提交则 merge）→ push origin(CNB)
# 冲突:  保留冲突现场并以退出码 2 结束，按提示手动解决后自行 push
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

UP=upstream/main

# ── 0. 前置检查 ─────────────────────────────────────────────
br=$(git rev-parse --abbrev-ref HEAD)
if [ "$br" != "main" ]; then
  echo "✗ 当前在 $br，请先切到 main:  git checkout main"; exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "✗ 工作区有未提交改动，请先 commit 或 stash:"; git status --short | head -10; exit 1
fi

# ── 1. 拉上游 ───────────────────────────────────────────────
echo "→ fetch upstream (makecindy/cindy) ..."
git fetch upstream --prune
UP_SHA=$(git rev-parse --short "$UP")
LOC_SHA=$(git rev-parse --short HEAD)

if git merge-base --is-ancestor "$UP" HEAD; then
  echo "✓ 已是最新：本地 $LOC_SHA 已包含上游 $UP_SHA，无需同步"; exit 0
fi
BEHIND=$(git rev-list --count HEAD.."$UP")
AHEAD=$(git rev-list --count "$UP"..HEAD)
echo "  上游 $UP_SHA | 本地 $LOC_SHA | 落后 $BEHIND / 领先 $AHEAD"

# ── 2. 合并 ─────────────────────────────────────────────────
if [ "$AHEAD" -eq 0 ]; then
  echo "→ 纯落后，快进 ..."
  git merge --ff-only "$UP"
else
  echo "→ 本地有 $AHEAD 笔自有提交，生成合并提交 ..."
  if ! git merge "$UP" -m "merge: 同步上游 makecindy/cindy ($UP_SHA)"; then
    echo ""
    echo "⚠ 有冲突，请手动解决后继续："
    echo "   1) 编辑冲突文件 → git add <文件>"
    echo "   2) git commit"
    echo "   3) git push        # 推 CNB，流水线自动镜像 fork"
    exit 2
  fi
fi

# ── 3. 推 CNB ───────────────────────────────────────────────
echo "→ push origin (CNB main) ..."
git push origin main

NEW_SHA=$(git rev-parse --short HEAD)
echo ""
echo "✓ 完成: $LOC_SHA → $NEW_SHA  (上游 $UP_SHA)"
echo "  流水线将自动镜像到 GitHub fork shadapang/cindy"
