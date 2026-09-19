# ryanrs.dropdown-overlay

ALll credit goes to https://github.com/crueber/omarchy-hermes-desktop-overlay

A Quake-style pull-down HUD for any app or web app on [Omarchy](https://omarchy.org).
Press a hotkey and the app drops down over whatever you're doing, floating
and centered, dimming the background behind it. Press the same hotkey again
and it slides back out of the way. If the app isn't running yet, the first
press launches it. This is the classic "quake console" / drop-down terminal
pattern, generalized to work with any window.

It's a generic, multi-app Omarchy plugin: instead of writing a dedicated
plugin per app, you register as many dropdowns as you want through one
`install.sh`/CLI, each independently addressable by name.

## What it does

- Turns any app or web app into a drop-down overlay on its own hotkey.
- Keeps that app parked off-screen (in a dedicated Hyprland "special"
  workspace) between uses instead of closing it, so re-opening it is instant.
- Launches the app for you on the first press if it isn't already running.
- Figures out the app's window class for you — you don't need to go digging
  through `hyprctl clients -j` by hand.
- Manages its own clearly-marked, idempotent blocks in your Hyprland config,
  so installing/removing one app never touches another's setup.

## How it works

Omarchy's Hyprland config here is written in Lua (`~/.config/hypr/*.lua`),
which itself compiles down to Hyprland's window rules, keybindings, and
dispatchers. This plugin has three pieces:

1. **A window rule** (written into `~/.config/hypr/hyprland.lua`) that
   matches the app's window class and forces it: floating, centered, sized
   to a fraction of the monitor, opened silently into a dedicated
   `special:<name>` workspace so it doesn't interrupt your current view when
   it first launches.

2. **A keybinding** (written into `~/.config/hypr/bindings.lua`) that runs
   `scripts/dropdown-toggle` with the app's class/workspace/launch command as
   env vars. That script checks whether a window with the matching class is
   already open (via `hyprctl clients -j` + a regex match — the class you
   register can be a plain string or an anchored regex like
   `^chrome-example\.com__-Default$`), launches the app if not, then
   dispatches a "toggle special workspace" command.

3. **Hyprland's special workspaces**, which render as an overlay on top of
   whatever workspace you're currently looking at (rather than switching you
   to them), and inherit Omarchy's built-in slide animation — that's what
   produces the drop-down effect. Toggling a special workspace show/hides it
   without destroying the window, so the app stays warm between uses.

Each app gets its own uniquely-tagged block in both Lua files
(`-- BEGIN ryanrs.dropdown-overlay:<name>` / `-- END ...`), so `install.sh`
can find-and-replace just that app's config on reinstall, and
`uninstall.sh`/`omarchy-dropdown-remove` can cleanly remove just that one.

### Figuring out the window class automatically

The trickiest part of wiring one of these up by hand is knowing the exact
window class Hyprland assigns the app — for a web app launched via
`omarchy-launch-webapp`, that's an opaque string like
`chrome-cloud.example.com__apps_foo-Default`, derived from the URL by
Chromium, not something you'd guess.

So when you don't pass `--class` yourself, `install.sh`:

1. Snapshots every currently-open window's class.
2. Launches the app.
3. Polls for a new class that wasn't in the snapshot (up to 20s).
4. Escapes it into a safe, exact-match regex and uses that.
5. Kills that detection window's process — it was launched *before* the
   window rule existed, so it never got floated/sized/moved into the special
   workspace. The next press of the keybinding launches a fresh one that the
   rule applies to from the moment it's created.

(This Hyprland build's `hyprctl dispatch` only understands its own Lua-call
dispatch syntax, not the vanilla `dispatcher selector` form, so closing the
detection window by class selector wasn't reliable — killing its pid
directly is.)

## Requirements

- Omarchy (Hyprland with Lua config)
- `jq`
- `gum` (for the interactive CLI; ships with Omarchy)

## Quick start

The easiest way — interactive, in the same spirit as Omarchy's own
`omarchy-webapp-install`/`omarchy-webapp-remove`:

```bash
omarchy-dropdown-install
```

It asks: web app or other app? → URL or launch command? → name (suggested
for you) → keybinding (suggested for you) — then launches the app once to
detect its window class, installs the rule + keybinding, and reloads
Hyprland.

```bash
omarchy-dropdown-remove
```

With no name, shows a picker of every overlay currently installed and
removes the one you choose.

Both commands are symlinked into `~/.local/bin` (from this plugin's `bin/`)
and also accept arguments directly, skipping the prompts entirely — see
below.

## Scriptable usage

For a web app, just give it a URL:

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
  --name tasks --key "SUPER + SHIFT + T" \
  --url 'https://cloud.example.com/apps/tasks' --size 0.6x0.75
```

For any other app, give it the launch command:

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
  --name hermes --key "SUPER + SHIFT + H" --launch /usr/bin/hermes-desktop
```

`--class` is optional (see "Figuring out the window class automatically"
above) — pass it explicitly only if auto-detection picks the wrong window
(e.g. the app also briefly opens some other transient window on startup) or
the app was already running when you tried to install it.

Re-running `install.sh` with the same `--name` replaces just that app's
blocks — safe to tweak and rerun.

### Options

| Flag | Required | Default | Meaning |
|------|----------|---------|---------|
| `--name` | yes | — | Slug identifying this overlay; also the default special-workspace name |
| `--key` | yes | — | Keybinding, e.g. `"SUPER + SHIFT + X"` |
| `--url` | one of `--url`/`--launch` | — | Web app shortcut; equivalent to `--launch "omarchy-launch-webapp '<url>'"` |
| `--launch` | one of `--url`/`--launch` | — | Shell command to launch the app if it isn't running |
| `--class` | no | auto-detected | Window class (or regex) to match |
| `--workspace` | no | `--name` | Special workspace name |
| `--size` | no | `0.75x0.75` | Fraction of monitor width x height, e.g. `0.6x0.75` |
| `--opacity` | no | `0.96` | Window opacity |
| `--no-dim` | no | (dim on) | Disable dimming the background |
| `--label` | no | `<name> dropdown` | Description shown in `omarchy menu keybindings --print` |

## Uninstalling

```bash
omarchy-dropdown-remove tasks
# or, calling the plugin script directly:
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/uninstall.sh --name tasks
```

Remove everything this plugin registered:

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/uninstall.sh --all
```

Neither removes the plugin itself — that's
`omarchy plugin remove ryanrs.dropdown-overlay`.

## Troubleshooting

- **"no new window appeared" during install** — the app was probably
  already running (many apps focus their existing window instead of opening
  a new one), so there was nothing new to detect. Close it and retry, or
  pass `--class` explicitly (find it with
  `hyprctl clients -j | jq -r '.[].class'`).
- **Wrong window got detected** — some apps briefly open a splash/update
  window on launch. Pass `--class` explicitly to skip detection.
- **Key doesn't do anything** — check for a collision with
  `omarchy menu keybindings --print`; `install.sh` warns about this at
  install time but doesn't block on it.
- **Hyprland reports config errors after install** — `install.sh` checks
  `hyprctl configerrors` itself and refuses to leave you in a broken state
  (it exits nonzero and prints the error), so this shouldn't happen; if it
  does, the offending block is still tagged and easy to find/remove by hand.

## License

MIT
