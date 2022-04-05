import Foundation
import Parsing

func readFile(location: String) throws -> [[String]] {
    let path = URL(fileURLWithPath: location)
    let text = try String(contentsOf: path)
    return text.split(separator: "\n").map({row in row.split(separator: "|").map({cell in String(cell)})})
}

public class CellParsing {
    static let number = Double.parser(of: Substring.self)
    static let string = Rest<Substring>().map(String.init)
    static let empty = Parse{"" }.map({EmptyContent() as CellContent})
    static let cellContent = OneOf {
        empty
        number.map(toContent)
        string.map(toContent)
    }

    public static func parseCell(_ str: String) throws -> CellContent {
        return try cellContent.parse(str[...])
    }

    static private func toContent(_ val: String) -> CellContent {
        return StringContent(String(val))
    }

    static private func toContent(_ val: Double) -> CellContent {
        return NumberContent(val)
    }
}