#!/usr/bin/env bash
# detect-framework.sh — emit the primary stack of a project.
#
# Usage:
#   ./scripts/detect-framework.sh [target-dir]
#
# Prints one of: python | go | node | rust | empty
# Used by integrate/upgrade/init flows to know which framework paths apply.
set -uo pipefail

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "empty"; exit 0; }

declare -a candidates=()

[ -f "$TARGET/pyproject.toml" ] && candidates+=("python")
[ -f "$TARGET/requirements.txt" ] && [[ ! " ${candidates[*]} " =~ " python " ]] && candidates+=("python")
[ -f "$TARGET/go.mod" ] && candidates+=("go")
[ -f "$TARGET/package.json" ] && candidates+=("node")
[ -f "$TARGET/Cargo.toml" ] && candidates+=("rust")

case "${#candidates[@]}" in
  0) echo "empty" ;;
  1) echo "${candidates[0]}" ;;
  *)
    # Multi-stack. Prefer the one whose directory structure looks most
    # populated (python/ vs go/ vs frontend/ subdir counts).
    best=""
    best_count=0
    for c in "${candidates[@]}"; do
      case "$c" in
        python) dir="$TARGET/python" ;;
        go)     dir="$TARGET/go" ;;
        node)   dir="$TARGET/frontend" ;;
        rust)   dir="$TARGET/src" ;;
      esac
      count=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [ "$count" -gt "$best_count" ]; then
        best="$c"
        best_count="$count"
      fi
    done
    echo "${best:-${candidates[0]}}"
    ;;
esac
