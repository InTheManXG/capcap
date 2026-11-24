import AppKit
import XCTest
@testable import capcap

@MainActor
final class ScrollCropViewTests: XCTestCase {
    func testTransparentRetinaCropAlignsToSourcePixels() throws {
        _ = NSApplication.shared
        let image = try makeImage()
        let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 100, height: 200), image: image)
        let window = makeWindow(for: view)
        defer { window.orderOut(nil) }
        XCTAssertFalse(view.isOpaque)
        XCTAssertFalse(view.isFlipped)
        XCTAssertEqual(view.cropRect, NSRect(x: 0, y: 0, width: 100, height: 200))

        drag(view, from: NSPoint(x: 50, y: 0), to: NSPoint(x: 50, y: 49.7), window: window)
        drag(view, from: NSPoint(x: 50, y: 200), to: NSPoint(x: 50, y: 174.7), window: window)

        XCTAssertEqual(view.cropRect, NSRect(x: 0, y: 49.5, width: 100, height: 125))
    }

    func testRotatedCropUsesRotatedDimensionsAndPixels() throws {
        _ = NSApplication.shared
        let view = ScrollCropView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 200),
            image: try makeImage(),
            rotation: .left
        )
        let window = makeWindow(for: view)
        defer { window.orderOut(nil) }
        XCTAssertEqual(view.cropRect, NSRect(x: 0, y: 0, width: 200, height: 100))

        drag(view, from: NSPoint(x: 200, y: 0), to: NSPoint(x: 200, y: 50.7), window: window)
        drag(view, from: NSPoint(x: 200, y: 200), to: NSPoint(x: 200, y: 150.7), window: window)

        XCTAssertEqual(view.cropRect, NSRect(x: 0, y: 25.5, width: 200, height: 50))
    }

    func testResizingOverlayPreservesCropAndTinyImagesKeepValidRange() throws {
        _ = NSApplication.shared
        let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 100, height: 200), image: try makeImage())
        let window = makeWindow(for: view)
        defer { window.orderOut(nil) }
        drag(view, from: NSPoint(x: 50, y: 0), to: NSPoint(x: 50, y: 50), window: window)
        drag(view, from: NSPoint(x: 50, y: 200), to: NSPoint(x: 50, y: 150), window: window)
        let crop = view.cropRect

        view.setFrameSize(NSSize(width: 50, height: 400))
        XCTAssertEqual(view.cropRect, crop)
        view.setFrameSize(NSSize(width: 50, height: 5))
        drag(view, from: NSPoint(x: 25, y: 3.75), to: NSPoint(x: 25, y: -20), window: window)
        XCTAssertGreaterThan(view.cropRect.height, 0)
        XCTAssertGreaterThanOrEqual(view.cropRect.minY, 0)
        XCTAssertLessThanOrEqual(view.cropRect.maxY, 200)
    }

    private func makeImage() throws -> NSImage {
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
        return image
    }

    private func makeWindow(for view: NSView) -> NSWindow {
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        return window
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
