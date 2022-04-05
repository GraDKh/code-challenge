import XCTest
import code_challenge

final class parsingTests: XCTestCase {
    func testEmptyCell() throws {
      let cell = try CellParsing.parseCell("")
      XCTAssert(cell.compare(EmptyContent()))
    }

    func testStringCell() throws {
      var cell = try CellParsing.parseCell("abc")
      XCTAssert(cell.compare(StringContent("abc")))

      cell = try CellParsing.parseCell("abc, def, ghj")
      XCTAssert(cell.compare(StringContent("abc, def, ghj")))


      cell = try CellParsing.parseCell("1 a")
      XCTAssert(cell.compare(StringContent("1 a")))
    }

    func testNumberCell() throws {
      var cell = try CellParsing.parseCell("0")
      XCTAssert(cell.compare(NumberContent(0)))

      cell = try CellParsing.parseCell("1")
      XCTAssert(cell.compare(NumberContent(1)))

      cell = try CellParsing.parseCell("-1")
      XCTAssert(cell.compare(NumberContent(-1)))

      cell = try CellParsing.parseCell("1234.5678")
      XCTAssert(cell.compare(NumberContent(1234.5678)))

      cell = try CellParsing.parseCell("-1234.5678")
      XCTAssert(cell.compare(NumberContent(-1234.5678)))
    }

    func testLabelCell() throws {
      let cell = try CellParsing.parseCell("!label")
      XCTAssert(cell.compare(LabelContent(Label("label"))))
    }

    func testSimpleFormulas() throws {
      let cell = try CellParsing.parseCell("=1")
      XCTAssert(cell.compare(FormulaContent(Formula(Literal<Double>(1)))))
    }
}
