class Formula {
    let expr: Expression

    init(expr: Expression) {
        self.expr = expr
    }
}

protocol Value {
    func toString() -> String
}

struct ErrorValue: Value {
    func toString() -> String {
        return "Error"
    }
}

struct NullValue: Value {
    func toString() -> String {
        return ""
    }
}

class SingleValue<Data>: Value {
    let val: Data

    init(_ val: Data) {
        self.val = val
    }

    func toString() -> String {
        return "\(val)"
    }
}

class ArrayValue: Value {
    let vals: [Value]

    init(_ vals: [Value]) {
        self.vals = vals
    }

    func toString() -> String {
        return vals.map({val in val.toString()}).joined(separator: ", ")
    }
}

// Special value for spreade b operator.
// This value shouldn't be the final one, it can only be processed by a further function call
class SpreadValue: Value {
    let vals: [Value]

    init(_ vals: [Value]) {
        self.vals = vals
    }

    func toString() -> String {
        return "!Spread value"
    }
}

class ExpressionContext {
    let address: CellAddress
    let sheet: Spreadsheet

    init(_ address: CellAddress, _ sheet: Spreadsheet) {
        self.address = address
        self.sheet = sheet
    }

    func shiftUp() -> ExpressionContext {
        return ExpressionContext(address.shiftUp(), sheet)
    }

    func withAddress(_ address: CellAddress) -> ExpressionContext {
        return ExpressionContext(address, sheet)
    }
}

protocol Expression {
    // Apply ^^ operator
    func shiftDown(_ context: ExpressionContext) -> Expression
    func evaluate(_ context: ExpressionContext) -> Value
    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>)
}

enum Operator {
    case plus, minus, product, division
}

class BinaryOp: Expression {
    let op: Operator
    let left: Expression
    let right: Expression

    init(_ op: Operator, _ left: Expression, _ right: Expression) {
        self.op = op
        self.left = left
        self.right = right
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return BinaryOp(op, left.shiftDown(context), right.shiftDown(context))
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        // TODO: should we support arithmetic operations on other types?
        if let leftVal = left.evaluate(context) as? SingleValue<Double> {
            if let rightVal = right.evaluate(context) as? SingleValue<Double> {
                switch op {
                    case .plus: return SingleValue<Double>(leftVal.val + rightVal.val)
                    case .minus: return SingleValue<Double>(leftVal.val - rightVal.val)
                    case .product: return SingleValue<Double>(leftVal.val * rightVal.val)
                    case .division: return SingleValue<Double>(leftVal.val / rightVal.val)
                }
            }
        }

        return ErrorValue()
    }

    func getReferences(_ context: ExpressionContext,_ refs: inout Set<CellAddress>) {
        left.getReferences(context, &refs)
        right.getReferences(context, &refs)
    }
}

typealias Function = (_ args: [Value]) -> Value

class FunctionCall: Expression {
    let function: Function
    let args: [Expression]

    init(_ function: @escaping Function, _ args: [Expression]) {
        self.function = function
        self.args = args
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return FunctionCall(function, args.map({expr in expr.shiftDown(context)}))
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        // unroll spread values
        let args = args.flatMap({(expr: Expression) -> [Value] in 
            let value = expr.evaluate(context)
            if let spreadValue = value as? SpreadValue {
                return spreadValue.vals
            } else {
                return [value]
            }
        })

        return function(args)
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        for arg in args {
            arg.getReferences(context, &refs)
        }
    }
}

class IncFrom: Expression {
    let from: Double

    init(_ from: Double) {
        self.from = from
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return IncFrom(from + 1)
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue(from)
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
    }
}

// ^^ operator
class UpFormulaRef: Expression {
    func shiftDown(_ context: ExpressionContext) -> Expression {
        return UpFormulaRef()
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        if context.address.x <= 0 {
            return ErrorValue()
        }

        if let expr = getFormulaExpression(context) {
            return expr.evaluate(context)
        } else {
            let upperCell = context.sheet.getCell(context.address.shiftUp())
            return upperCell.evaluate(context)
        }
    }

    func getReferences(_ context: ExpressionContext,_ refs: inout Set<CellAddress>) {
        if let expr = getFormulaExpression(context) {
            expr.getReferences(context, &refs)
        }
    }

    private func getFormulaExpression(_ context: ExpressionContext) -> Expression? {
        let upperCell = context.sheet.getCell(context.address.shiftUp())
        if let formula = upperCell as? FormulaContent {
            return formula.data.expr.shiftDown(context.shiftUp())
        } else {
            return nil
        }
    }
}

// Direct cell ref, e.g. A2
class CellRef: Expression {
    let address: CellAddress

    init(_ address: CellAddress) {
        self.address = address
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return CellRef(address.shiftDown())
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return context.sheet.getCell(address).evaluate(context.withAddress(address))
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        refs.insert(address)
    }
}

// Reference to the upper cell, e.g. E^
class UpCellRef: Expression {
    let x: Int

    init(_ x: Int) {
        self.x = x
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return self
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        let address = getAddress(context)
        let cell = context.sheet.getCell(address)
        return cell.evaluate(context.withAddress(address))
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        refs.insert(getAddress(context))
    }

    private func getAddress(_ context: ExpressionContext) -> CellAddress {
        return context.address.withColumn(x).shiftUp()
    }
}

// Reference to the last cell in a row group having specified column, e.g.
// E^v
class LastColGroupCellRef: Expression {
    let x: Int

    init(_ x: Int) {
        self.x = x
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return self
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        if let address = context.sheet.getLastGroupCell(x, context.address.y) {
            return context.sheet.getCell(address).evaluate(context.withAddress(address))
        } else {
            return ErrorValue()
        }
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        if let address = context.sheet.getLastGroupCell(x, context.address.y) {
            refs.insert(address)
        }
    }
}

// Reference to a cell by label + row offset, e.g.
// @label<n>

class LabelRef: Expression {
    let label: Label
    let rowOffset: Int

    init(_ label: Label, _ rowOffset: Int) {
        self.label = label
        self.rowOffset = rowOffset
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return LabelRef(label, rowOffset + 1)
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        if let address = context.sheet.getCellAddressByLabel(label, rowOffset) {
            return context.sheet.getCell(address).evaluate(context.withAddress(address))
        } else {
            return ErrorValue()
        }
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        if let address = context.sheet.getCellAddressByLabel(label, rowOffset) {
            refs.insert(address)
        }
    }
}