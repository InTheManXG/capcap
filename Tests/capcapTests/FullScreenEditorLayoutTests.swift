import AppKit
import XCTest
@testable import capcap

final class FullScreenEditorLayoutTests: XCTestCase {
    func testWorkspaceReservesBottomControlsAndSideToolbarOnSelectedDisplay() {
        let bounds = NSRect(x: -1_440, y: 200, width: 1_440, height: 900)
        let workspace = EditorToolbarPlacement.fullScreenWorkspaceRect(
            in: bounds, primaryToolbarHeight: 44, sideToolbarWidth: 44
        )

        XCTAssertEqual(workspace.minX, bounds.minX + 16)
        XCTAssertEqual(workspace.minY, bounds.minY + 44 + 108)
        XCTAssertEqual(workspace.maxX, bounds.maxX - 16 - 44 - 16)
        XCTAssertEqual(workspace.maxY, bounds.maxY - 16)
        XCTAssertTrue(bounds.contains(workspace))

        let withoutSideToolbar = EditorToolbarPlacement.fullScreenWorkspaceRect(
            in: bounds, primaryToolbarHeight: 44, sideToolbarWidth: 0
        )
        XCTAssertEqual(withoutSideToolbar.maxX, bounds.maxX - 16)
    }

    func testLongImageFitsWidthAndKeepsScrollableHeight() {
        let workspace = NSRect(x: 100, y: 150, width: 900, height: 600)
        let imageSize = NSSize(width: 2_400, height: 12_000)
        let layout = EditorToolbarPlacement.fullScreenImageLayout(
            imageSize: imageSize,
            padding: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            in: workspace
        )

        XCTAssertEqual(layout.scale, 0.375, accuracy: 0.001)
        XCTAssertEqual(layout.viewport, workspace)
        XCTAssertGreaterThan(imageSize.height * layout.scale, layout.viewport.height)
    }

    func testShortImageIsNotEnlargedAndBeautifyPaddingStaysInsideWorkspace() {
        let workspace = NSRect(x: 100, y: 150, width: 900, height: 600)
        let shortImage = EditorToolbarPlacement.fullScreenImageLayout(
            imageSize: NSSize(width: 200, height: 100),
            padding: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            in: workspace
        )

        XCTAssertEqual(shortImage.scale, 1)
        XCTAssertEqual(shortImage.viewport.size, NSSize(width: 200, height: 100))
        XCTAssertEqual(shortImage.viewport.midX, workspace.midX)
        XCTAssertEqual(shortImage.viewport.midY, workspace.midY)

        let padding = NSEdgeInsets(top: 24, left: 40, bottom: 56, right: 60)
        let paddedImage = EditorToolbarPlacement.fullScreenImageLayout(
            imageSize: NSSize(width: 1_400, height: 1_800),
            padding: padding,
            in: workspace
        )

        XCTAssertEqual(paddedImage.scale, 800.0 / 1_400, accuracy: 0.001)
        XCTAssertEqual(paddedImage.viewport.width, 1_400 * paddedImage.scale + padding.left + padding.right,
                       accuracy: 0.001)
        XCTAssertEqual(paddedImage.viewport.height, workspace.height)
        XCTAssertEqual(paddedImage.viewport.midX, workspace.midX)
        XCTAssertEqual(paddedImage.viewport.midY, workspace.midY)
        XCTAssertTrue(workspace.contains(paddedImage.viewport))
    }
}
