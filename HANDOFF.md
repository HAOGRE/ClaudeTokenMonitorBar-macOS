# Project Handoff: Tokenscope UI Redesign

## 🎯 总体目标 (Goal)
将当前 `ClaudeTokenMonitorBar-macOS` (菜单栏监控应用) 的 UI 完全 1:1 升级/复刻为 Web 项目 [Tokenscope](https://github.com/HduSy/tokenscope.git) 的现代化 UI，同时**保留并优化**原有项目最核心的功能特色（如：Mac 顶部系统托盘的实时网速显示、V4 官方速率预警等）。

---

## ✅ 已完成的工作 (What's Done)

1. **核心布局重构 (StatusBarView.swift)**
   - 抛弃了旧版的堆叠布局，采用全新的克制、现代化、圆角卡片式设计。
   - 实现了头部的 `Day | Week | Month` 仿系统级 Segmented Control 切换器。
   - 实现了 `TOTAL TOKENS` 巨石卡片（Hero Section）及动态迷你折线图（Sparkline）。

2. **核心指标与图表完美嵌入**
   - **四宫格指标卡片**：使用 2x2 网格，复刻展示了 `Cost`, `Input Tokens`, `Output Tokens`, `Cache Read`，并配以专属的圆形底色 Icon。
   - **模型分布**：完全还原了带有微型进度条的 `PROJECT CALLS` (使用模型名称和具体使用量) 列表。
   - **花费统计**：还原了左侧圆环图 (Donut Chart) + 右侧列表 (Top 5 消耗) 的经典面板。
   - **V4 官方速率限制**：将原本的 V4 Limits 完美重绘为横向进度条（包含百分比变色预警和 `Resets at` 时间显示），完美融入卡片序列。

3. **1:1 像素级复刻：Daily Activity 热力图**
   - 包含外层圆角 Border 与 Header。
   - 包含顶部的月份坐标（Jan - Jul）。
   - 还原了 7x52 的紧凑型方块矩阵，12x12 大小，间距 4。
   - 底部加入了 `Less [色阶] More` 的图例与 `Est. cost via models.dev / LiteLLM · estimate` 底部版权文字。

4. **系统级深色模式 (Robust Dark Mode)**
   - 彻底修复了 macOS `MenuBarExtra` 中 `NSColor(dynamicProvider:)` 不自动刷新的系统级 Bug。
   - 重构了 `Theme` 结构体，所有视图均主动订阅 `@Environment(\.colorScheme)`，确保浅色/深色主题的 Hex 颜色实时、完美切换。

5. **菜单栏独立实时速率显示**
   - 剔除了面板内部冗余的动态网速卡片。
   - 将 100% 精力的实时速率（`Input t/s`, `Output t/s`，附带上下箭头）全部保留并锁定在 Mac 顶部的菜单栏托盘图标上。

6. **代码编译通过**
   - 解决了一系列 Xcode (macOS 14 目标平台) 的编译警告与报错，项目当前 `Build Succeeded`。

---

## 🚧 未完成或待优化的工作 (What's Pending / To-Do)

1. **热力图月份动态化 (Dynamic Heatmap Headers)**
   - 当前热力图顶部的月份 (`Jan`, `Feb`... `Jul`) 为了保证 1:1 UI 还原度，目前是静态排布的。未来需要根据后端实际传来的时间戳数据，动态计算并渲染这些 Header。

2. **UI 模块化拆分 (Code Refactoring)**
   - 经过多次迭代，`StatusBarView.swift` 单文件已经超过 800 行。建议后续将 `HeatmapSection`、`TrendCard`、`ModelsDonutChart` 等子视图拆分到独立的 `.swift` 文件中，以提升维护性。

3. **设置项与退出按钮的位置调整**
   - 原版 Tokenscope 是一个网页，没有明确的 "Quit" 按钮。当前我们的 "Settings", "Reset", "Quit" 等系统控制按钮临时存放在了 Popover 的最底部。未来可以考虑将其整合到右上角的 Icon 或者独立的汉堡菜单中，使其更贴近原生 macOS 体验。

4. **更多交互细节**
   - 热力图小方块目前的 Hover (悬停显示具体某天 tokens 数量) 尚未用 SwiftUI 的 `.help()` 或 `Tooltip` 完整实现，可以进一步提升用户体验。

---

## 📝 开发者备注 (Notes)
- UI 修改均基于 `Tokenscope` 提供的截图与色值。
- 本地调试时，如需看数据变化，可以手动产生一些大 Tokens 的请求，观察顶部 MenuBar 以及拉开面板后的图表响应。
