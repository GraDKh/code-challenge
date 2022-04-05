import XCTest
import code_challenge

final class parsingTests: XCTestCase {
    func testEmptyCell() throws {
      let cell = try CellParsing.parseCell("")
      XCTAssert(cell.compare(EmptyContent()))
    }
}
