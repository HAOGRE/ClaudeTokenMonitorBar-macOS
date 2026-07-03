# v1.3.0 发布交接（进行中）

最后更新：2026-07-03 16:40 GMT+8。**中断后从「剩余步骤」第 1 步继续即可。**

## 本次发布内容

- feat: 面板毛玻璃背景（NSVisualEffectView .menu 材质，与系统菜单一致）
- perf: 轮询 CPU 优化（活跃期尖峰 13%→4-5%，内存抖动消除）
- 进程显示名改为 ClaudeTokenMonitorBar（原 "Claude Token Monitor"）
- **首个签名+公证版本**（Developer ID: hao zhang FB5Z8HKV28）

## 已完成 ✅

| 步骤 | 状态 |
|---|---|
| 版本号 1.3.0 / build 10（pbxproj，未提交） | ✅ |
| Release 构建 + Developer ID 签名（hardened runtime + timestamp） | ✅ |
| app 公证 Accepted（提交 ID `7753aead-0feb-49c3-8535-be33668f5c9a`）+ 已装订 | ✅ |
| `spctl -a` 验证 = "Notarized Developer ID" | ✅ |
| DMG 已创建并签名 | ✅ |
| DMG 公证已提交，**等待中**（提交 ID `184383eb-b7b8-44c4-a6ed-97b9bd8faa5b`） | ⏳ |
| README.md / README.zh.md 更新到 1.3.0、删除 Gatekeeper 教程（未提交） | ✅ |

关键产物（都在磁盘上，重启不丢）：
- DMG：`ClaudeMonitor/DerivedData/Build/Products/Release/ClaudeTokenMonitorBar-v1.3.0.dmg`
- 已装订的 app：同目录 `ClaudeTokenMonitorBar.app`（**不要 xcodebuild clean**，否则要重签重新公证）
- notarytool 凭据：keychain profile `CTMB_NOTARY`（Apple ID 不写在此处，见本地钥匙串该档案）

## 剩余步骤（按顺序执行）

```bash
cd /Users/haogre/github/ClaudeTokenMonitorBar-macOS/ClaudeMonitor/DerivedData/Build/Products/Release

# 1. 查公证结果（status 须为 Accepted；Invalid 则用 notarytool log 查原因）
xcrun notarytool info 184383eb-b7b8-44c4-a6ed-97b9bd8faa5b --keychain-profile CTMB_NOTARY

# 2. 装订 DMG 并验证
xcrun stapler staple ClaudeTokenMonitorBar-v1.3.0.dmg
spctl -a -vv -t open --context context:primary-signature ClaudeTokenMonitorBar-v1.3.0.dmg   # 应输出 accepted / Notarized Developer ID

# 3. 记下 sha256（第 5 步 tap 要用）
shasum -a 256 ClaudeTokenMonitorBar-v1.3.0.dmg

# 4. 发布 GitHub Release（在仓库根目录执行）
cd /Users/haogre/github/ClaudeTokenMonitorBar-macOS
gh release create v1.3.0 \
  --title "v1.3.0 - Signed & Notarized, Vibrancy UI, Performance" \
  --notes "## What's New

### ✅ Signed & Notarized by Apple
First notarized release — no more Gatekeeper warnings on first launch.

### New Features
- Panel now uses system-menu vibrancy (translucent blur), matching native macOS menus
- Process name now displays as ClaudeTokenMonitorBar

### Performance
- Refresh-tick CPU spikes cut from ~13% to ~4-5% during active Claude sessions
- Eliminated ~100MB transient memory churn per refresh
- Near-zero CPU when idle (snapshot cache)

### Install
\`\`\`bash
brew tap haogre/tap && brew install --cask claude-token-monitor-bar
\`\`\`

**Full Changelog**: https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/compare/v1.2.1...v1.3.0"
gh release upload v1.3.0 ClaudeMonitor/DerivedData/Build/Products/Release/ClaudeTokenMonitorBar-v1.3.0.dmg

# 5. 更新 Homebrew tap（本地 tap 位置即克隆，直接改推即可）
cd /opt/homebrew/Library/Taps/haogre/homebrew-tap
sed -i '' 's/version "1.2.1"/version "1.3.0"/; s/sha256 ".*"/sha256 "<第3步的sha256>"/' Casks/claude-token-monitor-bar.rb
# 同时删掉 README.md 里 --no-quarantine 那段（app 已公证，不需要了）
brew style haogre/tap && git add -A && git commit -m "claude-token-monitor-bar 1.3.0 (signed & notarized)" && git push

# 6. 验证 brew 全流程
brew update && brew reinstall --cask haogre/tap/claude-token-monitor-bar --appdir=$(mktemp -d)

# 7. 提交主仓变更（pbxproj 版本号+显示名、两个 README、本文件）并推送
cd /Users/haogre/github/ClaudeTokenMonitorBar-macOS
git add -A && git commit -m "release: v1.3.0 — signed & notarized, display name, docs" && git push origin main

# 8.（可选）官方 homebrew/cask PR #273009：公证问题已解决，
#    但知名度门槛（≥225 star）仍未达标，达标后向分支推新 sha256 重跑 CI 即可
```

## 参考

- 签名/公证完整流程与凭据说明：BREW_HANDOFF.md + 记忆文件 notarization-setup
- 公证不用重新排队：已 Accepted 的提交永久有效，装订可在任何时候补做
