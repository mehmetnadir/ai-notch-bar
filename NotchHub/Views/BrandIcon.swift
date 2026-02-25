import SwiftUI
import AppKit

/// Bilinen AI araç markaları
enum AIBrand: String, CaseIterable {
  case claude = "claude"
  case cursor = "cursor"
  case copilot = "copilot"
  case gemini = "gemini"
  case windsurf = "windsurf"
  case aider = "aider"
  case vscode = "vscode"
  case continueDev = "continue-dev"
  case zed = "zed"
  case openai = "openai"
  case cline = "cline"
  case supermaven = "supermaven"

  /// Marka adı (gösterim için)
  var displayName: String {
    switch self {
    case .claude: return "Claude"
    case .cursor: return "Cursor"
    case .copilot: return "Copilot"
    case .gemini: return "Gemini"
    case .windsurf: return "Windsurf"
    case .aider: return "Aider"
    case .vscode: return "VS Code"
    case .continueDev: return "Continue"
    case .zed: return "Zed"
    case .openai: return "ChatGPT"
    case .cline: return "Cline"
    case .supermaven: return "Supermaven"
    }
  }

  /// Fallback SF Symbol (SVG yüklenemezse)
  var fallbackSymbol: String {
    switch self {
    case .claude: return "sparkle"
    case .cursor: return "cursorarrow.rays"
    case .copilot: return "person.2.fill"
    case .gemini: return "sparkles"
    case .windsurf: return "wind"
    case .aider: return "terminal.fill"
    case .vscode: return "chevron.left.forwardslash.chevron.right"
    case .continueDev: return "play.fill"
    case .zed: return "bolt.fill"
    case .openai: return "brain.head.profile.fill"
    case .cline: return "chevron.left"
    case .supermaven: return "star.fill"
    }
  }

  /// Marka rengi
  var brandColor: Color {
    switch self {
    case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34) // #D97757
    case .cursor: return .purple
    case .copilot: return Color(red: 0.12, green: 0.44, blue: 0.92) // #1F6FEB
    case .gemini: return Color(red: 0.26, green: 0.52, blue: 0.96) // #4285F4
    case .windsurf: return .cyan
    case .aider: return .green
    case .vscode: return Color(red: 0, green: 0.48, blue: 0.8) // #007ACC
    case .continueDev: return .orange
    case .zed: return .blue
    case .openai: return Color(red: 0.06, green: 0.64, blue: 0.5) // #10A37F
    case .cline: return Color(red: 0.39, green: 0.4, blue: 0.95) // #6366F1
    case .supermaven: return Color(red: 0.55, green: 0.36, blue: 0.96) // #8B5CF6
    }
  }

  /// IDE adından markayı tespit et
  static func from(ideName: String) -> AIBrand? {
    let lower = ideName.lowercased()
    if lower.contains("cursor") || lower.contains("antigravity") {
      return .cursor
    }
    if lower.contains("copilot") { return .copilot }
    if lower.contains("windsurf") || lower.contains("codeium") {
      return .windsurf
    }
    if lower.contains("continue") { return .continueDev }
    if lower.contains("cline") || lower.contains("roo") { return .cline }
    if lower.contains("supermaven") { return .supermaven }
    if lower.contains("aider") { return .aider }
    if lower.contains("zed") { return .zed }
    if lower.contains("code") && !lower.contains("cursor") {
      return .vscode
    }
    return nil
  }
}

/// SVG tabanlı marka ikonu view'ı
struct BrandIcon: View {
  let brand: AIBrand
  var size: CGFloat = 16

  var body: some View {
    Group {
      if let image = loadSVG() {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
      } else {
        // Fallback: SF Symbol
        Image(systemName: brand.fallbackSymbol)
          .foregroundStyle(brand.brandColor)
      }
    }
    .frame(width: size, height: size)
  }

  private func loadSVG() -> NSImage? {
    guard let url = Bundle.module.url(
      forResource: brand.rawValue,
      withExtension: "svg",
      subdirectory: "Icons"
    ) else { return nil }
    return NSImage(contentsOf: url)
  }
}
