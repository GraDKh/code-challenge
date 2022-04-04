import Algorithms

struct CellAddress: Hashable {
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

class CellGroup {
    let y: Int
    let rowsCount: Int
    let labels: [Label]

    var lastRow : Int {
        get {
            return y + rowsCount
        }
    }

    init(_ y: Int, _ rowsCount: Int, _ labels: [Label]) {
        self.y = y
        self.rowsCount = rowsCount
        self.labels = labels
    }
}

class Spreadsheet {
    let cells: [[CellContent]] = [] // FIXME
    let groups: [CellGroup] = []
    let labelToGroup: [Label: (column: Int,group:  CellGroup)] = [:]

    func getCell(_ address: CellAddress) -> CellContent {
        return cells[address.x][address.y]
    }

    func getLastGroupCell(_ x: Int, _ y: Int) -> CellAddress? {
        let index = groups[...y].partitioningIndex(where: {group in group.labels.count > y})
        if index <= y {
            return CellAddress(x, groups[index].lastRow)
        } else {
            return nil
        }
    }

    func getCellAddressByLabel(_ label: Label, _ rowOffset: Int) -> CellAddress? {
        if let group = labelToGroup[label] {
            if rowOffset < group.group.rowsCount {
                return CellAddress(group.column, group.group.y + rowOffset)
            }
        }

        return nil
    }
}