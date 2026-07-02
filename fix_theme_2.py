import re

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "r") as f:
    content = f.read()

# For StatusBarView
content = content.replace(
    "@Environment(\\.colorScheme) private var colorScheme",
    "@Environment(\\.colorScheme) private var colorScheme\n    var theme: Theme { Theme(isDark: colorScheme == .dark) }"
)

# For TrendCard
content = content.replace(
    "struct TrendCard: View {",
    "struct TrendCard: View {\n    @Environment(\\.colorScheme) private var colorScheme\n    var theme: Theme { Theme(isDark: colorScheme == .dark) }"
)

# For StatItem
content = content.replace(
    "struct StatItem: View {",
    "struct StatItem: View {\n    @Environment(\\.colorScheme) private var colorScheme\n    var theme: Theme { Theme(isDark: colorScheme == .dark) }"
)

# For SparklineView
content = content.replace(
    "private struct SparklineView: View {",
    "private struct SparklineView: View {\n    @Environment(\\.colorScheme) private var colorScheme\n    var theme: Theme { Theme(isDark: colorScheme == .dark) }"
)

with open("ClaudeMonitor/ClaudeMonitor/StatusBarView.swift", "w") as f:
    f.write(content)

print("Added theme property to views")
