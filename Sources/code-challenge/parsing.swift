import Foundation
import Parsing

func readFile(location: String) throws -> [[String]] {
    let path = URL(fileURLWithPath: location)
    let text = try String(contentsOf: path)
    return text.split(separator: "\n").map({row in
        row.split(separator: "|", omittingEmptySubsequences: false)
        .map({cell in String(cell)})})
}

// TODO: need more rules for identifier name grammar
let identifierName = Prefix<Substring>(minLength: 1, while: {char in char.isLetter || char == "_"}).map(String.init)

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
        }.map(FunctionCall.init).map(asExpression).parse(&input)
    }
}

struct StringLiteralParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        // TODO: possibly we should support escaping here
        return try Parse {
            "\""
            Prefix { $0 != "\"" }.map(String.init)
            "\""
        }.map(Literal<String>.init).map(asExpression).parse(&input)
    }
}

func toExpression(_ val: Double) -> Expression {
    return Literal(val)
}

// TODO: currently we support only A-Z columns
let columnParser = Prefix<Substring>(minLength: 1, maxLength: 1, while: {char in char.isLetter})
    .map({str in Int(Array(str.uppercased())[0].asciiValue! - Character("A").asciiValue!)})

let cellRefParser = Parse {
        columnParser
        Int.parser()
    }.map({(x, y) in CellRef(CellAddress(Int(x), y - 1))}).map(asExpression)

let upCellRefParser = Parse {
    columnParser
    "^"
}.map({x in UpCellRef(x)}).map(asExpression)

let lastColGroupCellRefParser = Parse {
    columnParser
    "^v"
}.map({x in LastColGroupCellRef(x)}).map(asExpression)

let labelRefParser = Parse {
    "@"
    identifierName
    "<"
    Int.parser(of: Substring.self)
    ">"
}.map({(label, offset) in LabelRef(Label(label), offset - 1)})
.map(asExpression)

let incFromParser = Parse {
    "incFrom("
    Int.parser()
    ")"
}.map({from in IncFrom(from)}).map(asExpression)

struct AtomicExprParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try Parse{
            Whitespace()
            OneOf {
                Parse{"^^"}.map({_ in UpFormulaRef()}).map(asExpression)
                cellRefParser
                lastColGroupCellRefParser
                upCellRefParser
                labelRefParser
                Parse {
                    "("
                    ExpressionParser()
                    ")"
                }
                incFromParser
                FunctionCallParser()
                StringLiteralParser()
                Double.parser(of: Substring.self).map(toExpression)
            }
            Whitespace()
        }.map({(_, expr, _) in expr}).parse(&input)
    }
}

struct SubExpressionParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try OneOf {
            Parse {
                AtomicExprParser()
                OneOf {
                    "*".map({Operator.mult})
                    "/".map({Operator.div})
                }
                SubExpressionParser()
            }.map(BinaryOp.init).map(asExpression)
            Parse { AtomicExprParser() }
        }.parse(&input)
    }
}

func asExpression<T: Expression>(_ expr: T) -> Expression {
    return expr
}

struct PlusMinusExprParser: Parser {
    let operation = OneOf {
                    "+".map({Operator.plus})
                    "-".map({Operator.minus})
                }
    let operand = SubExpressionParser()

    func parse(_ input: inout Substring) throws -> Expression {
        var lhs = try operand.parse(&input)
        var rest = input
        while true {
            do {
                let operation = try operation.parse(&input)
                let rhs = try operand.parse(&input)
                rest = input
                lhs = BinaryOp(lhs, operation, rhs)
            } catch {
                input = rest
                return lhs
            }
        }
    }
}

struct ExpressionParser: Parser {
    func parse(_ input: inout Substring) throws -> Expression {
        return try OneOf {
            PlusMinusExprParser()
            Parse { AtomicExprParser() }
        }.parse(&input)
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