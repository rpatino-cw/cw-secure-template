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

cwt() {
  local sub="${1:-help}"
  shift 2>/dev/null || true
  case "$sub" in
    init)
      if [ -z "${1:-}" ]; then
        echo "usage: cwt init <name> [dest]"
        echo "  example: cwt init my-app         → ~/dev/my-app"
        echo "  example: cwt init my-app ~/code  → ~/code/my-app"
        return 1
      fi
      local name="$1"
      local dest="${2:-}"
      if [ -n "$dest" ]; then
        (cd "$CWT_TEMPLATE_DIR" && make cwt-init NAME="$name" DEST="$dest")
      else
        (cd "$CWT_TEMPLATE_DIR" && make cwt-init NAME="$name")
      fi
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

Template root: $CWT_TEMPLATE_DIR

Usage:
  cwt init <name> [dest]    Scaffold a new CWT-gated project
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
