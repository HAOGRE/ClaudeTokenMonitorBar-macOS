# v1.3.0 发布交接

**状态：✅ 已全部完成（2026-07-04）**，本文档留作下次发版的流程参考。

## 发布内容

- feat: 面板毛玻璃背景（NSVisualEffectView .menu 材质，与系统菜单一致）
- perf: 轮询 CPU 优化（活跃期尖峰 13%→4-5%，内存抖动消除）
- 进程显示名改为 ClaudeTokenMonitorBar（原 "Claude Token Monitor"）
- **首个签名+公证版本**（Developer ID: hao zhang FB5Z8HKV28）

## 结果记录

| 项 | 值 |
|---|---|
| Release | https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/tag/v1.3.0 |
| DMG sha256 | `4cb816d81019f9cd94d9acd5e25cb91736e5ae7f5be080691e273c113aef391b` |
| app 公证 | `7753aead-0feb-49c3-8535-be33668f5c9a` Accepted，已装订 |
| DMG 公证 | `b97af825-81b2-491f-9924-70b9bf91e50f` Accepted，已装订（首次提交 `184383eb...` 在 Apple 队列卡死 16h+，重新提交 2 分钟通过——**卡超过 1 小时就直接重交**） |
| spctl 验证 | app 与 DMG 均 "Notarized Developer ID" |
| Homebrew tap | haogre/tap 已更新 1.3.0，`brew reinstall` 端到端验证通过 |

## 下次发版流程（vX.Y.Z）

```bash
# 1. 升版本（pbxproj: MARKETING_VERSION / CURRENT_PROJECT_VERSION）
# 2. 构建 + 签名
cd ClaudeMonitor
xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -configuration Release \
  -destination 'platform=macOS' -derivedDataPath './DerivedData' build
cd DerivedData/Build/Products/Release
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: hao zhang (FB5Z8HKV28)" ClaudeTokenMonitorBar.app

# 3. 公证 app + 装订（凭据：keychain profile CTMB_NOTARY，Apple ID 见本地钥匙串）
ditto -c -k --keepParent ClaudeTokenMonitorBar.app app.zip
xcrun notarytool submit app.zip --keychain-profile CTMB_NOTARY --wait && rm app.zip
xcrun stapler staple ClaudeTokenMonitorBar.app

# 4. DMG：打包 → 签名 → 公证 → 装订
hdiutil create -volname "ClaudeTokenMonitorBar" -srcfolder ClaudeTokenMonitorBar.app \
  -ov -format UDZO ClaudeTokenMonitorBar-vX.Y.Z.dmg
codesign --force --timestamp --sign "Developer ID Application: hao zhang (FB5Z8HKV28)" ClaudeTokenMonitorBar-vX.Y.Z.dmg
xcrun notarytool submit ClaudeTokenMonitorBar-vX.Y.Z.dmg --keychain-profile CTMB_NOTARY --wait
xcrun stapler staple ClaudeTokenMonitorBar-vX.Y.Z.dmg
spctl -a -vv -t exec ClaudeTokenMonitorBar.app          # 应输出 Notarized Developer ID
shasum -a 256 ClaudeTokenMonitorBar-vX.Y.Z.dmg

# 5. gh release create vX.Y.Z + upload DMG
# 6. 更新 tap：/opt/homebrew/Library/Taps/haogre/homebrew-tap 里改 version + sha256，commit & push
# 7. README 版本徽章、下载文件名同步更新
```

## 官方 homebrew/cask（遗留）

PR [#273009](https://github.com/Homebrew/homebrew-cask/pull/273009) 仍开着。公证要求已满足，
仅剩知名度门槛（≥225 star 或 ≥90 fork/watch）。达标后向分支 `HAOGRE:add-claude-token-monitor-bar-1-2-1`
推新版本 cask（更新 version/sha256）重跑 CI 即可。
