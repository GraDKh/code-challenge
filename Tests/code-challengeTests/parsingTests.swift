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

    func testNumberLiteralFormula() throws {
      let cell = try CellParsing.parseCell("=1")
      XCTAssert(cell.compare(FormulaContent(Formula(Literal<Double>(1)))))
    }

    func testStringLiteralFormula() throws {
      let cell = try CellParsing.parseCell("=\"abc\"")
      XCTAssert(cell.compare(FormulaContent(Formula(Literal<String>("abc")))))
    }

    func testFunctionCallFormula() throws {
      let cell = try CellParsing.parseCell("=sum(1, 2)")
      XCTAssert(cell.compare(FormulaContent(Formula(
        FunctionCall(
          Sum(),
          [
            Literal<Double>(1),
            Literal<Double>(2)
          ]
        )))))
    }

    func testArithmeticFormula() throws {
      let cell = try CellParsing.parseCell("=1 + 2*3 - 5")
      XCTAssert(cell.compare(FormulaContent(Formula(
        BinaryOp(
          BinaryOp(
            Literal(1.0),
            Operator.plus,
            BinaryOp(
              Literal(2.0),
              Operator.product,
              Literal(3.0)
            )),
          Operator.minus,
          Literal(5.0)
        )))))
    }

    func testUpperFormulaRef() throws {
      var cell = try CellParsing.parseCell("=^^")
      XCTAssert(cell.compare(FormulaContent(Formula(
        UpFormulaRef()
      ))))

      cell = try CellParsing.parseCell("=^^ + 1")
      XCTAssert(cell.compare(FormulaContent(Formula(
        BinaryOp(
          UpFormulaRef(),
          Operator.plus,
          Literal(1.0)
      )))))
    }
}
