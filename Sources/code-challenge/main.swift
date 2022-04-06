if CommandLine.argc != 2 {
    print("Wrong arguments. Usage <path to file>")
} else {
    let sourceFile = CommandLine.arguments[1]
    let lines = try readFile(location: sourceFile)
    let cells = try lines.map({row in try row.map(CellParsing.parseCell)})
    let sheet = try Spreadsheet(cells)
    let values = sheet.evaluate()
    for row in values {
        print("\(row.map({v in v.toString()}).joined(separator: "|"))")
    }
}