# TemperatureBar

Small macOS menu-bar utility that shows CPU temperature on Apple Silicon.

## Features

- Live CPU temperature in the menu bar (e.g. `72°`)
- Click to open a popover with a 10-minute temperature chart
- Color hint: orange ≥ 80°C, red ≥ 90°C
- No Dock icon

## Requirements

- Apple Silicon Mac (M1+)
- macOS 14+
- Xcode **or** Command Line Tools

> **Note:** On some CLT-only installs, `swift build` is broken (SDK/compiler mismatch). Use `./scripts/package.sh`, which compiles with `swiftc` and a patched SDK overlay.

## Build & run

```bash
chmod +x scripts/package.sh
./scripts/package.sh
open dist/TemperatureBar.app
```

If you have a full Xcode install, this also works:

```bash
swift build -c release
```

## Notes

Temperature is read via private IOHID APIs (same approach as Stats / btop). Intended for personal use — not App Store distribution.
