struct CellAddress : Hashable {
    let x: Int
    let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    func shiftUp() -> CellAddress {
        return CellAddress(x, y - 1)
    }

    func shiftDown() -> CellAddress {
        return CellAddress(x, y + 1)
    }

    func withColumn(_ newX: Int) -> CellAddress {
        return CellAddress(newX, y)
    }
}

class Spreadsheet {
    let cells: [[CellContent]] = [] // FIXME

    func getCell(_ address: CellAddress) -> CellContent {
        return cells[address.x][address.y]
    }
}