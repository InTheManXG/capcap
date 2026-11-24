import AppKit

/// 覆盖当前编辑画布的透明裁剪层，图片和标注仍由下方画布绘制
final class ScrollCropView: NSView {
    private let imageSize: NSSize
    private let pixelSize: NSSize
    private var bottomFraction: CGFloat = 0
    private var topFraction: CGFloat = 1
    private enum Edge { case top, bottom }
    private var activeEdge: Edge?

    private let accent = NSColor(red: 0, green: 212.0 / 255.0, blue: 106.0 / 255.0, alpha: 1.0)
    private let edgeHitInset: CGFloat = 16

    init(frame frameRect: NSRect, image: NSImage, rotation: ImageRotation = .none) {
        imageSize = rotation.orientedSize(image.size)
        if let cgImage = image.cgImagePreservingBacking() {
            pixelSize = rotation.orientedSize(NSSize(width: cgImage.width, height: cgImage.height))
        } else {
            pixelSize = NSSize(width: max(1, imageSize.width.rounded()), height: max(1, imageSize.height.rounded()))
        }
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    /// 比例不依赖显示缩放；先对齐旋转后的实际像素，再返回左下原点逻辑坐标
    var cropRect: NSRect {
        let height = max(1, pixelSize.height)
        let bottom = min(height - 1, max(0, (bottomFraction * height).rounded()))
        let top = min(height, max(bottom + 1, (topFraction * height).rounded()))
        return NSRect(
            x: 0,
            y: bottom / height * imageSize.height,
            width: imageSize.width,
            height: (top - bottom) / height * imageSize.height
        )
    }

    private var cropBottom: CGFloat { bounds.minY + bottomFraction * bounds.height }
    private var cropTop: CGFloat { bounds.minY + topFraction * bounds.height }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        NSColor(white: 0, alpha: 0.62).setFill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: cropBottom - bounds.minY).fill()
        NSRect(x: bounds.minX, y: cropTop, width: bounds.width, height: bounds.maxY - cropTop).fill()
        drawHandle(atY: cropBottom)
        drawHandle(atY: cropTop)
    }

    private func drawHandle(atY y: CGFloat) {
        accent.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 2
        line.move(to: NSPoint(x: bounds.minX, y: y))
        line.line(to: NSPoint(x: bounds.maxX, y: y))
        line.stroke()

        let tabWidth = min(48, bounds.width)
        let tab = NSRect(x: bounds.midX - tabWidth / 2, y: y - 7, width: tabWidth, height: 14)
        accent.setFill()
        NSBezierPath(roundedRect: tab, xRadius: 7, yRadius: 7).fill()
        NSColor.white.setFill()
        for dx in [-7.0, 0.0, 7.0] {
            NSBezierPath(ovalIn: NSRect(x: tab.midX + dx - 1.5, y: tab.midY - 1.5, width: 3, height: 3)).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        activeEdge = edge(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let activeEdge, bounds.height > 0 else { return }
        // 边缘拖出可视区时滚动画布，让长图的裁剪线能继续移动
        _ = autoscroll(with: event)
        let point = convert(event.locationInWindow, from: nil)
        let fraction = (point.y - bounds.minY) / bounds.height
        // 小图不能产生倒置范围；任何缩放下至少保留一个实际图片像素
        let minimumFraction = min(1, max(1 / max(1, pixelSize.height), 12 / bounds.height))
        switch activeEdge {
        case .top:
            topFraction = min(1, max(bottomFraction + minimumFraction, fraction))
        case .bottom:
            bottomFraction = max(0, min(topFraction - minimumFraction, fraction))
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        activeEdge = nil
    }

    private func edge(at point: NSPoint) -> Edge? {
        guard point.x >= bounds.minX - edgeHitInset, point.x <= bounds.maxX + edgeHitInset else { return nil }
        let topDistance = abs(point.y - cropTop)
        let bottomDistance = abs(point.y - cropBottom)
        if topDistance <= edgeHitInset && topDistance <= bottomDistance { return .top }
        if bottomDistance <= edgeHitInset { return .bottom }
        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        (edge(at: point) != nil ? NSCursor.resizeUpDown : NSCursor.arrow).set()
    }
}
