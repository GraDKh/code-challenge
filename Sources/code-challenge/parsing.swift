import Foundation

func readFile(location: String) throws -> [[String]] {
    let path = URL(fileURLWithPath: location)
    let text = try String(contentsOf: path)
    return text.split(separator: "\n").map({row in row.split(separator: "|").map({cell in String(cell)})})
}