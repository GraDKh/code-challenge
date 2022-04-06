import Algorithms

public struct CellAddress: Hashable {
    let x: Int
    let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    func shiftUp(_ offset: Int = 1) -> CellAddress {
        return CellAddress(x, y - offset)
    }

    func shiftDown(_ offset: Int = 1) -> CellAddress {
        return CellAddress(x, y + offset)
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
            return y + rowsCount - 1
        }
    }

    init(_ y: Int, _ rowsCount: Int, _ labels: [Label]) {
        self.y = y
        self.rowsCount = rowsCount
        self.labels = labels
    }
}

public class Spreadsheet {
    let cells: [[CellContent]]
    let groups: [CellGroup]
    let labelToGroup: [Label: (column: Int,group:  CellGroup)]

    public init(_ cells: [[CellContent]]) throws {
        self.cells = cells

        var currentGroup: (y: Int, labels: [Label])? = nil
        var groups: [CellGroup] = []
        var labelToGroup: [Label: (column: Int,group:  CellGroup)] = [:]
        for (index, row) in self.cells.enumerated() {
            if row.count > 0 {
                if (row[0] as? LabelContent) != nil {
                    if let groupInfo = currentGroup {
                        let group = CellGroup(groupInfo.y + 1, index - groupInfo.y - 1, groupInfo.labels)
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
        return cells[address.y][address.x]
    }

    func getLastGroupCell(_ x: Int, _ y: Int) -> CellAddress? {
        if let group = groups.last(where: {group in group.lastRow <= y && group.labels.count > x}) {
            return CellAddress(x, group.lastRow)
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

    public func evaluate() -> [[Value]] {
        var result = cells.map({row in [Value?](repeating: nil, count: row.count)})

        func evaluate(_ address: CellAddress) {
            if result[address.y][address.x] != nil {
                return
            }

            let cell = getCell(address)
            let context = ExpressionContext(address, self)
            if let formula = cell as? FormulaContent {
                var dependencies = Set<CellAddress>()
                formula.data.expr.getReferences(context, &dependencies)
                for dep in dependencies {
                    evaluate(dep)
                }
            }

            result[address.y][address.x] = cell.evaluate(context)
        }

        for (y, row) in cells.enumerated() {
            for (x, _) in row.enumerated() {
                evaluate(CellAddress(x, y))
            }
        }

        return result.map({row in row.map({cell in cell!})})
    }
}