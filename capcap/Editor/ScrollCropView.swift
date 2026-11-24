import AppKit

/// 覆盖当前编辑画布的透明裁剪层，图片和标注仍由下方画布绘制
final class ScrollCropView: NSView {
    private let imageSize: NSSize
    private let pixelSize: NSSize
    private var cropFractions = NSRect(x: 0, y: 0, width: 1, height: 1)
    private var dragState: (handle: SelectionView.HandlePosition, rect: NSRect, point: NSPoint)?

    private let handleHitInset: CGFloat = 10

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
        dragState = nil
        needsDisplay = true
    }

    /// 比例不依赖显示缩放；四条边先对齐旋转后的实际像素，再返回逻辑坐标
    var cropRect: NSRect {
        let width = max(1, pixelSize.width)
        let height = max(1, pixelSize.height)
        let left = min(width - 1, max(0, (cropFractions.minX * width).rounded()))
        let right = min(width, max(left + 1, (cropFractions.maxX * width).rounded()))
        let bottom = min(height - 1, max(0, (cropFractions.minY * height).rounded()))
        let top = min(height, max(bottom + 1, (cropFractions.maxY * height).rounded()))
        return NSRect(
            x: left / width * imageSize.width,
            y: bottom / height * imageSize.height,
            width: (right - left) / width * imageSize.width,
            height: (top - bottom) / height * imageSize.height
        )
    }

    private var selectionRect: NSRect {
        NSRect(
            x: bounds.minX + cropFractions.minX * bounds.width,
            y: bounds.minY + cropFractions.minY * bounds.height,
            width: cropFractions.width * bounds.width,
            height: cropFractions.height * bounds.height
        )
    }

    /// 手柄外框全部位于裁剪框内，避免边缘被滚动容器裁掉；顺序沿用选区的八点枚举
    var handleRects: [NSRect] {
        let rect = selectionRect
        let size = max(0, min(SelectionView.selectionHandleSize, rect.width / 3, rect.height / 3))
        let centers = SelectionView.handlePositions(for: rect.insetBy(dx: size / 2, dy: size / 2))
        return centers.map {
            NSRect(x: $0.x - size / 2, y: $0.y - size / 2, width: size, height: size)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = selectionRect
        let mask = NSBezierPath(rect: bounds)
        mask.append(NSBezierPath(rect: rect))
        mask.windingRule = .evenOdd
        NSColor(white: 0, alpha: 0.62).setFill()
        mask.fill()

        // 沿用截图选区的实心圆点；边框内缩，避免滚动容器裁掉实线
        let inset = min(1, rect.width / 2, rect.height / 2)
        SelectionView.drawSelectionBorder(context: context, rect: rect.insetBy(dx: inset, dy: inset), dashed: false)
        SelectionView.drawSelectionHandles(context: context, rects: handleRects)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let handle = handle(at: point) else { return }
        dragState = (handle, selectionRect, point)
        SelectionView.setCursorForHandle(handle)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragState, bounds.width > 0, bounds.height > 0 else { return }
        _ = autoscroll(with: event)
        let point = convert(event.locationInWindow, from: nil)
        let delta = NSPoint(x: point.x - dragState.point.x, y: point.y - dragState.point.y)
        let original = dragState.rect
        // 内缩手柄只影响命中位置，边界始终从原框加鼠标位移，首次拖动不会跳边
        let minimumWidth = min(original.width, bounds.width, max(12, bounds.width / max(1, pixelSize.width)))
        let minimumHeight = min(original.height, bounds.height, max(12, bounds.height / max(1, pixelSize.height)))
        var left = original.minX, right = original.maxX
        var bottom = original.minY, top = original.maxY
        switch dragState.handle {
        case .topLeft, .bottomLeft, .leftCenter:
            left = max(bounds.minX, min(original.maxX - minimumWidth, original.minX + delta.x))
        case .topRight, .bottomRight, .rightCenter:
            right = min(bounds.maxX, max(original.minX + minimumWidth, original.maxX + delta.x))
        default:
            break
        }
        switch dragState.handle {
        case .bottomLeft, .bottomRight, .bottomCenter:
            bottom = max(bounds.minY, min(original.maxY - minimumHeight, original.minY + delta.y))
        case .topLeft, .topRight, .topCenter:
            top = min(bounds.maxY, max(original.minY + minimumHeight, original.maxY + delta.y))
        default:
            break
        }
        cropFractions = NSRect(
            x: (left - bounds.minX) / bounds.width,
            y: (bottom - bounds.minY) / bounds.height,
            width: (right - left) / bounds.width,
            height: (top - bottom) / bounds.height
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragState = nil
    }

    private func handle(at point: NSPoint) -> SelectionView.HandlePosition? {
        var closest: Int?
        var closestDistance = CGFloat.greatestFiniteMagnitude
        for (index, rect) in handleRects.enumerated() where rect.insetBy(dx: -handleHitInset, dy: -handleHitInset).contains(point) {
            let dx = point.x - rect.midX, dy = point.y - rect.midY
            let distance = dx * dx + dy * dy
            if distance < closestDistance {
                closest = index
                closestDistance = distance
            }
        }
        return closest.map { SelectionView.HandlePosition.allCases[$0] }
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
        if let handle = handle(at: convert(event.locationInWindow, from: nil)) {
            SelectionView.setCursorForHandle(handle)
        } else {
            NSCursor.arrow.set()
        }
    }
}
