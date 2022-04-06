public struct Formula: Equatable {
    let expr: Expression

    public init(_ expr: Expression) {
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
    init() {
    }

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

    init(_ arr: ArrayValue) {
        self.vals = arr.vals
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

    func shiftUp(_ offset: Int = 1) -> ExpressionContext {
        return ExpressionContext(address.shiftUp(offset), sheet)
    }

    func withAddress(_ address: CellAddress) -> ExpressionContext {
        return ExpressionContext(address, sheet)
    }
}

public protocol Expression {
    // Apply ^^ operator
    func shiftDown(_ context: ExpressionContext) -> Expression
    func evaluate(_ context: ExpressionContext) -> Value
    func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>)

    func compare(_ other: Expression) -> Bool
}

public struct Literal<Data: Equatable>: Expression, Equatable {
    let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return self
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<Data>(data)
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherLit = other as? Literal<Data> {
            return self == otherLit
        } else {
            return false
        }
    }
}

struct ParseError: Error {}

public enum Operator {
    case plus, minus, product, division

    static func fromString(_ str: String) -> Operator {
        switch str {
            case "+": return plus
            case "-": return minus
            case "*": return product
            case "/": return division
            default: fatalError()
        }
    }
}

public struct BinaryOp: Expression {
    let op: Operator
    let left: Expression
    let right: Expression

    public init(_ left: Expression, _ op: Operator, _ right: Expression) {
        self.op = op
        self.left = left
        self.right = right
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return BinaryOp(left.shiftDown(context), op, right.shiftDown(context))
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
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

    public func getReferences(_ context: ExpressionContext,_ refs: inout Set<CellAddress>) {
        left.getReferences(context, &refs)
        right.getReferences(context, &refs)
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherOp = other as? BinaryOp {
            return op == otherOp.op &&
                left.compare(otherOp.left) &&
                right.compare(otherOp.right)
        } else {
            return false
        }
    }
}

public protocol Function {
    func call(_ args: [Value]) -> Value
}

public struct FunctionCall: Expression {
    let function: Function
    let args: [Expression]

    public init(_ function: Function, _ args: [Expression]) {
        self.function = function
        self.args = args
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return FunctionCall(function, args.map({expr in expr.shiftDown(context)}))
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        // unroll spread values
        let flatArgs = args.flatMap({(expr: Expression) -> [Value] in
          let value = expr.evaluate(context)
            if let spreadValue = value as? SpreadValue {
                return spreadValue.vals
            } else {
                return [value]
            }
        })

        return function.call(flatArgs)
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherFunc = other as? FunctionCall {
            return type(of: function) == type(of: otherFunc.function) && // assume function implementation are stateless
                   args.count == otherFunc.args.count &&
                   zip(args, otherFunc.args).allSatisfy({(left, right) in left.compare(right)})
        } else {
            return false
        }
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        for arg in args {
            arg.getReferences(context, &refs)
        }
    }
}

public struct IncFrom: Expression, Equatable {
    let from: Int

    init(_ from: Int) {
        self.from = from
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return IncFrom(from + 1)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue(from)
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherInc = other as? IncFrom {
            return self == otherInc
        } else {
            return false
        }
    }
}

// ^^ operator
public struct UpFormulaRef: Expression, Equatable {
    var offset: Int;

    public init(_ offset: Int = 1) {
        self.offset = offset
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return UpFormulaRef(offset + 1)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        if context.address.y < offset {
            return ErrorValue()
        }

        if let expr = getFormulaExpression(context) {
            return expr.evaluate(context)
        } else {
            let upperCell = context.sheet.getCell(context.address.shiftUp(offset))
            return upperCell.evaluate(context)
        }
    }

    public func getReferences(_ context: ExpressionContext,_ refs: inout Set<CellAddress>) {
        if let expr = getFormulaExpression(context) {
            expr.getReferences(context, &refs)
        }
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? UpFormulaRef {
            return self == otherRef
        } else {
            return false
        }
    }

    private func getFormulaExpression(_ context: ExpressionContext) -> Expression? {
        let upperCell = context.sheet.getCell(context.address.shiftUp(offset))
        if let formula = upperCell as? FormulaContent {
            return formula.data.expr.shiftDown(context.shiftUp(offset))
        } else {
            return nil
        }
    }
}

// Direct cell ref, e.g. A2
public struct CellRef: Expression, Equatable {
    let address: CellAddress

    public init(_ address: CellAddress) {
        self.address = address
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return CellRef(address.shiftDown())
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return context.sheet.getCell(address).evaluate(context.withAddress(address))
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        refs.insert(address)
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? CellRef {
            return self == otherRef
        } else {
            return false
        }
    }
}

// Reference to the upper cell, e.g. E^
public struct UpCellRef: Expression, Equatable {
    let x: Int

    public init(_ x: Int) {
        self.x = x
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return self
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        let address = getAddress(context)
        let cell = context.sheet.getCell(address)
        return cell.evaluate(context.withAddress(address))
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        refs.insert(getAddress(context))
    }

    public func compare(_ other: Expression) -> Bool {
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
public struct LastColGroupCellRef: Expression, Equatable {
    let x: Int

    public init(_ x: Int) {
        self.x = x
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return self
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        if let address = context.sheet.getLastGroupCell(x, context.address.y) {
            return context.sheet.getCell(address).evaluate(context.withAddress(address))
        } else {
            return ErrorValue()
        }
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        if let address = context.sheet.getLastGroupCell(x, context.address.y) {
            refs.insert(address)
        }
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? LastColGroupCellRef {
            return self == otherRef
        } else {
            return false
        }
    }
}

// Reference to a cell by label + row offset, e.g.
// @label<n>

public struct LabelRef: Expression, Equatable {
    let label: Label
    let rowOffset: Int

    public init(_ label: Label, _ rowOffset: Int) {
        self.label = label
        self.rowOffset = rowOffset
    }

    public func shiftDown(_ context: ExpressionContext) -> Expression {
        return LabelRef(label, rowOffset + 1)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        if let address = context.sheet.getCellAddressByLabel(label, rowOffset) {
            return context.sheet.getCell(address).evaluate(context.withAddress(address))
        } else {
            return ErrorValue()
        }
    }

    public func getReferences(_ context: ExpressionContext, _ refs: inout Set<CellAddress>) {
        if let address = context.sheet.getCellAddressByLabel(label, rowOffset) {
            refs.insert(address)
        }
    }

    public func compare(_ other: Expression) -> Bool {
        if let otherRef = other as? LabelRef {
            return self == otherRef
        } else {
            return false
        }
    }
}