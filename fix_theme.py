import re

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "r") as f:
    content = f.read()

# Add @Environment(\.colorScheme) var colorScheme
content = content.replace("@Environment(MonitoringViewModel.self) private var viewModel", "@Environment(MonitoringViewModel.self) private var viewModel\n    @Environment(\\.colorScheme) private var colorScheme")

content = content.replace("TokenScopeTheme.", "theme.")

# Inject Theme struct at the end
theme_code = """
struct Theme {
    let isDark: Bool
    
    var primaryGreen: Color { Color(hex: "#10b981") ?? .green }
    var lightGreen: Color { Color(hex: "#34d399") ?? .green }
    var darkGreen: Color { Color(hex: "#059669") ?? .green }
    
    var bg: Color { isDark ? Color(hex: "#1f2226")! : Color(hex: "#ffffff")! }
    var cardBg: Color { isDark ? Color(hex: "#1f2226")! : Color(hex: "#ffffff")! }
    var textMain: Color { isDark ? Color(hex: "#f3f4f6")! : Color(hex: "#111827")! }
    var textSecondary: Color { isDark ? Color(hex: "#9ca3af")! : Color(hex: "#6b7280")! }
    var separator: Color { isDark ? Color(hex: "#374151")! : Color(nsColor: NSColor(white: 0.9, alpha: 1.0)) }
    
    var gridEmpty: Color { isDark ? Color(hex: "#374151")! : Color(hex: "#e5e7eb")! }
    var gridLevel1: Color { isDark ? Color(hex: "#064e3b")! : Color(hex: "#d1fae5")! }
    var gridLevel2: Color { isDark ? Color(hex: "#047857")! : Color(hex: "#6ee7b7")! }
    var gridLevel3: Color { isDark ? Color(hex: "#10b981")! : Color(hex: "#34d399")! }
    var gridLevel4: Color { isDark ? Color(hex: "#34d399")! : Color(hex: "#10b981")! }
}
"""

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "w") as f:
    f.write(content + "\n" + theme_code)

print("Replaced TokenScopeTheme with theme")
