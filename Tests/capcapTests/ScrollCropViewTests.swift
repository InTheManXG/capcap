import AppKit
import XCTest
@testable import capcap

@MainActor
final class ScrollCropViewTests: XCTestCase {
    func testDraggedRetinaEdgesProducePixelAlignedBottomOriginCrop() throws {
        _ = NSApplication.shared
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 200,
            pixelsHigh: 400,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        bitmap.size = NSSize(width: 100, height: 200)
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 1000, height: 1000), image: image)
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        defer { window.orderOut(nil) }
        XCTAssertEqual(view.cropRect, NSRect(x: 0, y: 0, width: 100, height: 200))

        // 图像在此宽裕画布中以原尺寸居中，上下边为 400 和 600
        drag(view, from: NSPoint(x: 500, y: 400), to: NSPoint(x: 500, y: 425.3), window: window)
        drag(view, from: NSPoint(x: 500, y: 600), to: NSPoint(x: 500, y: 550.3), window: window)

        XCTAssertEqual(view.cropRect, NSRect(x: 0, y: 49.5, width: 100, height: 125))
    }

    private func drag(_ view: ScrollCropView, from start: NSPoint, to end: NSPoint, window: NSWindow) {
        func event(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(
                with: type,
                location: view.convert(point, to: nil),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )!
        }
        view.mouseDown(with: event(.leftMouseDown, at: start))
        view.mouseDragged(with: event(.leftMouseDragged, at: end))
        view.mouseUp(with: event(.leftMouseUp, at: end))
    }
}
