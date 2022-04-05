public struct EmptyValue {}

public struct Label: Hashable {
    let name: String

    public init(_ name: String) {
        self.name = name
    }
}

public protocol CellContentVisitor {
    func visit(_: EmptyValue)
    func visit(_ value: String)
    func visit(_ value: Double)
    func visit(_ value: Formula)
    func visit(_ value: Label)
}

class DefaultCellContentVisitor: CellContentVisitor {
    func visit(_: EmptyValue) {}
    func visit(_ value: String) {}
    func visit(_ value: Double) {}
    func visit(_ value: Formula) {}
    func visit(_ value: Label) {}
}

public protocol CellContent {
    func apply(_ visitor: CellContentVisitor)
    func evaluate(_ context: ExpressionContext) -> Value
    func compare(_ other: CellContent) -> Bool
}

public class SingleDataContent<Data: Equatable> {
    let data: Data

    public init(_ data: Data) {
        self.data = data
    }


    func compare<FinalType: SingleDataContent<Data>, CellContent>(_ left : FinalType, _ right: CellContent) -> Bool {
        if let otherData = right as? FinalType {
            return left.data == otherData.data
        } else {
            return false
        }
    }
}

public class StringContent: SingleDataContent<String>, CellContent {
    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<String>(data)
    }

    public func compare(_ other: CellContent) -> Bool {
        return compare(self, other)
    }
}

public class NumberContent: SingleDataContent<Double>, CellContent {
    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<Double>(data)
    }

    public func compare(_ other: CellContent) -> Bool {
        return compare(self, other)
    }
}

public class FormulaContent: SingleDataContent<Formula>, CellContent {
    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return data.expr.evaluate(context)
    }

    public func compare(_ other: CellContent) -> Bool {
        return compare(self, other)
    }
}

public class LabelContent: SingleDataContent<Label>, CellContent {
    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<String>("!\(data.name)")
    }

    public func compare(_ other: CellContent) -> Bool {
        return compare(self, other)
    }
}

public struct EmptyContent: CellContent {
    public init(){}

    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(EmptyValue())
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return NullValue()
    }

    public func compare(_ other: CellContent) -> Bool {
        return (other as? EmptyContent) != nil
    }
}