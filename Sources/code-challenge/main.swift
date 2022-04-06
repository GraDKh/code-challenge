let sourceFile = "/home/dgordon/dev/code-challenge/transactions.csv"
let lines = try readFile(location: sourceFile)
let cells = try lines.map({row in try row.map(CellParsing.parseCell)})
let sheet = try Spreadsheet(cells)
let values = sheet.evaluate()
for row in values {
    print("\(row.map({v in v.toString()}))")
}

//print("\(cells)")

