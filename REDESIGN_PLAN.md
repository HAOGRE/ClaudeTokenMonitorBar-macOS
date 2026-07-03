# 重新设计计划：ClaudeTokenMonitor 仿 Tokenscope 风格改造

Tokenscope 的 UI 以其精美的配色、紧凑的数据展示和直观的图表（如甜甜圈图、热力图、迷你折线图）而显得非常高级和现代。按照您的要求，我们将**使用原生 SwiftUI 1:1 完全复刻**它的视觉效果，然后再考虑后续的迭代优化。

## 1. 视觉基础 (Colors & Typography)
*   **主题配色 (Theme Colors)**: 
    *   深色模式背景 `#1f2226`，浅色模式背景 `#ffffff`。
    *   主强调色：绿色系（如暗色下的 `#27b06e`，亮色下的 `#178a55`）。
    *   次强调色 `#5fcf9c`，缓存色 `#5a6660`，以及相应的半透明辅助文本色。
*   **字体 (Typography)**: 
    *   数字和代码标识严格使用等宽字体 `.monospaced`（对应 `IBM Plex Mono` 的原生平替）。
    *   UI 文字使用系统自带无衬线体 `.system(design: .default)`。

## 2. 布局重构 (Layout Restructuring 1:1 复刻)
完全抛弃现有的 `VStack` 分隔线布局，改用 Tokenscope 的卡片式流式布局。

1.  **吸顶 Header**:
    *   左侧：自定义的 `TokenGlyph`（绿色方形阵列图标）和应用名称 "Tokenscope / ClaudeMonitor"。
    *   右侧：Segmented 时段选择器（Day / Week / Month），暗/亮主题切换图标，截图按钮。
2.  **英雄区 (Hero Section)**:
    *   左侧 **Total tokens**：大号粗体等宽数字（带动画计数），以及涨跌幅百分比（▲▼ 带红绿色块背景）。
    *   右侧 **Est. cost** 估算成本，使用带强调色的粗体数字。
3.  **分色进度条 (Input/Output Split Bar)**:
    *   一根双色无缝进度条直观展示 Input（含 Cache）与 Output 占比，下方紧接文字图例。
4.  **图表模块 (Charts) [替换原 30天趋势图]**:
    *   **弃用旧版 30天趋势图**：原有的单一 30天柱状图与新功能重叠，将被彻底移除。
    *   **Bar Chart (分段柱状图)**：支持动态切换 Day/Week/Month 的堆叠柱状图（下方颜色为 Input，上方为 Output）。
    *   **Tokens by model (条形列表)**: 1:1 还原各模型的消耗占比长条和百分比。
    *   **Cost by model (甜甜圈图)**: 右侧模型列表，左侧带中空总计数值的连续圆环图，带 Hover 焦点高亮。
5.  **数据看板 (Mini Stats)**:
    *   并排的迷你卡片：左侧显示 Requests 和 Sessions 数量，右侧显示 Cost trend 成本趋势。卡片背景带 `Sparkline` 渐变曲线图。
6.  **活动热力图 (Heatmap)**:
    *   底部的 7xN 方块阵列，带 Less/More 的五级颜色深浅图例。

## 3. 原有特色功能与模块化 (Legacy Features & Modularity)
为了不丢失 ClaudeTokenMonitor 本身的实用价值，新设计将在 Tokenscope 外观下完美融入原有特色：

1.  **实时速率监控 (Real-time RateBar)**：
    *   **位置**：放置在英雄区 (Hero Section) 和分色进度条之间。
    *   **设计**：采用 Tokenscope 的无边框微底色卡片（例如深色模式下的 `rgba(255,255,255,0.06)`），配合 `.monospaced` 字体。当有数据流时，相应的数值亮起主题色并伴随微弱的呼吸动画。
2.  **v4 官方限制状态 (v4 Limits)**：
    *   **位置**：放置在实时速率或图表区下方，作为一个精致的 Tokenscope 风格警告卡片（带小圆角进度条）。
3.  **完全的模块化管理 (Modular Toggles)**：
    *   除“30天趋势图”外，原有的 `AppSettings` 模块化开关将被 **100% 保留**。
    *   用户依然可以在设置中自由开启或关闭：项目成本区 (Project)、最近记录区 (Recent)、以及新加入的热力图 (Heatmap) 等。即使关闭某些模块，整体的流式布局依然会自适应收缩，保持美观。

## 4. 数据结构设计与变更 (Data Structure Changes)
为了能够 1:1 驱动这套新 UI，目前的 `MonitoringData` 需要大幅扩充，向 `tokenscope/src/data.ts` 的模型靠拢：

**变更 1: 引入周期性报表聚合 (PeriodReport)**
目前的 `todayCost` 和 `totalCost` 无法满足界面上 `Day | Week | Month` 的切换，需要引入新的聚合模型：
```swift
struct Metrics {
    var totalTokens: Int
    var inputTokens: Int
    var cacheTokens: Int
    var outputTokens: Int
    var cost: Double
    var requests: Int
    var sessions: Int
    var deltaTokens: Double // 涨跌幅百分比
}

struct PeriodReport {
    var metrics: Metrics
    var series: [SeriesPoint]       // 柱状图数据
    var models: [ModelStat]         // 模型消费统计（用于列表和甜甜圈图）
    var mcp: [NamedCount]           // 可选：MCP 调用统计
    var reqTrend: [Double]          // Sparkline 趋势数组
    var costTrend: [Double]         // Sparkline 趋势数组
}
```

**变更 2: 扩展 `MonitoringData`**
重构 `MonitoringData` 结构，提供界面的全量上下文：
```swift
struct MonitoringData {
    var day: PeriodReport
    var week: PeriodReport
    var month: PeriodReport
    
    // 用于底部热力图
    var heatmap: [HeatDay]
    
    var lastUpdated: Date
    var v4State: V4StateProtocol?
}

struct HeatDay {
    var date: Date
    var tokens: Int
    var level: Int // 0...4 代表颜色深浅
}

struct ModelStat: Identifiable {
    var id: String { name }
    var name: String
    var tokens: Int
    var cost: Double
    var color: Color
}

struct SeriesPoint: Identifiable {
    var id: String { label }
    var label: String
    var input: Int
    var cache: Int
    var output: Int
}
```

**变更 3: ViewModel 解析逻辑适配**
*   `MonitoringViewModel.swift` 需要读取日志数据后，根据 `Date` 过滤出今天、本周、本月的子集，并分别生成三个 `PeriodReport` 对象。
*   分配模型专属颜色（ModelStat 中的 `color`），按照成本占比排名。
*   计算 5 级深度的热力图 `level`。

## 5. 下一步行动 (Action Plan)
1.  **数据层改造**: 先修改 `MonitoringViewModel.swift` 和相关数据读取类，填充上述新数据结构。
2.  **构建核心原子 UI**: 实现原生的 `SegmentedControl`, `TokenGlyph`, `Sparkline`, `CostDonut` 和 `Heatmap` 视图组件。
3.  **组装 StatusBarView**: 使用新组件完全替换现有布局，完成 1:1 像素级复刻。

*(注：由于已经创建了新分支 `feature/ui-redesign`，我们的改动是安全的。)*
