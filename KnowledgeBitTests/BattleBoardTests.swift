import XCTest
@testable import KnowledgeBit

/// BattleBoard 純座標運算測試。預設 side=4（4×4 棋盤，共 16 格，id 0..<16）。
///
///   id 索引佈局（row × side + col）：
///     0  1  2  3
///     4  5  6  7
///     8  9 10 11
///    12 13 14 15
final class BattleBoardTests: XCTestCase {

  // MARK: - neighbors

  func testNeighborsOfTopLeftCorner() {
    // (0,0)：右(1)、下(4)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 0)), Set([1, 4]))
  }

  func testNeighborsOfTopRightCorner() {
    // (0,3)：左(2)、下(7)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 3)), Set([2, 7]))
  }

  func testNeighborsOfBottomLeftCorner() {
    // (3,0)：上(8)、右(13)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 12)), Set([8, 13]))
  }

  func testNeighborsOfBottomRightCorner() {
    // (3,3)：上(11)、左(14)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 15)), Set([11, 14]))
  }

  func testNeighborsOfTopEdgeNonCorner() {
    // (0,1)：左(0)、右(2)、下(5)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 1)), Set([0, 2, 5]))
  }

  func testNeighborsOfLeftEdgeNonCorner() {
    // (1,0)：上(0)、下(8)、右(5)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 4)), Set([0, 8, 5]))
  }

  func testNeighborsOfInteriorCellHasFour() {
    // (1,1) at id=5：上(1)、下(9)、左(4)、右(6)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 5)), Set([1, 9, 4, 6]))
  }

  func testNeighborsAllPositionsHaveBetween2And4() {
    for id in 0..<16 {
      let n = BattleBoard.neighbors(of: id)
      XCTAssertGreaterThanOrEqual(n.count, 2, "id=\(id) should have ≥2 neighbors")
      XCTAssertLessThanOrEqual(n.count, 4, "id=\(id) should have ≤4 neighbors")
    }
  }

  func testNeighborsRelationIsSymmetric() {
    // 若 b 是 a 的鄰居，a 也必須是 b 的鄰居
    for a in 0..<16 {
      for b in BattleBoard.neighbors(of: a) {
        XCTAssertTrue(
          BattleBoard.neighbors(of: b).contains(a),
          "neighbors must be symmetric: \(a) ↔ \(b)"
        )
      }
    }
  }

  // MARK: - isEdgeCell

  func testEdgeCellsAreOuterRing() {
    // 4×4 的外環應有 12 格：第一/最後行（各 4 格）+ 中間兩行的左右（各 2 格）
    let edges = (0..<16).filter { BattleBoard.isEdgeCell($0) }
    XCTAssertEqual(edges.count, 12)
  }

  func testInteriorCellsAreNotEdge() {
    // 4×4 內部 4 格：5, 6, 9, 10
    XCTAssertFalse(BattleBoard.isEdgeCell(5))
    XCTAssertFalse(BattleBoard.isEdgeCell(6))
    XCTAssertFalse(BattleBoard.isEdgeCell(9))
    XCTAssertFalse(BattleBoard.isEdgeCell(10))
  }

  func testAllCornersAreEdgeCells() {
    XCTAssertTrue(BattleBoard.isEdgeCell(0))
    XCTAssertTrue(BattleBoard.isEdgeCell(3))
    XCTAssertTrue(BattleBoard.isEdgeCell(12))
    XCTAssertTrue(BattleBoard.isEdgeCell(15))
  }

  // MARK: - Side parameterisation

  func test3x3BoardNeighbors() {
    // 3×3 中央格 (1,1)=4：上(1)、下(7)、左(3)、右(5)
    XCTAssertEqual(Set(BattleBoard.neighbors(of: 4, side: 3)), Set([1, 7, 3, 5]))
  }

  func test3x3CenterIsNotEdge() {
    XCTAssertFalse(BattleBoard.isEdgeCell(4, side: 3))
  }
}
