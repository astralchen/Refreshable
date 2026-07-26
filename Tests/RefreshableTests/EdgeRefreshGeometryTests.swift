import Testing
import UIKit
@testable import Refreshable

@Suite("EdgeRefreshGeometry")
struct EdgeRefreshGeometryTests {

    @Test("四个物理方向使用同一边界距离公式")
    func pullDistanceForEveryPhysicalEdge() {
        let base = makeGeometry(edge: .top, offset: CGPoint(x: -7, y: -40))
        #expect(base.pullDistance == 30)

        let bottom = makeGeometry(edge: .bottom, offset: CGPoint(x: 0, y: 770))
        #expect(bottom.pullDistance == 40)

        let left = makeGeometry(edge: .left, offset: CGPoint(x: -50, y: 0))
        #expect(left.pullDistance == 30)

        let right = makeGeometry(edge: .right, offset: CGPoint(x: 720, y: 0))
        #expect(right.pullDistance == 30)
    }

    @Test("reveal offset 在四方向露出完整 reserved extent")
    func revealOffsetsForEveryPhysicalEdge() {
        #expect(makeGeometry(edge: .top).revealContentOffset.y == -72)
        #expect(makeGeometry(edge: .bottom).revealContentOffset.y == 792)
        #expect(makeGeometry(edge: .left).revealContentOffset.x == -82)
        #expect(makeGeometry(edge: .right).revealContentOffset.x == 752)
    }

    @Test("renderer frame 按物理边应用 outer spacing 和 cross-axis inset")
    func rendererFramesRespectPlacement() {
        let top = makeGeometry(edge: .top)
        #expect(
            top.rendererFrame(in: CGRect(x: 0, y: 0, width: 320, height: 62))
                == CGRect(x: 4, y: 8, width: 312, height: 50)
        )

        let right = makeGeometry(edge: .right)
        #expect(
            right.rendererFrame(in: CGRect(x: 0, y: 0, width: 62, height: 480))
                == CGRect(x: 4, y: 4, width: 50, height: 472)
        )
    }

    private func makeGeometry(
        edge: RefreshablePhysicalEdge,
        offset: CGPoint = .zero
    ) -> EdgeRefreshGeometry {
        EdgeRefreshGeometry(
            physicalEdge: edge,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 480),
            contentSize: CGSize(width: 1000, height: 1200),
            contentOffset: offset,
            baselineInset: UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 10),
            boundaryAdjustment: .zero,
            automaticAdjustment: .zero,
            safeAreaInsets: .zero,
            displayExtent: 50,
            placement: RefreshablePlacement(
                contentSpacing: 4,
                outerSpacing: 8,
                crossAxisInset: 4
            )
        )
    }
}
