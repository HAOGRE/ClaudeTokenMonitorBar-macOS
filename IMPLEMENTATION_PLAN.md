# 实施计划

根据您的反馈更新 ClaudeTokenMonitorBar-macOS 应用程序。更新内容包括：
1. 调研 `Maciek-roboblog/Claude-Code-Usage-Monitor` 项目，评估是否有可集成的新指标。
2. 移除手动切换主题按钮，改为自动跟随系统设置（深色/浅色模式）。
3. 将截图（相机）图标更改为分享图标，点击功能保持一致。
4. 在设置中移除手动语言切换功能，改为自动跟随系统语言。

## 需要您的审查
请审阅下方关于指标的调研结果及建议的UI更改。如果一切无误，请批准此计划，以便我开始执行。

## 调研结果：指标集成
在审查了 `Maciek-roboblog/Claude-Code-Usage-Monitor` (v4.0.0) 项目后，我发现我们的 `ClaudeTokenMonitorBar-macOS` 已经非常完善，几乎集成了他们所有的指标，甚至还包含了一些他们没有的指标：
- **Token 使用量：** 我们跟踪了输入(Input)、输出(Output)、缓存创建(Cache Creation)和缓存读取(Cache Read)。
- **消息/会话使用量：** 我们跟踪了 `requests`（消息请求数）和 `sessions`（会话数）。
- **成本分析：** 我们使用了 `ModelPricing` 基于 Anthropic 的定价进行准确的成本计算。
- **官方速率限制：** 我们已经通过 `V4StateProtocol` 实现了 V4 官方速率限制跟踪。
- **高级跟踪：** 我们还跟踪了 MCP 工具调用和 Skill 调用，这些是我们生态系统特有的。

**结论：** Python 版本的工具主要侧重于“预测”（基于消耗速率预测何时会触及 5 小时的限制）。虽然我们有计算每秒 Token 数（`tokenRate`），但我们并没有在 UI 中显式地展示“距离触及限制的倒计时”。
鉴于我们的 UI 已经非常丰富且全面，我建议我们**暂时不要**从 Python 工具中添加新的指标，因为我们在数据收集上已经与之齐平甚至超越。如果您特别希望添加“距离触及限制的倒计时(burn rate)”功能，请告诉我，否则我将继续执行而不添加新指标。

## 提议的更改

---

### UI 和设置重构
更新 UI 组件以满足有关主题、图标和语言设置的新需求。

#### [修改] [StatusBarView.swift](file:///Users/haogre/github/ClaudeTokenMonitorBar-macOS/ClaudeMonitor/ClaudeMonitor/StatusBarView.swift)
- 移除 `@AppStorage("tokenscopeThemeMode")` 属性及相关的主题覆盖逻辑。
- 让 `theme` 和 `effectiveColorScheme` 直接依赖 `@Environment(\.colorScheme)` 自动跟随系统。
- 从头部区域移除 `sun.max`/`moon.fill` 主题切换按钮。
- 将 `copyPanelSnapshot` 按钮的 `camera`（相机）图标更改为 `square.and.arrow.up`（分享图标）。

#### [修改] [SettingsView.swift](file:///Users/haogre/github/ClaudeTokenMonitorBar-macOS/ClaudeMonitor/ClaudeMonitor/SettingsView.swift)
- 移除“语言 / Language”区域标题及允许手动选择语言的 `Picker` 组件。

#### [修改] [AppSettings.swift](file:///Users/haogre/github/ClaudeTokenMonitorBar-macOS/ClaudeMonitor/ClaudeMonitor/AppSettings.swift)
- 调整 `language` 属性默认动态获取系统语言，或者如果应用的 `Localization` 可以自动检测系统语言，则直接移除对语言的 AppStorage 持久化存储。

#### [修改] [Localization.swift](file:///Users/haogre/github/ClaudeTokenMonitorBar-macOS/ClaudeMonitor/ClaudeMonitor/Localization.swift)
- 调整本地化逻辑，使其回退使用系统语言（`Locale.current.language.languageCode`），不再依赖用户手动选择的配置（如果需要的话）。

## 验证计划
### 自动化测试
- 运行 Xcode build 确保应用编译无误。
### 手动验证
- 运行应用并验证主题是否自动匹配 macOS 系统设置。
- 检查头部区域是否已没有主题切换按钮。
- 检查截图按钮是否使用了分享图标，并且仍然可以成功将图片复制到剪贴板。
- 打开“设置”，验证语言切换功能是否已被移除。
- 验证应用启动时是否使用了正确的系统语言。
