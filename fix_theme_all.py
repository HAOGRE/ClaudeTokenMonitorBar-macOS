import re

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "r") as f:
    content = f.read()

# Replace struct TokenScopeTheme with Theme
theme_code = """struct Theme {
    let isDark: Bool

    func dynamic(light: String, dark: String) -> Color {
        return Color(hex: isDark ? dark : light) ?? .black
    }
    func dynamic(light: NSColor, dark: NSColor) -> Color {
        return Color(nsColor: isDark ? dark : light)
    }

    var bg: Color { dynamic(light: "#ffffff", dark: "#1f2226") }
    var cardBg: Color { dynamic(light: "#ffffff", dark: "#1f2226") }
    var cardBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.08), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.10)) }
    
    var primaryGreen: Color { dynamic(light: "#178a55", dark: "#27b06e") }
    var chartGreen: Color { dynamic(light: "#178a55", dark: "#27b06e") }
    var lightGreen: Color { dynamic(light: "#8fd9b4", dark: "#5fcf9c") }
    
    var textMain: Color { dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.94), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.94)) }
    var textSecondary: Color { dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.52)) }
    var separator: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.06), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)) }
    
    var segBg: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.05), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)) }
    var segBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.07), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.09)) }
    var segOnBg: Color { dynamic(light: NSColor(red: 1, green: 1, blue: 1, alpha: 1.0), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.15)) }
    var segOnText: Color { dynamic(light: "#111111", dark: "#ffffff") }
    var segOffText: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.55)) }
    
    var palette: [Color] {
        [
            chartGreen,
            lightGreen,
            dynamic(light: "#aeb8b2", dark: "#5a6660"),
            dynamic(light: "#70c39a", dark: "#40be84"),
            dynamic(light: "#a0e0c0", dark: "#7ce3b1")
        ]
    }
}"""
content = re.sub(r'struct TokenScopeTheme \{.*?\n\}', theme_code, content, flags=re.DOTALL)

# Add @Environment and theme to StatusBarView
content = content.replace(
    "@Environment(MonitoringViewModel.self) private var viewModel",
    "@Environment(MonitoringViewModel.self) private var viewModel\n    @Environment(\\.colorScheme) private var colorScheme\n    var theme: Theme { Theme(isDark: colorScheme == .dark) }"
)

# Add @Environment and theme to TrendCard, StatItem, SparklineView
for view in ["TrendCard", "StatItem", "SparklineView"]:
    content = content.replace(
        f"struct {view}: View {{",
        f"struct {view}: View {{\n    @Environment(\\.colorScheme) private var colorScheme\n    var theme: Theme {{ Theme(isDark: colorScheme == .dark) }}"
    )

content = content.replace("TokenScopeTheme.", "theme.")

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "w") as f:
    f.write(content)

print("Applied theme fixes")
