import Algorithms

public struct CellAddress: Hashable {
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
    let cells: [[CellContent]]
    let groups: [CellGroup]
    let labelToGroup: [Label: (column: Int,group:  CellGroup)]

    init(_ cells: [[CellContent]]) throws {
        self.cells = cells

        var currentGroup: (y: Int, labels: [Label])? = nil
        var groups: [CellGroup] = []
        var labelToGroup: [Label: (column: Int,group:  CellGroup)] = [:]
        for (index, row) in self.cells.enumerated() {
            if row.count > 0 {
                if (row[0] as? LabelContent) != nil {
                    if let groupInfo = currentGroup {
                        let group = CellGroup(groupInfo.y + 1, index - groupInfo.y, groupInfo.labels)
                        groups.append(group)
                        for (labelIndex, label) in groupInfo.labels.enumerated() {
                            labelToGroup[label] = (labelIndex, group)
                        }
                    }

                    let labels = row.map({cell in (cell as! LabelContent).data})
                    currentGroup = (index, labels)
                }
            }
        }

        self.groups = groups
        self.labelToGroup = labelToGroup
    }

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