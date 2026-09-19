import QtQuick

// This plugin works at the Hyprland level: install.sh writes a window rule and
// a keybinding per app, and scripts/dropdown-toggle puts that app into its own
// special workspace that toggles like a Quake-style drop-down HUD.
//
// The Omarchy plugin registry requires a QML entry point, so this service
// exists to satisfy the manifest. It intentionally has no UI and no logic.
//
// Add an app after installing:
//   ~/.config/omarchy/plugins/ryanrs.dropdown-overlay/install.sh \
//     --name <slug> --key "SUPER + SHIFT + X" --class "<window-class>" \
//     --launch "<launch command>"
Item {
}
