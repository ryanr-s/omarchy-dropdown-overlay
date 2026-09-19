#!/usr/bin/env bash
# Register an app as a Quake-style dropdown overlay: window rule + keybinding.
#
# Usage:
#   ./install.sh --name <slug> --key "SUPER + SHIFT + X" --class "<window class or regex>" \
#     --launch "<launch command>" [--workspace <name>] [--size WxH] [--opacity N] [--no-dim] \
#     [--label "<description>"]
#
# Each --name registers its own independently installable/uninstallable block,
# so this one plugin can drive dropdowns for as many apps as you like:
#   ./install.sh --name hermes --key "SUPER + SHIFT + H" --class Hermes \
#     --launch /usr/bin/hermes-desktop
#   ./install.sh --name tasks --key "SUPER + SHIFT + T" \
#     --class '^chrome-cloud\.ryansaito\.com__apps_tasks_collections_week-Default$' \
#     --launch 'omarchy-launch-webapp https://cloud.ryansaito.com/apps/tasks/collections/week' \
#     --size 0.6x0.75
#
# Recommended install path (keeps the plugin updatable via `omarchy plugin update`):
#   omarchy plugin add <git-url>
#   ~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh --name ... --key ... --class ... --launch ...

set -euo pipefail

PLUGIN_ID="ryanrs.dropdown-overlay"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME=""
KEY=""
APP_CLASS=""
LAUNCH_CMD=""
WORKSPACE=""
SIZE="0.75x0.75"
OPACITY="0.96"
DIM=1
LABEL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --key) KEY="$2"; shift 2 ;;
    --class) APP_CLASS="$2"; shift 2 ;;
    --launch) LAUNCH_CMD="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --opacity) OPACITY="$2"; shift 2 ;;
    --no-dim) DIM=0; shift ;;
    --label) LABEL="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n $NAME ]] || { echo "install.sh: --name is required" >&2; exit 1; }
[[ $NAME =~ ^[A-Za-z0-9_-]+$ ]] || { echo "install.sh: --name must be alphanumeric/-/_" >&2; exit 1; }
[[ -n $KEY ]] || { echo "install.sh: --key is required" >&2; exit 1; }
[[ -n $APP_CLASS ]] || { echo "install.sh: --class is required" >&2; exit 1; }
[[ -n $LAUNCH_CMD ]] || { echo "install.sh: --launch is required" >&2; exit 1; }
[[ -n $WORKSPACE ]] || WORKSPACE="$NAME"
[[ -n $LABEL ]] || LABEL="$NAME dropdown"

if [[ $SIZE =~ ^([0-9]*\.?[0-9]+)x([0-9]*\.?[0-9]+)$ ]]; then
  WIDTH_FRAC="${BASH_REMATCH[1]}"
  HEIGHT_FRAC="${BASH_REMATCH[2]}"
else
  echo "install.sh: --size must look like 0.75x0.75" >&2
  exit 1
fi

BLOCK_TAG="$PLUGIN_ID:$NAME"

HYPR_DIR="$HOME/.config/hypr"
HYPRLAND_LUA="$HYPR_DIR/hyprland.lua"
BINDINGS_LUA="$HYPR_DIR/bindings.lua"

for file in "$HYPRLAND_LUA" "$BINDINGS_LUA"; do
  [[ -f $file ]] || { echo "install.sh: missing $file — is Omarchy installed?" >&2; exit 1; }
done
command -v hyprctl >/dev/null || { echo "install.sh: hyprctl not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "install.sh: jq not found" >&2; exit 1; }

TOGGLE_SCRIPT="$PLUGIN_DIR/scripts/dropdown-toggle"
chmod +x "$TOGGLE_SCRIPT"

if omarchy menu keybindings --print 2>/dev/null | grep -qF "$KEY"; then
  echo "NOTE: '$KEY' is already bound. The managed block below unbinds it first."
fi

remove_block() {
  local file=$1
  awk -v begin="-- BEGIN $BLOCK_TAG " -v end="-- END $BLOCK_TAG" '
    index($0, begin) == 1 { inblock = 1; next }
    inblock && index($0, end) == 1 { inblock = 0; next }
    !inblock { print }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

append_block() {
  local file=$1 body=$2
  printf '\n%s\n%s\n%s\n' \
    "-- BEGIN $BLOCK_TAG (managed by install.sh/uninstall.sh --name $NAME)" \
    "$body" \
    "-- END $BLOCK_TAG" >> "$file"
}

DIM_LINE=""
[[ $DIM -eq 1 ]] && DIM_LINE="    dim_around = true,"

RULE_BODY="o.window(
  { class = \"$APP_CLASS\" },
  {
    float = true,
    size = { \"(monitor_w*$WIDTH_FRAC)\", \"(monitor_h*$HEIGHT_FRAC)\" },
    center = true,
    workspace = \"special:$WORKSPACE silent\",
    opacity = \"$OPACITY\",
$DIM_LINE
  }
)"

BINDING_BODY="hl.unbind(\"$KEY\")
o.bind(\"$KEY\", \"$LABEL\", \"env DROPDOWN_CLASS='$APP_CLASS' DROPDOWN_WORKSPACE='$WORKSPACE' DROPDOWN_LAUNCH='$LAUNCH_CMD' $TOGGLE_SCRIPT\")"

remove_block "$HYPRLAND_LUA"
append_block "$HYPRLAND_LUA" "$RULE_BODY"

remove_block "$BINDINGS_LUA"
append_block "$BINDINGS_LUA" "$BINDING_BODY"

hyprctl reload >/dev/null
sleep 1
ERRORS=$(hyprctl configerrors)
if [[ -n $ERRORS ]]; then
  echo "Hyprland reported config errors:" >&2
  echo "$ERRORS" >&2
  exit 1
fi

echo "Installed dropdown overlay '$NAME'."
echo "  Key:      $KEY   (toggles the HUD; launches if not running)"
echo "  Rule:     floating, centered, ${WIDTH_FRAC}x${HEIGHT_FRAC} of monitor, special workspace '$WORKSPACE'"
echo "Uninstall with: $(dirname "$0")/uninstall.sh --name $NAME"
