#!/usr/bin/env bash
# Uninstall one or all dropdown overlays registered by this plugin: removes
# the managed window-rule and keybinding blocks from your Hyprland config and
# reloads Hyprland.
# Does not remove the plugin folder itself (`omarchy plugin remove ryanrs.dropdown-overlay`).
#
# Usage:
#   ./uninstall.sh --name <slug>   # remove just that app's overlay
#   ./uninstall.sh --all           # remove every overlay this plugin registered

set -euo pipefail

PLUGIN_ID="ryanrs.dropdown-overlay"
HYPR_DIR="$HOME/.config/hypr"

NAME=""
ALL=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "uninstall.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ $ALL -eq 1 ]]; then
  BEGIN_PREFIX="-- BEGIN $PLUGIN_ID:"
elif [[ -n $NAME ]]; then
  BEGIN_PREFIX="-- BEGIN $PLUGIN_ID:$NAME "
else
  echo "uninstall.sh: pass --name <slug> or --all" >&2
  exit 1
fi

for file in "$HYPR_DIR/hyprland.lua" "$HYPR_DIR/bindings.lua"; do
  if [[ -f $file ]]; then
    awk -v begin_prefix="$BEGIN_PREFIX" -v end_prefix="-- END $PLUGIN_ID:" '
      index($0, begin_prefix) == 1 { inblock = 1; next }
      inblock && index($0, end_prefix) == 1 { inblock = 0; next }
      !inblock { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done

command -v hyprctl >/dev/null && hyprctl reload >/dev/null
if [[ $ALL -eq 1 ]]; then
  echo "All dropdown-overlay entries uninstalled."
else
  echo "Dropdown overlay '$NAME' uninstalled."
fi
