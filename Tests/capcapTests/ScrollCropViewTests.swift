import AppKit
import XCTest
@testable import capcap

@MainActor
final class ScrollCropViewTests: XCTestCase {
    func testEveryHandleResizesItsOwnEdgesWithoutInitialJump() throws {
        _ = NSApplication.shared
        let cases: [(SelectionView.HandlePosition, NSPoint, NSRect)] = [
            (.topLeft, NSPoint(x: 20, y: -30), NSRect(x: 10, y: 0, width: 90, height: 185)),
            (.topRight, NSPoint(x: -20, y: -30), NSRect(x: 0, y: 0, width: 90, height: 185)),
            (.bottomLeft, NSPoint(x: 20, y: 30), NSRect(x: 10, y: 15, width: 90, height: 185)),
            (.bottomRight, NSPoint(x: -20, y: 30), NSRect(x: 0, y: 15, width: 90, height: 185)),
            (.topCenter, NSPoint(x: 0, y: -30), NSRect(x: 0, y: 0, width: 100, height: 185)),
            (.bottomCenter, NSPoint(x: 0, y: 30), NSRect(x: 0, y: 15, width: 100, height: 185)),
            (.leftCenter, NSPoint(x: 20, y: 0), NSRect(x: 10, y: 0, width: 90, height: 200)),
            (.rightCenter, NSPoint(x: -20, y: 0), NSRect(x: 0, y: 0, width: 90, height: 200)),
        ]
        for (handle, delta, expected) in cases {
            let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 200, height: 400), image: try makeImage())
            let window = makeWindow(for: view)
            defer { window.orderOut(nil) }
            try drag(handle, on: view, by: delta, window: window)
            assertRect(view.cropRect, equals: expected)
        }
    }

    func testFourEdgesAlignToRetinaSourcePixels() throws {
        _ = NSApplication.shared
        let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 100, height: 200), image: try makeImage())
        let window = makeWindow(for: view)
        defer { window.orderOut(nil) }
        XCTAssertFalse(view.isOpaque)
        XCTAssertFalse(view.isFlipped)
        try drag(.leftCenter, on: view, by: NSPoint(x: 5.3, y: 0), window: window)
        try drag(.rightCenter, on: view, by: NSPoint(x: -7.3, y: 0), window: window)
        try drag(.bottomCenter, on: view, by: NSPoint(x: 0, y: 9.3), window: window)
        try drag(.topCenter, on: view, by: NSPoint(x: 0, y: -11.3), window: window)
        assertRect(view.cropRect, equals: NSRect(x: 5.5, y: 9.5, width: 87, height: 179))
    }

    func testAllEightHandlesStayCompletelyInsideSelectionAndTinyOverlay() throws {
        _ = NSApplication.shared
        let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 200, height: 400), image: try makeImage())
        let window = makeWindow(for: view)
        defer { window.orderOut(nil) }
        XCTAssertEqual(view.handleRects.count, 8)
        assertHandles(in: view.bounds, view: view)
        try drag(.bottomLeft, on: view, by: NSPoint(x: 20, y: 30), window: window)
        assertHandles(in: NSRect(x: 20, y: 30, width: 180, height: 370), view: view)

        view.setFrameSize(NSSize(width: 1, height: 2))
        assertHandles(in: NSRect(x: 0.1, y: 0.15, width: 0.9, height: 1.85), view: view)
        let unchanged = view.cropRect
        try drag(.topRight, on: view, by: .zero, window: window)
        assertRect(view.cropRect, equals: unchanged)
    }

    func testRotatedCropPreservesBothAxesWhenOverlayResizes() throws {
        _ = NSApplication.shared
        let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 400, height: 200),
                                  image: try makeImage(), rotation: .left)
        let window = makeWindow(for: view)
        defer { window.orderOut(nil) }
        assertRect(view.cropRect, equals: NSRect(x: 0, y: 0, width: 200, height: 100))
        try drag(.bottomLeft, on: view, by: NSPoint(x: 51.3, y: 25.3), window: window)
        try drag(.topRight, on: view, by: NSPoint(x: -49.3, y: -23.3), window: window)
        assertRect(view.cropRect, equals: NSRect(x: 25.5, y: 12.5, width: 150, height: 76))
        let crop = view.cropRect
        view.setFrameSize(NSSize(width: 200, height: 400))
        assertRect(view.cropRect, equals: crop)
        assertHandles(in: view.bounds, view: view)
    }

    func testCornersCannotInvertOrEscapeImageBounds() throws {
        _ = NSApplication.shared
        let cases: [(SelectionView.HandlePosition, NSPoint)] = [
            (.topLeft, NSPoint(x: 1_000, y: -1_000)),
            (.topRight, NSPoint(x: -1_000, y: -1_000)),
            (.bottomLeft, NSPoint(x: 1_000, y: 1_000)),
            (.bottomRight, NSPoint(x: -1_000, y: 1_000)),
        ]
        for (handle, delta) in cases {
            let view = ScrollCropView(frame: NSRect(x: 0, y: 0, width: 100, height: 200), image: try makeImage())
            let window = makeWindow(for: view)
            defer { window.orderOut(nil) }
            try drag(handle, on: view, by: delta, window: window)
            XCTAssertGreaterThanOrEqual(view.cropRect.width, 0.5)
            XCTAssertGreaterThanOrEqual(view.cropRect.height, 0.5)
            XCTAssertGreaterThanOrEqual(view.cropRect.minX, 0)
            XCTAssertGreaterThanOrEqual(view.cropRect.minY, 0)
            XCTAssertLessThanOrEqual(view.cropRect.maxX, 100)
            XCTAssertLessThanOrEqual(view.cropRect.maxY, 200)
            assertHandles(in: view.bounds, view: view)
        }
    }

    private func assertHandles(in rect: NSRect, view: ScrollCropView,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(view.handleRects.count, 8, file: file, line: line)
        for handle in view.handleRects {
            XCTAssertGreaterThan(handle.width, 0, file: file, line: line)
            XCTAssertGreaterThan(handle.height, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(handle.minX, rect.minX - 0.0001, file: file, line: line)
            XCTAssertGreaterThanOrEqual(handle.minY, rect.minY - 0.0001, file: file, line: line)
            XCTAssertLessThanOrEqual(handle.maxX, rect.maxX + 0.0001, file: file, line: line)
            XCTAssertLessThanOrEqual(handle.maxY, rect.maxY + 0.0001, file: file, line: line)
        }
    }

    private func assertRect(_ actual: NSRect, equals expected: NSRect,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.0001, file: file, line: line)
    }

    private func makeImage() throws -> NSImage {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 200, pixelsHigh: 400,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        bitmap.size = NSSize(width: 100, height: 200)
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func makeWindow(for view: NSView) -> NSWindow {
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = view
        return window
    }

    private func drag(_ handle: SelectionView.HandlePosition, on view: ScrollCropView,
                      by delta: NSPoint, window: NSWindow) throws {
        let index = try XCTUnwrap(SelectionView.HandlePosition.allCases.firstIndex(of: handle))
        let rect = view.handleRects[index]
        let start = NSPoint(x: rect.midX, y: rect.midY)
        let end = NSPoint(x: start.x + delta.x, y: start.y + delta.y)
        func event(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [],
                               timestamp: 0, windowNumber: window.windowNumber, context: nil,
                               eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        let original = view.cropRect
        view.mouseDown(with: event(.leftMouseDown, at: start))
        view.mouseDragged(with: event(.leftMouseDragged, at: start))
        assertRect(view.cropRect, equals: original)
        view.mouseDragged(with: event(.leftMouseDragged, at: end))
        view.mouseUp(with: event(.leftMouseUp, at: end))
    }
}
