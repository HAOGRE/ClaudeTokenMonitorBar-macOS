# ClaudeTokenMonitorBar 项目规范

本文档记录 ClaudeTokenMonitorBar 项目的开发、构建和发布规范。

---

## 1. 添加新模型支持

当 Anthropic 发布新 Claude 模型时，按以下步骤更新：

### 1.1 查询官方定价
访问 https://platform.claude.com/docs/en/about-claude/pricing 获取最新定价：
- Input price ($/MTok)
- Output price ($/MTok)
- Cache write/creation price ($/MTok)
- Cache read price ($/MTok)

### 1.2 更新定价配置
编辑 `ClaudeMonitor/ClaudeMonitor/Backend/TokenDataReader.swift`：

```swift
// 在 pricingConfigs 数组中添加新模型配置
// 格式：(关键字, 是否前缀匹配, 定价)
// 注意：更具体的型号放在前面（前缀匹配优先）

("new-model-4-9", true, ModelPricing(input: X.0, output: Y.0, cacheCreation: Z.0, cacheRead: W.0)),
```

### 1.3 更新模型显示名称（可选）
如需自定义短名称显示，编辑 `ClaudeMonitor/ClaudeMonitor/StatusBarView.swift`：

```swift
private var shortModel: String {
    let m = entry.model.lowercased()
    // ... 现有模型判断 ...
    if m.contains("new-model") { return "shortname" }
    // ...
}
```

### 1.4 构建测试
```bash
cd ClaudeMonitor
xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' build
```

---

## 2. 版本管理规范

### 2.1 版本号格式
采用语义化版本：`MAJOR.MINOR.PATCH`

- **MAJOR**: 重大功能变更、架构重构
- **MINOR**: 新功能（如支持新模型、UI 改进）
- **PATCH**: Bug 修复、小优化

### 2.2 更新版本号
编辑 `ClaudeMonitor/ClaudeMonitor.xcodeproj/project.pbxproj`：

```bash
# 更新版本号（示例：1.0.1 → 1.1.0）
sed -i '' 's/MARKETING_VERSION = 1.0.1;/MARKETING_VERSION = 1.1.0;/g' project.pbxproj

# 更新 build 号（示例：7 → 8）
sed -i '' 's/CURRENT_PROJECT_VERSION = 7;/CURRENT_PROJECT_VERSION = 8;/g' project.pbxproj
```

### 2.3 Git 提交规范
```bash
git add -A
git commit -m "feat: 简短描述

- 详细变更点 1
- 详细变更点 2

Source: 官方文档链接

🤖 Generated with [Codex](https://openai.com/codex)"
```

---

## 3. 构建与发布流程

### 3.1 构建 GitHub 分发版本

使用 **CTMB** scheme（非 AppStore 版本）：

```bash
cd ClaudeMonitor

# 清理并构建 Release 版本
xcodebuild -project ClaudeMonitor.xcodeproj \
  -scheme CTMB \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath './DerivedData' \
  PRODUCT_NAME="ClaudeMonitor" \
  build

# 验证输出
ls DerivedData/Build/Products/Release/ClaudeMonitor.app
```

### 3.2 创建 DMG

```bash
# 创建 DMG 文件
hdiutil create -volname "ClaudeTokenMonitorBar" \
  -srcfolder "DerivedData/Build/Products/Release/ClaudeTokenMonitorBar.app" \
  -ov -format UDZO \
  "ClaudeTokenMonitorBar-v{VERSION}.dmg"

# 验证
ls -lh ClaudeTokenMonitorBar-v{VERSION}.dmg
```

**命名规范**：
- GitHub 分发：`ClaudeTokenMonitorBar-v{VERSION}.dmg`
- AppStore 版本：`ClaudeTokenMonitorBar-v{VERSION}.dmg`（由 AppStore scheme 构建）

### 3.3 推送到 GitHub

```bash
# 添加 GitHub remote（如未配置）
git remote add github git@github.com:HAOGRE/ClaudeTokenMonitorBar-macOS.git

# 推送到 main 分支
git push github main
```

### 3.4 创建 GitHub Release

```bash
# 创建 release
gh release create v{VERSION} \
  --title "v{VERSION} - 简短描述" \
  --notes "## What's New

### New Features
- 功能 1
- 功能 2

### Pricing Reference
| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| ... | ... | ... | ... | ... |

### Source
官方定价文档链接

**Full Changelog**: https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/compare/v{PREV_VERSION}...v{VERSION}"

# 上传 DMG
gh release upload v{VERSION} ClaudeTokenMonitorBar-v{VERSION}.dmg
```

---

## 4. 项目结构

```
ClaudeMonitor/
├── ClaudeMonitor.xcodeproj/     # Xcode 项目
│   └── project.pbxproj          # 版本号配置在此
├── ClaudeMonitor/
│   ├── Backend/
│   │   ├── TokenDataReader.swift    # 定价模型配置
│   │   └── MonitoringViewModel.swift
│   ├── StatusBarView.swift          # UI & 模型显示
│   └── ...
├── README.md
└── AGENTS.md                    # 本文件
```

---

## 5. 定价数据来源

**官方来源**: https://platform.claude.com/docs/en/about-claude/pricing

每次更新模型定价前，必须核实官方文档，确保数据准确。

---

## 6. 快速检查清单

发布前检查：

- [ ] 新模型定价已核实（官方文档）
- [ ] `TokenDataReader.swift` 配置已更新
- [ ] `StatusBarView.swift` 显示名称已更新（如需）
- [ ] 版本号已更新（project.pbxproj）
- [ ] Build 成功无错误
- [ ] DMG 文件命名正确（ClaudeTokenMonitorBar-vX.X.X.dmg）
- [ ] 已推送到 GitHub main 分支
- [ ] GitHub Release 已创建
- [ ] DMG 已上传到 Release

---

*最后更新: 2026-06-11*
