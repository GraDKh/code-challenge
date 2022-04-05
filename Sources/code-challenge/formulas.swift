public struct Formula: Equatable {
    let expr: Expression

    init(expr: Expression) {
        self.expr = expr
    }

    public static func==(_ left: Formula, _ right: Formula) -> Bool {
        return left.expr.compare(right.expr)
    }
}

public protocol Value {
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

public class ExpressionContext {
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

    func compare(_ other: Expression) -> Bool
}

struct Literal<Data: Equatable>: Expression, Equatable {
    let data: Data

    init(_ data: Data) {
        self.data = data
    }

    func shiftDown(_ context: ExpressionContext) -> Expression {
        return self
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<Data>(data)
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
    }

    func compare(_ other: Expression) -> Bool {
        if let otherLit = other as? Literal<Data> {
            return self == otherLit
        } else {
            return false
        }
    }
}

enum Operator {
    case plus, minus, product, division
}

struct BinaryOp: Expression {
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

    func compare(_ other: Expression) -> Bool {
        if let otherOp = other as? BinaryOp {
            return op == otherOp.op &&
                left.compare(otherOp.left) &&
                right.compare(otherOp.right)
        } else {
            return false
        }
    }
}

protocol Function {
    func call(_ args: [Value]) -> Value
}

struct FunctionCall: Expression {
    let function: Function
    let args: [Expression]

    init(_ function: Function, _ args: [Expression]) {
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

        return function.call(args)
    }

    func compare(_ other: Expression) -> Bool {
        if let otherFunc = other as? FunctionCall {
            return type(of: function) == type(of: otherFunc.function) && // assume function implementation are stateless
                   args.count == otherFunc.args.count &&
                   zip(args, otherFunc.args).allSatisfy({(left, right) in left.compare(right)})
        } else {
            return false
        }
    }

    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        for arg in args {
            arg.getReferences(context, &refs)
        }
    }
}

struct IncFrom: Expression, Equatable {
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

    func compare(_ other: Expression) -> Bool {
        if let otherInc = other as? IncFrom {
            return self == otherInc
        } else {
            return false
        }
    }
}

// ^^ operator
struct UpFormulaRef: Expression, Equatable {
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

    func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? UpFormulaRef {
            return self == otherRef
        } else {
            return false
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
struct CellRef: Expression, Equatable {
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

    func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? CellRef {
            return self == otherRef
        } else {
            return false
        }
    }
}

// Reference to the upper cell, e.g. E^
struct UpCellRef: Expression, Equatable {
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

    func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? UpCellRef {
            return self == otherRef
        } else {
            return false
        }
    }

    private func getAddress(_ context: ExpressionContext) -> CellAddress {
        return context.address.withColumn(x).shiftUp()
    }
}

// Reference to the last cell in a row group having specified column, e.g.
// E^v
struct LastColGroupCellRef: Expression, Equatable {
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

    func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? LastColGroupCellRef {
            return self == otherRef
        } else {
            return false
        }
    }
}

// Reference to a cell by label + row offset, e.g.
// @label<n>

struct LabelRef: Expression, Equatable {
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

    func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? LabelRef {
            return self == otherRef
        } else {
            return false
        }
    }
}