import re

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "r") as f:
    content = f.read()

# Fix dynamic(light: String, dark: String)
content = content.replace(
    "return Color(hex: isDark ? dark : light) ?? .black",
    "return Color(nsColor: NSColor(hex: isDark ? dark : light) ?? .black)"
)

# Add grid levels to Theme
grid_levels = """    var segOffText: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.55)) }
    
    var gridEmpty: Color { dynamic(light: "#e5e7eb", dark: "#374151") }
    var gridLevel1: Color { dynamic(light: "#d1fae5", dark: "#064e3b") }
    var gridLevel2: Color { dynamic(light: "#6ee7b7", dark: "#047857") }
    var gridLevel3: Color { dynamic(light: "#34d399", dark: "#10b981") }
    var gridLevel4: Color { dynamic(light: "#10b981", dark: "#34d399") }"""

content = content.replace(
    "    var segOffText: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.55)) }",
    grid_levels
)

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "w") as f:
    f.write(content)
