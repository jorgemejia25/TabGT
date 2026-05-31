import CoreGraphics
import Testing
@testable import TabGT

struct SplitDropPlacementTests {
    @Test func detectsLeftEdge() {
        let placement = SplitDropPlacement.placementAt(
            CGPoint(x: 20, y: 100),
            in: CGSize(width: 400, height: 300)
        )

        #expect(placement == .left)
    }

    @Test func detectsRightEdge() {
        let placement = SplitDropPlacement.placementAt(
            CGPoint(x: 380, y: 100),
            in: CGSize(width: 400, height: 300)
        )

        #expect(placement == .right)
    }

    @Test func detectsTopEdge() {
        let placement = SplitDropPlacement.placementAt(
            CGPoint(x: 200, y: 20),
            in: CGSize(width: 400, height: 300)
        )

        #expect(placement == .up)
    }

    @Test func detectsBottomEdge() {
        let placement = SplitDropPlacement.placementAt(
            CGPoint(x: 200, y: 280),
            in: CGSize(width: 400, height: 300)
        )

        #expect(placement == .down)
    }

    @Test func centerDoesNotSuggestSplit() {
        let placement = SplitDropPlacement.placementAt(
            CGPoint(x: 200, y: 150),
            in: CGSize(width: 400, height: 300)
        )

        #expect(placement == nil)
    }
}
