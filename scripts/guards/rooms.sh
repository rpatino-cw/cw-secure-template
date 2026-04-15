# guards/rooms.sh — Room boundaries + dependency protection + rename inbox
# Sourced by guard.sh. Uses: FILE_PATH, CONTENT, OLD_STRING, TOOL_NAME, AGENT_ROOM, REPO_ROOT

# --- Room boundary enforcement ---
if [[ -n "${AGENT_ROOM:-}" && -n "$FILE_PATH" ]]; then
  ROOMS_CONFIG="$REPO_ROOT/rooms.json"
  if [[ -f "$ROOMS_CONFIG" ]]; then
    ALLOWED=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
room = config.get('rooms', {}).get(sys.argv[2], {})
for p in room.get('owns', []):
    print(p)
" "$ROOMS_CONFIG" "$AGENT_ROOM" 2>/dev/null || echo "")

    if [[ -n "$ALLOWED" ]]; then
      IN_ROOM=false
      REL_PATH="${FILE_PATH#$REPO_ROOT/}"
      REL_PATH="${REL_PATH#./}"
      while IFS= read -r owned_path; do
        [[ -z "$owned_path" ]] && continue
        owned_path="${owned_path#./}"
        if [[ "$REL_PATH" == "$owned_path"* ]]; then
          IN_ROOM=true
          break
        fi
      done <<< "$ALLOWED"

      if [[ "$FILE_PATH" == *"rooms/"* ]]; then
        IN_ROOM=true
      fi

      if [[ "$IN_ROOM" == false ]]; then
        echo "BLOCKED: Agent '$AGENT_ROOM' cannot edit $FILE_PATH" >&2
        echo "" >&2
        echo "You own: $ALLOWED" >&2
        echo "" >&2
        echo "To request a change in this file, write to the owning room's inbox:" >&2
        echo "  rooms/{owner}/inbox/NNN-from-${AGENT_ROOM}.md" >&2
        echo "" >&2
        echo "Run 'make room-status' to see all rooms and their owners." >&2
        exit 2
      fi
    fi
  fi
fi

