import AppKit
import Carbon
import XCTest
@testable import capcap

final class AutoScrollInputTests: XCTestCase {
    private let controlRect = CGRect(x: 220, y: 220, width: 150, height: 40)

    private func makeScroller(interactiveRect: CGRect? = nil) -> AutoScroller {
        AutoScroller(
            centerPoint: CGPoint(x: 300, y: 350),
            blockingRect: CGRect(x: 100, y: 200, width: 400, height: 300),
            interactiveRect: interactiveRect,
            speedPointsPerSecond: 300
        )
    }

    func testScreenshotBodyStillBlocksMouseInput() {
        let scroller = makeScroller(interactiveRect: controlRect)

        XCTAssertTrue(scroller.blocksMouseInput(at: CGPoint(x: 120, y: 280)))
        XCTAssertTrue(scroller.blocksMouseInput(at: CGPoint(x: 210, y: 240)))
        XCTAssertTrue(scroller.blocksMouseInput(at: CGPoint(x: 380, y: 240)))
    }

    func testControlInsideCaptureAllowsMouseInput() {
        let scroller = makeScroller(interactiveRect: controlRect)

        XCTAssertFalse(scroller.blocksMouseInput(at: CGPoint(x: 250, y: 240)))
    }

    func testNoControlRectPreservesCaptureBlocking() {
        let scroller = makeScroller()

        XCTAssertTrue(scroller.blocksMouseInput(at: CGPoint(x: 250, y: 240)))
    }

    func testPointsOutsideCaptureRemainAllowed() {
        let scroller = makeScroller(interactiveRect: controlRect)

        XCTAssertFalse(scroller.blocksMouseInput(at: CGPoint(x: 90, y: 240)))
        XCTAssertFalse(scroller.blocksMouseInput(at: CGPoint(x: 510, y: 240)))
    }

    func testEscapeAndFinishKeysAreConsumedAndForwardedToTheCaptureSession() throws {
        for keyCode in [kVK_Escape, kVK_ANSI_A, kVK_Return] {
            let forwarded = expectation(description: "Forward key \(keyCode)")
            forwarded.assertForOverFulfill = true
            let scroller = AutoScroller(
                centerPoint: .zero,
                blockingRect: .zero,
                speedPointsPerSecond: 300,
                onKeyPressed: { event in
                    XCTAssertEqual(event.type, .keyDown)
                    XCTAssertEqual(Int(event.keyCode), keyCode)
                    forwarded.fulfill()
                }
            )
            // 直接检查事件分发，不安装全局监听或向其他应用发送按键
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil,
                                             virtualKey: CGKeyCode(keyCode), keyDown: true))
            event.flags = []
            XCTAssertNil(scroller.handleTappedEvent(type: .keyDown, event: event))
            XCTAssertNil(scroller.handleTappedEvent(type: .keyDown, event: event))
            wait(for: [forwarded], timeout: 1)
        }
    }

    func testSpaceStillPassesToTheModeSwitchMonitor() throws {
        let scroller = makeScroller()
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil,
                                         virtualKey: CGKeyCode(kVK_Space), keyDown: true))
        event.flags = []

        XCTAssertNotNil(scroller.handleTappedEvent(type: .keyDown, event: event))
    }
}
