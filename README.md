# AI Notch Bar

A macOS menu bar app that turns your MacBook's notch into a smart AI status hub. Get visual and audio feedback when your AI coding assistant (Claude Code, Copilot, Cursor, etc.) is working, waiting for input, or done.

## Features

- **AI Status Monitoring** — Watch your AI assistant's status right in the notch area
  - Claude Code support (via lock file monitoring)
  - Extensible provider system for other AI tools
- **Dynamic Island Style** — Smooth animations inspired by iPhone's Dynamic Island
- **Conflict-Aware** — Detects other notch apps (boring.notch, NotchDrop) and adapts
- **Music Integration** — (Planned) Now Playing controls alongside AI status
- **CLI Tool** — Trigger notifications from any script or tool
- **Sound Alerts** — Audio feedback when AI needs your attention

## Requirements

- macOS 13 (Ventura) or later
- MacBook with notch (falls back to floating popup on non-notch Macs)
- Swift 5.9+

## Building

```bash
swift build
swift run NotchHub
```

## Architecture

```
NotchHub.app
├── Core/           # Window management, screen detection
├── Protocols/      # NotchProvider plugin system
├── Providers/      # AI tool integrations (Claude, etc.)
├── Views/          # SwiftUI views (Dynamic Island style)
├── Audio/          # Sound effects
└── CLI/            # Command-line notification tool
```

### Provider System

AI Notch Bar uses a plugin-based architecture. Each AI tool integration is a "Provider" that implements the `NotchProvider` protocol:

```swift
protocol NotchProvider: ObservableObject {
  var id: String { get }
  var name: String { get }
  var priority: ProviderPriority { get }
  var state: ProviderState { get }

  func compactView() -> AnyView
  func expandedView() -> AnyView
  func onActivate()
}
```

### Adding a New AI Provider

1. Create a class conforming to `NotchProvider`
2. Implement status detection for your AI tool
3. Register it in `NotchHubManager`

## Supported AI Tools

| Tool | Status | Detection Method |
|------|--------|------------------|
| Claude Code | In Progress | `~/.claude/ide/*.lock` file monitoring |
| GitHub Copilot | Planned | TBD |
| Cursor AI | Planned | TBD |
| Windsurf | Planned | TBD |

## License

MIT
