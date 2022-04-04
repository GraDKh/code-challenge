struct EmptyValue {}

struct Label: Hashable {
    let name: String

    init(_ name: String) {
        self.name = name
    }
}

protocol CellContentVisitor {
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

protocol CellContent {
    func apply(_ visitor: CellContentVisitor)
    func evaluate(_ context: ExpressionContext) -> Value
}

class BaseData<Data> {
    let data: Data

    init(data: Data) {
        self.data = data
    }
}

class StringContent: BaseData<String>, CellContent {
    func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<String>(data)
    }
}

class NumberContent: BaseData<Double>, CellContent {
    func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<Double>(data)
    }
}

class FormulaContent: BaseData<Formula>, CellContent {
    func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return data.expr.evaluate(context)
    }
}

class LabelContent: BaseData<Label>, CellContent {
    func apply(_ visitor: CellContentVisitor) {
        visitor.visit(data)
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return SingleValue<String>("!\(data.name)")
    }
}

class EmptyContent: CellContent {
    func apply(_ visitor: CellContentVisitor) {
        visitor.visit(EmptyValue())
    }

    func evaluate(_ context: ExpressionContext) -> Value {
        return NullValue()
    }
}