# ryanrs.dropdown-overlay

Quake-style pull-down HUD for any app on [Omarchy](https://omarchy.org). A
hotkey drops a floating window over part of your screen, dimming what's
behind it; press the hotkey again and it slides back up. If the app isn't
running yet, the first press launches it.

It works at the Hyprland level: each app you register lives in its own
special workspace (`special:<name>`) that overlays whatever you're working
on, with Omarchy's built-in slide animation. No QML UI — the plugin's shell
entry point is a deliberate no-op.

This is the generic, multi-app version of the pattern used by
single-purpose overlay plugins (e.g. Hermes Desktop): instead of one plugin
per app, `install.sh` registers as many named overlays as you want, each
independently installable/uninstallable.

## Requirements

- Omarchy (Hyprland 0.55+ with Lua config)
- `jq`

## Install an app

The easiest way — interactive, same idea as `omarchy-webapp-install`/
`omarchy-webapp-remove`: run it bare and answer a few prompts.

```bash
omarchy-dropdown-install
omarchy-dropdown-remove
```

`omarchy-dropdown-remove` with no name shows a picker of everything currently
installed. Both also accept args directly (skipping the prompts) — see below.

These are symlinked into `~/.local/bin` from `bin/` in this plugin, so they
stay on your `PATH` and update in place if you edit the plugin.

### The scriptable way

For a webapp, just give it a URL:

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
  --name tasks --key "SUPER + SHIFT + T" \
  --url 'https://cloud.ryansaito.com/apps/tasks/collections/week' --size 0.6x0.75
```

Or for any other app, just give it the launch command:

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
  --name hermes --key "SUPER + SHIFT + H" --launch /usr/bin/hermes-desktop
```

You don't need to figure out the window class yourself. If `--class` is
omitted, `install.sh` launches the app, watches for the new window, works out
its class automatically, and closes that detection window (a fresh, correctly
styled one appears the first time you press the keybinding). This is the
normal way to add an app — pass `--class` explicitly only if detection picks
the wrong window (e.g. the app also opens some other transient window) or the
app is already running and can't be launched a second time to detect.

`install.sh` writes clearly marked, idempotent blocks into
`~/.config/hypr/hyprland.lua` (window rule) and `~/.config/hypr/bindings.lua`
(keybinding) for that `--name`, then reloads Hyprland and validates the
config. Re-running with the same `--name` replaces just that app's blocks.

### Options

| Flag | Required | Default | Meaning |
|------|----------|---------|---------|
| `--name` | yes | — | Slug identifying this overlay; also used as the default special-workspace name |
| `--key` | yes | — | Keybinding, e.g. `"SUPER + SHIFT + X"` |
| `--url` | one of `--url`/`--launch` | — | Webapp shortcut; equivalent to `--launch "omarchy-launch-webapp '<url>'"` |
| `--launch` | one of `--url`/`--launch` | — | Shell command to launch the app if it isn't running |
| `--class` | no | auto-detected | Window class (or regex) to match; skip this to have it detected for you |
| `--workspace` | no | `--name` | Special workspace name |
| `--size` | no | `0.75x0.75` | Fraction of monitor width x height, e.g. `0.6x0.75` |
| `--opacity` | no | `0.96` | Window opacity |
| `--no-dim` | no | (dim on) | Disable dimming the background |
| `--label` | no | `<name> dropdown` | Description shown in `omarchy menu keybindings --print` |

## Uninstall an app

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/uninstall.sh --name tasks
```

Or remove everything this plugin registered:

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/uninstall.sh --all
```

Neither removes the plugin folder itself
(`omarchy plugin remove ryanrs.dropdown-overlay`).

## How it works

1. A window rule matches the app's window class and forces it floating,
   centered, sized to a fraction of the monitor, opened silently into a
   dedicated `special:<workspace>` workspace.
2. The keybinding runs `scripts/dropdown-toggle`, which launches the app if
   needed and dispatches `hl.dsp.workspace.toggle_special('<workspace>')`.
3. Special workspaces render over the active workspace and inherit Omarchy's
   vertical slide animation, producing the drop-down HUD effect.

## License

MIT
