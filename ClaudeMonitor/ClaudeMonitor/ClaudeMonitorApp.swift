//
//  ClaudeTokenMonitorBarApp.swift
//  ClaudeTokenMonitorBar
//

import AppKit
import SwiftUI

@main
struct ClaudeTokenMonitorBarApp: App {
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

// MARK: - 菜单栏图标

private struct MenuBarLabel: View {
    @Environment(MonitoringViewModel.self) private var viewModel

    var body: some View {
        let rate = viewModel.tokenRate
        if rate.hasActivity {
            // 有活动：双行速率
            let rate1 = MonitoringViewModel.formatRate(rate.inputPerSec)
            let rate2 = MonitoringViewModel.formatRate(rate.outputPerSec)
            Image(nsImage: makeMenuBarImage(rate1: rate1, rate2: rate2))
        } else {
            // 无活动：单行显示总成本
            let cost = MonitoringViewModel.formatCost(viewModel.monitoringData.totalCost)
            Image(nsImage: makeCostImage(cost: cost))
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

private func makeMenuBarImage(rate1: String, rate2: String) -> NSImage {
    let key = "\(rate1)|\(rate2)"
    if key == ImageCache.rateKey, let cached = ImageCache.rateImage { return cached }

    let H: CGFloat    = 22   // 状态栏固定高度
    let minW: CGFloat = 58   // 固定最小宽度，避免速率为 0 时图标过窄

    // 数字：等宽、medium 字重
    let numFont   = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
    // 箭头：同字号，保持视觉统一
    let arrowFont = NSFont.systemFont(ofSize: 10, weight: .medium)

    let arrowAttrs: [NSAttributedString.Key: Any] = [
        .font: arrowFont,
        .foregroundColor: NSColor.labelColor
    ]
    let numAttrs: [NSAttributedString.Key: Any] = [
        .font: numFont,
        .foregroundColor: NSColor.labelColor
    ]

    let arrow1 = "↗" as NSString
    let arrow2 = "↙" as NSString

    let a1Size = arrow1.size(withAttributes: arrowAttrs)
    let r1Size = (rate1 as NSString).size(withAttributes: numAttrs)
    let r2Size = (rate2 as NSString).size(withAttributes: numAttrs)

    // glyphH：控制箭头行间距（用户调好的值，保持不动）
    let glyphH    = ceil(numFont.capHeight - 3)
    // textLineH：数字的实际渲染行高，用于定位数字 Y 坐标（保证不截断）
    let textLineH = ceil(r1Size.height - 2)
    let arrowW = ceil(a1Size.width)
    let textW  = ceil(max(r1Size.width, r2Size.width))

    let rowGap: CGFloat = 1
    // 箭头两行总高（决定箭头垂直位置）
    let arrowTotalH = glyphH * 2 + rowGap
    // 数字两行总高（用实际行高，保证完整显示）
    let textTotalH  = textLineH * 2 + rowGap

    // 图像总宽：不低于 minW
    let W = max(minW, arrowW + 2 + textW)

    // 箭头块、数字块各自独立垂直居中，互不影响
    let arrowStartY = floor((H - arrowTotalH) / 2)
    let textStartY  = floor((H - textTotalH)  / 2)

    let image = NSImage(size: NSSize(width: W, height: H), flipped: true) { _ in
        // ── 行 1：↗ 输入速率 ──────────────────────────────────
        let arrowOff = floor((glyphH - a1Size.height) / 2)
        arrow1.draw(at: NSPoint(x: 0, y: arrowStartY + arrowOff), withAttributes: arrowAttrs)
        // 数字：右对齐，Y 坐标基于 textStartY（完整显示，不截断）
        (rate1 as NSString).draw(
            at: NSPoint(x: W - r1Size.width, y: textStartY),
            withAttributes: numAttrs
        )

        // ── 行 2：↙ 输出速率 ──────────────────────────────────
        let arrowRow2Y = arrowStartY + glyphH + rowGap
        let textRow2Y  = textStartY  + textLineH + rowGap
        arrow2.draw(at: NSPoint(x: 0, y: arrowRow2Y + arrowOff), withAttributes: arrowAttrs)
        (rate2 as NSString).draw(
            at: NSPoint(x: W - r2Size.width, y: textRow2Y),
            withAttributes: numAttrs
        )

        return true
    }
    image.isTemplate = true
    ImageCache.rateKey = key
    ImageCache.rateImage = image
    return image
}
