import AppKit
import XCTest
@testable import capcap

final class EditorToolbarPlacementTests: XCTestCase {
    private let bounds = NSRect(x: 0, y: 0, width: 1_512, height: 982)
    private let toolbarSize = NSSize(width: 720, height: 44)
    private let sideToolbarSize = NSSize(width: 44, height: 300)

    func testScrollControlsStayInsideSelectionNearItsBottom() {
        let selection = NSRect(x: 200, y: 300, width: 800, height: 550)
        let frame = EditorToolbarPlacement.scrollCaptureControlRect(
            referenceRect: selection, in: bounds, size: NSSize(width: 220, height: 44)
        )
        XCTAssertTrue(selection.contains(frame))
        XCTAssertEqual(frame.midX, selection.midX)
        XCTAssertEqual(frame.minY, selection.minY + 12)
    }

    func testSmallEdgeSelectionKeepsControlsOnScreen() {
        let frame = EditorToolbarPlacement.scrollCaptureControlRect(
            referenceRect: NSRect(x: 0, y: 0, width: 20, height: 20),
            in: bounds, size: NSSize(width: 88, height: 44)
        )
        XCTAssertTrue(bounds.contains(frame))
        XCTAssertEqual(frame.minX, 8)
        XCTAssertFalse(frame.intersects(NSRect(x: 0, y: 0, width: 20, height: 20)))
    }

    func testScrollControlsUseTheSelectedDisplayCoordinates() {
        let display = NSRect(x: -1440, y: 200, width: 1440, height: 900)
        let selection = NSRect(x: -1200, y: 300, width: 600, height: 400)
        let frame = EditorToolbarPlacement.scrollCaptureControlRect(
            referenceRect: selection, in: display, size: NSSize(width: 220, height: 44)
        )
        XCTAssertTrue(selection.contains(frame))
        XCTAssertEqual(frame.midX, selection.midX)
    }

    func testScrollEventAvoidsControlsCoveringTheSelectionCenter() {
        let selection = CGRect(x: 200, y: 300, width: 800, height: 100)
        let controls = CGRect(x: 490, y: 344, width: 220, height: 44)
        let point = EditWindowController.scrollCaptureEventPoint(in: selection, avoiding: controls)
        XCTAssertTrue(selection.contains(point))
        XCTAssertFalse(controls.contains(point))
        XCTAssertEqual(point.y, selection.midY)
    }

    func testScrollEventKeepsCenterWhenControlsAreAwayFromIt() {
        let selection = CGRect(x: -800, y: 100, width: 600, height: 500)
        XCTAssertEqual(EditWindowController.scrollCaptureEventPoint(in: selection, avoiding: nil),
                       CGPoint(x: selection.midX, y: selection.midY))
    }

    func testPrimaryToolbarReservesTopSafeInsetWhenSelectionFillsScreen() {
        let rect = EditorToolbarPlacement.primaryToolbarRect(
            referenceRect: bounds,
            in: bounds,
            size: toolbarSize,
            topSafeInset: 38
        )

        XCTAssertEqual(rect.maxY, bounds.maxY - 38 - 8, accuracy: 0.001)
        XCTAssertEqual(rect.maxX, bounds.maxX - 8, accuracy: 0.001)
    }

    func testPrimaryToolbarRightAlignsWithSelection() {
        let selection = NSRect(x: 200, y: 300, width: 900, height: 500)
        let rect = EditorToolbarPlacement.primaryToolbarRect(
            referenceRect: selection,
            in: bounds,
            size: toolbarSize,
            topSafeInset: 38
        )

        XCTAssertEqual(rect.maxX, selection.maxX, accuracy: 0.001)
    }

    func testPrimaryToolbarKeepsEdgeMarginWithoutTopSafeInset() {
        let rect = EditorToolbarPlacement.primaryToolbarRect(
            referenceRect: bounds,
            in: bounds,
            size: toolbarSize,
            topSafeInset: 0
        )

        XCTAssertEqual(rect.maxY, bounds.maxY - 8, accuracy: 0.001)
    }

    func testPrimaryToolbarBelowSelectionIsUnaffectedByTopSafeInset() {
        let selection = NSRect(x: 200, y: 300, width: 900, height: 500)
        let rect = EditorToolbarPlacement.primaryToolbarRect(
            referenceRect: selection,
            in: bounds,
            size: toolbarSize,
            topSafeInset: 38
        )

        XCTAssertEqual(rect.maxY, selection.minY - 8, accuracy: 0.001)
    }

    func testSideToolbarBottomAlignsWithSelection() {
        let selection = NSRect(x: 200, y: 300, width: 900, height: 500)
        let rect = EditorToolbarPlacement.sideToolbarRect(
            referenceRect: selection,
            in: bounds,
            size: sideToolbarSize
        )

        XCTAssertEqual(rect.minX, selection.maxX + 8, accuracy: 0.001)
        XCTAssertEqual(rect.minY, selection.minY, accuracy: 0.001)
    }

    func testSideToolbarKeepsBottomScreenMargin() {
        let selection = NSRect(x: 200, y: 0, width: 900, height: 500)
        let rect = EditorToolbarPlacement.sideToolbarRect(
            referenceRect: selection,
            in: bounds,
            size: sideToolbarSize
        )

        XCTAssertEqual(rect.minY, bounds.minY + 8, accuracy: 0.001)
    }
}