# --- Dependency protection (delete/rename) ---
if [[ "$TOOL_NAME" == "Edit" && -n "$OLD_STRING" && -n "${AGENT_ROOM:-}" && -n "$FILE_PATH" ]]; then
  ROOMS_CONFIG="$REPO_ROOT/rooms.json"

  if [[ -f "$ROOMS_CONFIG" ]]; then
    CHANGES=$(python3 -c "
import re, sys

old = sys.argv[1]
new = sys.argv[2]

patterns = [
    r'(?:^|\n)\s*def\s+(\w+)\s*\(',
    r'(?:^|\n)\s*class\s+(\w+)',
    r'(?:^|\n)\s*func\s+(\w+)\s*\(',
    r'(?:^|\n)\s*func\s+\([^)]+\)\s+(\w+)\s*\(',
    r'(?:^|\n)\s*(?:export\s+)?function\s+(\w+)',
    r'(?:^|\n)\s*(?:export\s+)?const\s+(\w+)\s*=',
]

skip = {'main','init','new','get','set','run','test','setup','teardown'}

old_names = set()
for p in patterns:
    old_names.update(re.findall(p, old))

new_names = set()
for p in patterns:
    new_names.update(re.findall(p, new))

removed = {n for n in (old_names - new_names) if len(n) > 2 and n not in skip}
added = {n for n in (new_names - old_names) if len(n) > 2 and n not in skip}

if len(removed) == 1 and len(added) == 1:
    old_n = removed.pop()
    new_n = added.pop()
    print(f'RENAME:{old_n}:{new_n}')
else:
    for name in sorted(removed):
        print(f'DELETE:{name}')
" "$OLD_STRING" "$CONTENT" 2>/dev/null || echo "")

    if [[ -n "$CHANGES" ]]; then
      ALLOWED=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
room = config.get('rooms', {}).get(sys.argv[2], {})
for p in room.get('owns', []):
    print(p)
" "$ROOMS_CONFIG" "$AGENT_ROOM" 2>/dev/null || echo "")

      find_outside_refs() {
        local name="$1"
        local outside=""
        local refs
        refs=$(grep -rn --include="*.go" --include="*.py" --include="*.js" --include="*.ts" \
          -w "$name" "$REPO_ROOT" 2>/dev/null \
          | grep -v "$FILE_PATH" \
          | grep -v "_test\." \
          | grep -v "rooms/" \
          | head -5 || true)

        [[ -z "$refs" ]] && return

        while IFS= read -r ref_line; do
          [[ -z "$ref_line" ]] && continue
          local ref_file ref_rel in_room=false
          ref_file=$(echo "$ref_line" | cut -d: -f1)
          ref_rel="${ref_file#$REPO_ROOT/}"

          while IFS= read -r owned; do
            [[ -z "$owned" ]] && continue
            owned="${owned#./}"
            if [[ "$ref_rel" == "$owned"* ]]; then
              in_room=true
              break
            fi
          done <<< "$ALLOWED"

          if [[ "$in_room" == false ]]; then
            outside="${outside}  ${ref_line}\n"
          fi
        done <<< "$refs"

        echo "$outside"
      }

      while IFS= read -r change; do
        [[ -z "$change" ]] && continue
        TYPE=$(echo "$change" | cut -d: -f1)
        NAME=$(echo "$change" | cut -d: -f2)

        if [[ "$TYPE" == "DELETE" ]]; then
          OUTSIDE=$(find_outside_refs "$NAME")
          if [[ -n "$OUTSIDE" ]]; then
            echo "BLOCKED: Removing '$NAME' would break code in other rooms" >&2
            echo "" >&2
            echo "These files reference '$NAME':" >&2
            echo -e "$OUTSIDE" >&2
            echo "Coordinate with the owning agent before removing." >&2
            echo "Send a request to their inbox: rooms/{room}/inbox/" >&2
            exit 2
          fi

        elif [[ "$TYPE" == "RENAME" ]]; then
          NEW_NAME=$(echo "$change" | cut -d: -f3)
          OUTSIDE=$(find_outside_refs "$NAME")
          if [[ -n "$OUTSIDE" ]]; then
            TS=$(date +%Y%m%d-%H%M%S)

            NOTIFIED_ROOMS=""
            while IFS= read -r ref_line; do
              [[ -z "$ref_line" ]] && continue
              ref_file=$(echo "$ref_line" | cut -d: -f1)
              ref_rel="${ref_file#$REPO_ROOT/}"

              TARGET_ROOM=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
path = sys.argv[2]
for name, room in config.get('rooms', {}).items():
    for owned in room.get('owns', []):
        if path.startswith(owned.strip('/')):
            print(name)
            break
" "$ROOMS_CONFIG" "$ref_rel" 2>/dev/null || echo "")

              if [[ -n "$TARGET_ROOM" && "$TARGET_ROOM" != "$AGENT_ROOM" && ! "$NOTIFIED_ROOMS" == *"$TARGET_ROOM"* ]]; then
                INBOX_DIR="$REPO_ROOT/rooms/$TARGET_ROOM/inbox"
                if [[ -d "$INBOX_DIR" ]]; then
                  cat > "$INBOX_DIR/${TS}-from-${AGENT_ROOM}.md" << REQEOF
---
from: ${AGENT_ROOM}
priority: high
type: rename
---

**Function renamed** — please update your references:

\`$NAME\` → \`$NEW_NAME\`

File changed: $(basename "$FILE_PATH")

Your files that reference the old name:
$(echo -e "$OUTSIDE" | grep "$TARGET_ROOM" || echo -e "$OUTSIDE")
REQEOF
                  NOTIFIED_ROOMS="${NOTIFIED_ROOMS} ${TARGET_ROOM}"
                fi
              fi
            done <<< "$(echo -e "$OUTSIDE")"

            echo "<dependency-rename>"
            echo "You renamed '$NAME' → '$NEW_NAME'"
            echo ""
            if [[ -n "$NOTIFIED_ROOMS" ]]; then
              echo "Auto-sent inbox requests to:$NOTIFIED_ROOMS"
              echo "They will see the rename and update their references."
            fi
            echo "</dependency-rename>"
          fi
        fi
      done <<< "$CHANGES"
    fi
  fi
fi
