# Changelog

## 1.0.0 - 2026-10-18

- Bar widget with a popup to rotate the monitor the bar is on: Normal,
  Portrait (turned left or right), Upside down
- Current rotation highlighted; icon reflects landscape or portrait
- Keeps the monitor's mode, position and scale when rotating
- Opt-in "Remember after restart" via `~/.config/hypr/screen-rotate.lua`
- `bin/screen-rotate` helper: `list`, `get`, `set`, `setup`, `forget`
- IPC: `open` (focused monitor), `close`, `refresh`
