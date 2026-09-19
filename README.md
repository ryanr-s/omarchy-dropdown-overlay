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

```bash
~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
  --name hermes --key "SUPER + SHIFT + H" --class Hermes \
  --launch /usr/bin/hermes-desktop

~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
  --name tasks --key "SUPER + SHIFT + T" \
  --class '^chrome-cloud\.ryansaito\.com__apps_tasks_collections_week-Default$' \
  --launch 'omarchy-launch-webapp https://cloud.ryansaito.com/apps/tasks/collections/week' \
  --size 0.6x0.75
```

`install.sh` writes clearly marked, idempotent blocks into
`~/.config/hypr/hyprland.lua` (window rule) and `~/.config/hypr/bindings.lua`
(keybinding) for that `--name`, then reloads Hyprland and validates the
config. Re-running with the same `--name` replaces just that app's blocks.

### Options

| Flag | Required | Default | Meaning |
|------|----------|---------|---------|
| `--name` | yes | — | Slug identifying this overlay; also used as the default special-workspace name |
| `--key` | yes | — | Keybinding, e.g. `"SUPER + SHIFT + X"` |
| `--class` | yes | — | Window class (or Lua-pattern regex) to match |
| `--launch` | yes | — | Shell command to launch the app if it isn't running |
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
