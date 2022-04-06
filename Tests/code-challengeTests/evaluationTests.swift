import XCTest
import code_challenge

final class evaluationTests: XCTestCase {
    func testIncFrom() throws {
        let cells: [[CellContent]] =
        [
            [FormulaContent(Formula(IncFrom(1)))],
            [FormulaContent(Formula(UpFormulaRef()))],
            [FormulaContent(Formula(UpFormulaRef()))],
        ]
        let sheet = try Spreadsheet(cells)
        let values = sheet.evaluate()
        XCTAssert(values.count == 3)
        XCTAssert(values[0][0] as! SingleValue<Int> == SingleValue(1))
        XCTAssert(values[1][0] as! SingleValue<Int> == SingleValue(2))
        XCTAssert(values[2][0] as! SingleValue<Int> == SingleValue(3))
    }
}