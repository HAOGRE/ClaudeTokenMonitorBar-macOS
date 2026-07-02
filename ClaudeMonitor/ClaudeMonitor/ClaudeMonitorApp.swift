//
//  ClaudeTokenMonitorApp.swift
//  ClaudeTokenMonitor
//

import AppKit
import SwiftUI

@main
struct ClaudeTokenMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = MonitoringViewModel()

    var body: some Scene {
        MenuBarExtra {
            StatusBarView()
                .environment(viewModel)
        } label: {
            MenuBarLabel()
                .environment(viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDock = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? false
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)

        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if isSandboxed && !BookmarkManager.shared.hasBookmark {
            BookmarkManager.shared.requestAccess()
        }
    }
}

// MARK: - 菜单栏图标

private struct MenuBarLabel: View {
    @Environment(MonitoringViewModel.self) private var viewModel

    var body: some View {
        let rate = viewModel.tokenRate
        if rate.hasActivity {
            let rate1 = MonitoringViewModel.formatRate(rate.inputPerSec)
            let rate2 = MonitoringViewModel.formatRate(rate.outputPerSec)
            Image(nsImage: makeMenuBarImage(rate1: rate1, rate2: rate2))
                .accessibilityLabel("↑\(rate1.value) \(rate1.unit) ↓\(rate2.value) \(rate2.unit)")
        } else {
            // 空闲时显示今日成本，避免长期挂着 0 T/s
            let cost = MonitoringViewModel.formatCost(viewModel.monitoringData.dashboard.day.metrics.cost)
            Image(nsImage: makeCostImage(cost: cost))
                .accessibilityLabel(cost)
        }
    }
}

// MARK: - NSImage 缓存（避免显示字符串未变时重复绘制）

private enum ImageCache {
    static var costKey: String = ""
    static var costImage: NSImage?
    static var rateKey: String = ""
    static var rateImage: NSImage?
}

// MARK: - NSImage 绘制（无活动时：单行总成本）

private func makeCostImage(cost: String) -> NSImage {
    if cost == ImageCache.costKey, let cached = ImageCache.costImage { return cached }
    let H: CGFloat = 22
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.labelColor
    ]
    let textSize = (cost as NSString).size(withAttributes: attrs)
    let W = max(58, ceil(textSize.width) + 8)
    let startX = floor((W - textSize.width) / 2)   // 水平居中
    let startY = floor((H - textSize.height) / 2)   // 垂直居中

    let image = NSImage(size: NSSize(width: W, height: H), flipped: true) { _ in
        (cost as NSString).draw(
            at: NSPoint(x: startX, y: startY),
            withAttributes: attrs
        )
        return true
    }
    image.isTemplate = true
    ImageCache.costKey = cost
    ImageCache.costImage = image
    return image
}

// MARK: - NSImage 绘制（仿 iStat Menus 双行速率）
//
// 布局：
//   ↗  [右对齐速率]     ← 上行：输入
//   ↙  [右对齐速率]     ← 下行：输出
//
//   箭头左对齐，数字右对齐，两行间距极紧凑（参考 iStats）

private func makeMenuBarImage(rate1: (value: String, unit: String), rate2: (value: String, unit: String)) -> NSImage {
    let key = "\(rate1.value)|\(rate1.unit)|\(rate2.value)|\(rate2.unit)"
    if key == ImageCache.rateKey, let cached = ImageCache.rateImage { return cached }

    let H: CGFloat    = 22   // 状态栏固定高度
    let minW: CGFloat = 58   // 固定最小宽度，避免速率为 0 时图标过窄

    // 数字：SF Mono 9pt medium（加粗版）
    let numFont   = NSFont(name: "SFMono-Medium", size: 9) ?? NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
    // 箭头：同字号，medium 字重
    let arrowFont = NSFont.systemFont(ofSize: 9, weight: .medium)

    let arrowAttrs: [NSAttributedString.Key: Any] = [
        .font: arrowFont,
        .foregroundColor: NSColor.textColor
    ]
    let numAttrs: [NSAttributedString.Key: Any] = [
        .font: numFont,
        .foregroundColor: NSColor.textColor
    ]

    let arrow1 = "↗" as NSString
    let arrow2 = "↙" as NSString

    let a1Size = arrow1.size(withAttributes: arrowAttrs)
    let v1Size = (rate1.value as NSString).size(withAttributes: numAttrs)
    let v2Size = (rate2.value as NSString).size(withAttributes: numAttrs)
    let u1Size = (rate1.unit as NSString).size(withAttributes: numAttrs)
    let u2Size = (rate2.unit as NSString).size(withAttributes: numAttrs)

    // glyphH：控制箭头行间距（用户调好的值，保持不动）
    let glyphH    = ceil(numFont.capHeight - 3)
    // textLineH：数字的实际渲染行高，用于定位数字 Y 坐标（保证不截断）
    let textLineH = ceil(v1Size.height - 2)
    let arrowW = ceil(a1Size.width)
    // 三列布局：数字列右对齐 + 单位列右对齐（Kt/s 与 t/s 的 t/s 上下对齐）
    let valueW = ceil(max(v1Size.width, v2Size.width))
    let unitW  = ceil(max(u1Size.width, u2Size.width))
    let colGap: CGFloat = 3   // 数字列与单位列间距

    let rowGap: CGFloat = 1
    // 箭头两行总高（决定箭头垂直位置）
    let arrowTotalH = glyphH * 2 + rowGap
    // 数字两行总高（用实际行高，保证完整显示）
    let textTotalH  = textLineH * 2 + rowGap

    // 图像总宽：不低于 minW
    let W = max(minW, arrowW + 2 + valueW + colGap + unitW)
    // 数字列右缘（单位列右缘即 W）
    let valueRight = W - unitW - colGap

    // 箭头块、数字块各自独立垂直居中，互不影响
    let arrowStartY = floor((H - arrowTotalH) / 2)
    let textStartY  = floor((H - textTotalH)  / 2)

    let image = NSImage(size: NSSize(width: W, height: H), flipped: true) { _ in
        // ── 行 1：↗ 输入速率 ──────────────────────────────────
        let arrowOff = floor((glyphH - a1Size.height) / 2)
        arrow1.draw(at: NSPoint(x: 0, y: arrowStartY + arrowOff), withAttributes: arrowAttrs)
        (rate1.value as NSString).draw(
            at: NSPoint(x: valueRight - v1Size.width, y: textStartY),
            withAttributes: numAttrs
        )
        (rate1.unit as NSString).draw(
            at: NSPoint(x: W - u1Size.width, y: textStartY),
            withAttributes: numAttrs
        )

        // ── 行 2：↙ 输出速率 ──────────────────────────────────
        let arrowRow2Y = arrowStartY + glyphH + rowGap
        let textRow2Y  = textStartY  + textLineH + rowGap
        arrow2.draw(at: NSPoint(x: 0, y: arrowRow2Y + arrowOff), withAttributes: arrowAttrs)
        (rate2.value as NSString).draw(
            at: NSPoint(x: valueRight - v2Size.width, y: textRow2Y),
            withAttributes: numAttrs
        )
        (rate2.unit as NSString).draw(
            at: NSPoint(x: W - u2Size.width, y: textRow2Y),
            withAttributes: numAttrs
        )

        return true
    }
    image.isTemplate = true
    ImageCache.rateKey = key
    ImageCache.rateImage = image
    return image
}
