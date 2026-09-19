#!/usr/bin/env bash
# Register an app as a Quake-style dropdown overlay: window rule + keybinding.
#
# Usage:
#   ./install.sh --name <slug> --key "SUPER + SHIFT + X" (--url <url> | --launch "<command>") \
#     [--class "<window class or regex>"] [--workspace <name>] [--size WxH] [--opacity N] \
#     [--no-dim] [--label "<description>"]
#
# --class is optional: if you leave it out, install.sh launches the app for
# you, watches for the new window, and figures out its class itself — no need
# to dig through `hyprctl clients -j` by hand.
#
# --url is a shortcut for webapps: it's equivalent to
# --launch "omarchy-launch-webapp '<url>'".
#
# Each --name registers its own independently installable/uninstallable block,
# so this one plugin can drive dropdowns for as many apps as you like:
#   ./install.sh --name hermes --key "SUPER + SHIFT + H" --launch /usr/bin/hermes-desktop
#   ./install.sh --name tasks --key "SUPER + SHIFT + T" \
#     --url 'https://cloud.ryansaito.com/apps/tasks/collections/week' --size 0.6x0.75
#
# Recommended install path (keeps the plugin updatable via `omarchy plugin update`):
#   omarchy plugin add <git-url>
#   ~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh --name ... --key ... --url ...

set -euo pipefail

PLUGIN_ID="ryanrs.dropdown-overlay"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME=""
KEY=""
APP_CLASS=""
LAUNCH_CMD=""
URL=""
WORKSPACE=""
SIZE="0.75x0.75"
OPACITY="0.96"
DIM=1
LABEL=""
DETECT_TIMEOUT=20
DETECTION_WINDOW_CLOSED=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --key) KEY="$2"; shift 2 ;;
    --class) APP_CLASS="$2"; shift 2 ;;
    --launch) LAUNCH_CMD="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --opacity) OPACITY="$2"; shift 2 ;;
    --no-dim) DIM=0; shift ;;
    --label) LABEL="$2"; shift 2 ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n $NAME ]] || { echo "install.sh: --name is required" >&2; exit 1; }
[[ $NAME =~ ^[A-Za-z0-9_-]+$ ]] || { echo "install.sh: --name must be alphanumeric/-/_" >&2; exit 1; }
[[ -n $KEY ]] || { echo "install.sh: --key is required" >&2; exit 1; }

if [[ -z $LAUNCH_CMD ]]; then
  [[ -n $URL ]] || { echo "install.sh: pass --launch <command> or --url <url>" >&2; exit 1; }
  LAUNCH_CMD="omarchy-launch-webapp '$URL'"
fi

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

# Keep the omarchy-dropdown-install/-remove CLI on PATH, symlinked from this
# plugin's bin/ so `omarchy plugin update` picks up fixes automatically.
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
for cli in "$PLUGIN_DIR"/bin/*; do
  chmod +x "$cli"
  ln -sf "$cli" "$LOCAL_BIN/$(basename "$cli")"
done

# Escape regex metacharacters so an auto-detected class (a literal string) is
# matched exactly rather than interpreted as a pattern.
regex_escape() {
  local s=$1 out="" c i
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      '.'|'^'|'$'|'*'|'+'|'?'|'('|')'|'['|']'|'{'|'}'|'|'|'\')
        out+="\\$c" ;;
      *) out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

# Launch the app and watch for a window class that wasn't there before, so
# --class can be figured out automatically instead of asking the user to go
# read `hyprctl clients -j` themselves. Sets DETECTED_CLASS/DETECTED_PID.
detect_class() {
  local before after new_class
  before=$(hyprctl clients -j | jq -r '.[].class' | sort -u)
  setsid bash -c "exec $LAUNCH_CMD" >/dev/null 2>&1 &
  local i
  for (( i=0; i<DETECT_TIMEOUT*10; i++ )); do
    after=$(hyprctl clients -j | jq -r '.[].class' | sort -u)
    new_class=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -1)
    if [[ -n $new_class ]]; then
      DETECTED_CLASS="$new_class"
      DETECTED_PID=$(hyprctl clients -j | jq -r --arg c "$new_class" '[.[] | select(.class == $c)][0].pid // ""')
      return 0
    fi
    sleep 0.1
  done
  return 1
}

if [[ -z $APP_CLASS ]]; then
  echo "install.sh: no --class given; launching '$LAUNCH_CMD' to detect its window class (up to ${DETECT_TIMEOUT}s)..." >&2
  detect_class || {
    echo "install.sh: no new window appeared. If '$NAME' was already running, close it and try again," >&2
    echo "  or pass --class explicitly (check: hyprctl clients -j | jq -r '.[].class')." >&2
    exit 1
  }
  echo "install.sh: detected class '$DETECTED_CLASS'" >&2
  APP_CLASS="^$(regex_escape "$DETECTED_CLASS")\$"
  # The window that was just launched to detect the class predates the window
  # rule we're about to write, so it never got floated/sized/moved to the
  # special workspace. Kill its process directly — this Hyprland build's
  # `hyprctl dispatch` only accepts its own Lua-call syntax, not a plain
  # `closewindow class:...` selector, so a pid kill is the reliable path.
  # The next press of the keybinding launches a fresh one that the rule
  # (installed below) applies to from creation.
  if [[ -n ${DETECTED_PID:-} ]]; then
    kill "$DETECTED_PID" 2>/dev/null || true
    DETECTION_WINDOW_CLOSED=1
  fi
fi

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

# Lua double-quoted strings only recognize a handful of backslash escapes, so
# any literal backslash in a value we splice in (e.g. a class regex like
# '^chrome-cloud\.example\.com$') must become \\ or Lua's parser rejects it.
lua_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

LUA_APP_CLASS=$(lua_escape "$APP_CLASS")
LUA_LABEL=$(lua_escape "$LABEL")
LUA_LAUNCH_CMD=$(lua_escape "$LAUNCH_CMD")
LUA_KEY=$(lua_escape "$KEY")

RULE_BODY="o.window(
  { class = \"$LUA_APP_CLASS\" },
  {
    float = true,
    size = { \"(monitor_w*$WIDTH_FRAC)\", \"(monitor_h*$HEIGHT_FRAC)\" },
    center = true,
    workspace = \"special:$WORKSPACE silent\",
    opacity = \"$OPACITY\",
$DIM_LINE
  }
)"

BINDING_BODY="hl.unbind(\"$LUA_KEY\")
o.bind(\"$LUA_KEY\", \"$LUA_LABEL\", \"env DROPDOWN_CLASS='$LUA_APP_CLASS' DROPDOWN_WORKSPACE='$WORKSPACE' DROPDOWN_LAUNCH='$LUA_LAUNCH_CMD' $TOGGLE_SCRIPT\")"

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
[[ $DETECTION_WINDOW_CLOSED -eq 1 ]] && echo "  Note:     closed the detection window — press $KEY to summon it properly styled"
echo "Uninstall with: $(dirname "$0")/uninstall.sh --name $NAME"
