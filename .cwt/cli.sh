# shellcheck shell=bash
# CWT CLI — define the `cwt` shell function.
#
# This file is sourced (not executed). Expects CWT_TEMPLATE_DIR to be set
# by the bootstrap file (~/.cwt-cli.sh installed by scripts/install-cwt-cli.sh).

if [ -z "${CWT_TEMPLATE_DIR:-}" ]; then
  echo "cwt: CWT_TEMPLATE_DIR not set. Re-run 'make cwt-install' in the template directory." >&2
  return 1 2>/dev/null || exit 1
fi

if [ ! -d "$CWT_TEMPLATE_DIR/.cwt" ]; then
  echo "cwt: CWT_TEMPLATE_DIR ($CWT_TEMPLATE_DIR) is not a CWT template. Re-run 'make cwt-install'." >&2
  return 1 2>/dev/null || exit 1
fi

_cwt_open_browser() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url" 2>/dev/null || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" 2>/dev/null || true
  fi
}

cwt() {
  local sub="${1:-help}"
  shift 2>/dev/null || true
  case "$sub" in
    new)
      # Global landing server: scaffold a project from a prose description.
      # No need to be in any particular directory.
      local global_dir="$HOME/.cwt-global"
      mkdir -p "$global_dir"
      local port_file="$global_dir/port"
      # If a cwt-new-server is already running and reachable, reuse it
      if [ -f "$port_file" ] && curl -s -o /dev/null "http://127.0.0.1:$(cat "$port_file")/" 2>/dev/null; then
        local existing_url="http://127.0.0.1:$(cat "$port_file")/"
        echo "  cwt new already running → $existing_url"
        _cwt_open_browser "$existing_url"
        return 0
      fi
      rm -f "$port_file"
      nohup python3 "$CWT_TEMPLATE_DIR/scripts/cwt-new-server.py" > "$global_dir/server.log" 2>&1 &
      disown 2>/dev/null || true
      local tries=0
      while [ ! -f "$port_file" ] && [ $tries -lt 40 ]; do
        sleep 0.1
        tries=$((tries + 1))
      done
      if [ ! -f "$port_file" ]; then
        echo "cwt new: server did not start. Check $global_dir/server.log" >&2
        return 1
      fi
      local url="http://127.0.0.1:$(cat "$port_file")/"
      echo "  new-project launcher → $url"
      _cwt_open_browser "$url"
      ;;
    wizard)
      # Start the cwt-new-server (which now serves /setup.html + /api/suggest-wizard
      # for Gemini recommendations) and open the wizard. Same server that powers
      # `cwt new` — reused so the wizard can call Gemini on the same origin.
      local global_dir="$HOME/.cwt-global"
      mkdir -p "$global_dir"
      local port_file="$global_dir/port"
      if [ ! -f "$port_file" ] || ! curl -s -o /dev/null "http://127.0.0.1:$(cat "$port_file")/" 2>/dev/null; then
        rm -f "$port_file"
        nohup python3 "$CWT_TEMPLATE_DIR/scripts/cwt-new-server.py" > "$global_dir/server.log" 2>&1 &
        disown 2>/dev/null || true
        local tries=0
        while [ ! -f "$port_file" ] && [ $tries -lt 40 ]; do
          sleep 0.1
          tries=$((tries + 1))
        done
        if [ ! -f "$port_file" ]; then
          echo "cwt wizard: server did not start. Check $global_dir/server.log" >&2
          return 1
        fi
      fi
      local url="http://127.0.0.1:$(cat "$port_file")/setup.html"
      echo "  Wizard: $url"
      _cwt_open_browser "$url"
      ;;
    config)
      # `cwt config gemini` — store a Gemini API key for AI features.
      local sub2="${1:-}"
      case "$sub2" in
        gemini|gemini-key)
          local secrets_dir="$HOME/.cwt-secrets"
          local key_file="$secrets_dir/gemini-key"
          mkdir -p "$secrets_dir"
          chmod 700 "$secrets_dir"
          echo ""
          echo "  Gemini powers architecture suggestions + plain-English plan summaries."
          echo "  Get a free key: https://aistudio.google.com/apikey"
          echo ""
          read -rp "  Paste your Gemini API key (input hidden, or blank to cancel): " -s new_key
          echo ""
          if [ -z "$new_key" ]; then
            echo "  Cancelled."
            return 0
          fi
          echo -n "$new_key" > "$key_file"
          chmod 600 "$key_file"
          echo "  ✓ saved to $key_file"
          echo "  Restart any running CWT dashboards to pick it up."
          ;;
        ""|*)
          echo "usage: cwt config gemini"
          return 1
          ;;
      esac
      ;;
    init)
      if [ -z "${1:-}" ]; then
        echo "usage: cwt init <name> [dest]"
        echo "  example: cwt init my-app         → ~/dev/my-app"
        echo "  example: cwt init my-app ~/code  → ~/code/my-app"
        echo ""
        echo "  tip: \`cwt new\` skips the name-pick step and suggests a name for you"
        return 1
      fi
      local name="$1"
      local dest_parent="${2:-$HOME/dev}"
      local project_dir="$dest_parent/$name"
      if [ -n "${2:-}" ]; then
        (cd "$CWT_TEMPLATE_DIR" && CWT_INIT_WRAPPED=1 make cwt-init NAME="$name" DEST="$dest_parent") || return 1
      else
        (cd "$CWT_TEMPLATE_DIR" && CWT_INIT_WRAPPED=1 make cwt-init NAME="$name") || return 1
      fi
      # Auto-cd into new project (only possible because cwt is a shell function)
      if [ -d "$project_dir" ]; then
        cd "$project_dir" || return 1
        # Auto-boot the dashboard + open browser
        echo ""
        echo "  booting dashboard..."
        nohup python3 .cwt/server.py > .cwt/server.log 2>&1 &
        disown 2>/dev/null || true
        local tries=0
        while [ ! -f .cwt/port ] && [ $tries -lt 30 ]; do
          sleep 0.1
          tries=$((tries + 1))
        done
        local url=""
        if [ -f .cwt/port ]; then
          url="http://127.0.0.1:$(cat .cwt/port)/"
          _cwt_open_browser "$url"
        fi
        echo ""
        echo "────────────────────────────────────────────────────────────"
        echo "  You are now in: $project_dir"
        if [ -n "$url" ]; then
          echo "  Dashboard:      $url (browser opening…)"
        else
          echo "  Dashboard:      failed to boot — see .cwt/server.log"
        fi
        echo "────────────────────────────────────────────────────────────"
        echo ""
        echo "  Next:"
        echo "    cwt build                    open the App Maker here"
        echo "    /cwt-plan <feature>          draft a plan (inside App Maker)"
        echo "    cwt down                     stop the dashboard"
        echo ""
      fi
      ;;
    build|maker|app)
      if ! command -v claude >/dev/null 2>&1; then
        echo "cwt build: claude CLI not found in PATH." >&2
        echo "  install Claude Code first: https://claude.ai/code" >&2
        return 1
      fi
      command claude "$@"
      ;;
    up)
      if [ ! -f .cwt/server.py ]; then
        echo "cwt up: no .cwt/server.py here — are you in a CWT fork?" >&2
        return 1
      fi
      if [ -f .cwt/port ] && curl -s -o /dev/null "http://127.0.0.1:$(cat .cwt/port)/api/plans" 2>/dev/null; then
        echo "  dashboard already running at http://127.0.0.1:$(cat .cwt/port)/"
        _cwt_open_browser "http://127.0.0.1:$(cat .cwt/port)/"
        return 0
      fi
      nohup python3 .cwt/server.py > .cwt/server.log 2>&1 &
      disown 2>/dev/null || true
      # Wait up to 3 seconds for .cwt/port to appear
      local tries=0
      while [ ! -f .cwt/port ] && [ $tries -lt 30 ]; do
        sleep 0.1
        tries=$((tries + 1))
      done
      if [ -f .cwt/port ]; then
        local port
        port="$(cat .cwt/port)"
        echo "  dashboard booted → http://127.0.0.1:$port/"
        echo "  logs: .cwt/server.log"
        _cwt_open_browser "http://127.0.0.1:$port/"
      else
        echo "  server did not start in time — check .cwt/server.log" >&2
        return 1
      fi
      ;;
    down|stop)
      if [ ! -f .cwt/port ]; then
        echo "  no .cwt/port — server not running (or not tracked)"
        return 0
      fi
      local port
      port="$(cat .cwt/port)"
      local pid
      pid="$(lsof -ti ":$port" 2>/dev/null || true)"
      if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
        echo "  stopped dashboard on port $port (pid $pid)"
      else
        echo "  no process found on port $port"
      fi
      rm -f .cwt/port
      ;;
    integrate)
      if [ -z "${1:-}" ]; then
        echo "usage: cwt integrate <target-dir>"
        echo "  wires CWT into an existing project"
        return 1
      fi
      (cd "$CWT_TEMPLATE_DIR" && make cwt-integrate TARGET="$1" "${@:2}")
      ;;
    upgrade)
      if [ ! -f .framework-version ]; then
        echo "cwt upgrade: run this from inside a CWT fork (no .framework-version in $PWD)" >&2
        return 1
      fi
      make cwt-upgrade "$@"
      ;;
    detect)
      bash "$CWT_TEMPLATE_DIR/scripts/detect-framework.sh" "${1:-.}"
      ;;
    team)
      if [ ! -f .cwt/tasks.py ]; then
        echo "cwt team: run this from inside a CWT fork (no .cwt/tasks.py in $PWD)" >&2
        return 1
      fi
      make cwt-team
      ;;
    graph)
      if [ ! -f .cwt/graph.py ]; then
        echo "cwt graph: run this from inside a CWT fork (no .cwt/graph.py in $PWD)" >&2
        return 1
      fi
      make cwt-graph
      ;;
    where|root)
      echo "$CWT_TEMPLATE_DIR"
      ;;
    version)
      if [ -f "$CWT_TEMPLATE_DIR/.framework-version" ]; then
        cat "$CWT_TEMPLATE_DIR/.framework-version"
      else
        echo "(unversioned — template not tagged)"
      fi
      ;;
    help|--help|-h|"")
      cat <<EOF
cwt — CoreWeave Template CLI

Usage:
  cwt new                   One-command flow: prompt → AI-suggested architecture → scaffold
  cwt init <name> [dest]    Scaffold a new CWT-gated project with a specific name
  cwt wizard                Open the original blueprint wizard (stack picker + folder tree)
  cwt build                 Open the App Maker (Claude Code) here
  cwt up                    Boot dashboard + open in browser
  cwt down                  Stop the dashboard
  cwt config gemini         Save a Gemini API key (enables AI suggestions + summaries)
  cwt integrate <path>      Wire CWT into an existing project
  cwt upgrade               Pull latest framework (from inside a fork)
  cwt detect [path]         Print detected stack (python/go/node/rust/empty)
  cwt team                  Show task DAG (from inside a fork)
  cwt graph                 Show import graph stats (from inside a fork)
  cwt where                 Print the template root directory
  cwt version               Print the template's framework version
  cwt help                  This help

Template: $CWT_TEMPLATE_DIR
EOF
      ;;
    *)
      echo "cwt: unknown subcommand '$sub'. Run 'cwt help'." >&2
      return 1
      ;;
  esac
}
