import Foundation
import Parsing

func readFile(location: String) throws -> [[String]] {
    let path = URL(fileURLWithPath: location)
    let text = try String(contentsOf: path)
    return text.split(separator: "\n").map({row in row.split(separator: "|").map({cell in String(cell)})})
}

let identifierName = Prefix<Substring>{$0.isLetter}.map(String.init)

struct FunctionCallParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try Parse {
            identifierName.map(parseFunction)
            "("
            Many {
                ExpressionParser()
            } separator: {
            ","
            }
            ")"
        }.map(FunctionCall.init).map(asExpression).parse(input)
    }
}

struct StringLiteralParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        // TODO: possibly we should support escaping here
        return try Parse {
            "\""
            Prefix { $0 != "\"" }.map(String.init)
            "\""
        }.map(Literal<String>.init).map(asExpression).parse(input)
    }
}

func toExpression(_ val: Double) -> Expression {
    return Literal(val)
}

struct AtomicExprParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try OneOf {
            Parse {
                "("
                ExpressionParser()
                ")"
            }
            FunctionCallParser()
            StringLiteralParser()
            Double.parser(of: Substring.self).map(toExpression)
        }.parse(input)
    }
}

struct SubExpressionParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try OneOf {
            Parse {
                AtomicExprParser()
                Prefix { $0 == "*" || $0 == "*"}.map(String.init).map(Operator.fromString)
                SubExpressionParser()
            }.map(BinaryOp.init).map(asExpression)
            Parse { AtomicExprParser() }
        }.parse(input)
    }
}

func asExpression<T: Expression>(_ expr: T) -> Expression {
    return expr
}

struct ExpressionParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try OneOf {
            Parse {
                SubExpressionParser()
                Prefix { $0 == "+" || $0 == "-"}.map(String.init).map(Operator.fromString)
                SubExpressionParser()
            }.map(BinaryOp.init).map(asExpression)
            Parse { AtomicExprParser() }
        }.parse(input)
    }
}

public class CellParsing {
    static let number = Double.parser(of: Substring.self)
    static let string = Rest<Substring>().map(String.init)
    static let label = Parse {
        "!"
        string.map({str in Label(str)})
        }
    static let empty = Parse{""}.map({EmptyContent() as CellContent})
    static let expressionParser = ExpressionParser()
    static let formula = Parse {
        "="
        ExpressionParser().map(Formula.init)
        }
    static let cellContent = OneOf {
        Parse {
            label.map(toContent)
            End()
        }
        Parse {
            formula.map(toContent)
            End()
        }
        Parse {
            number.map(toContent)
            End()
        }
        Parse {
            string.map(toContent)
            End()
        }
        Parse {
            empty
            End()
        }
    }

    public static func parseCell(_ str: String) throws -> CellContent {
        return try cellContent.parse(str[...])
    }

    static private func toContent(_ val: String) -> CellContent {
        return StringContent(val)
    }

    static private func toContent(_ val: Label) -> CellContent {
        return LabelContent(val)
    }

    static private func toContent(_ val: Double) -> CellContent {
        return NumberContent(val)
    }

    static private func toContent(_ val: Formula) -> CellContent {
        return FormulaContent(val)
    }
}