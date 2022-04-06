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

public protocol SingleDataContent: CellContent {
    associatedtype Data: Equatable

    var data: Data { get }
}

extension SingleDataContent {
    public func compare(_ other: CellContent) -> Bool {
       if let otherData = other as? Self {
            return data == otherData.data
        } else {
            return false
        }
    }
}

public final class StringContent: SingleDataContent {
    public typealias Data = String

    public let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<String>(data)
    }
}

public final class NumberContent: SingleDataContent {
    public typealias Data = Double

    public let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<Double>(data)
    }
}

public final class FormulaContent: SingleDataContent {
    public typealias Data = Formula

    public let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return data.expr.evaluate(context)
    }
}

public final class LabelContent: SingleDataContent {
    public typealias Data = Label

    public let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    public func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<String>("!\(data.name)")
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