public struct Split: Function {
    public init() {}

    public func call(_ args: [Value]) -> Value {
        if args.count != 2 {
            return ErrorValue()
        }

        if let str = args[0] as? SingleValue<String> {
            if let separator = args[1] as? SingleValue<String> {
                return ArrayValue(str.val.components(separatedBy: separator.val).map({chunk in SingleValue<String>(chunk)}))
            }
        }

        return ErrorValue()
    }
}

public struct Spread: Function {
    public init() {}

    public func call(_ args: [Value]) -> Value {
        return SpreadValue(args)
    }
}

func asNumber(_ val: Value) -> Double? {
    if let number = val as? SingleValue<Double> {
        return number.val
    } else if let str = val as? SingleValue<String> {
        if let number = Double(str.val) {
            return number
        }
    }

    return nil
}

public struct Sum: Function {
    public init() {}

    public func call(_ args: [Value]) -> Value {
        var result = 0.0
        for arg in args {
            if let number = asNumber(arg) {
                result += number
            } else {
                return ErrorValue()
            }
        }
        return SpreadValue(args)
    }
}

public struct BTE: Function {
    public init() {}

    public func call(_ args: [Value]) -> Value {
        if args.count != 2 {
            return ErrorValue()
        }

        if let left = args[0] as? SingleValue<Double> {
            if let right = args[1] as? SingleValue<Double> {
                return SingleValue<Bool>(left.val >= right.val)
            }
        }

        return ErrorValue()
    }
}

public struct Text: Function {
    public init() {}

    public func call(_ args: [Value]) -> Value {
        if args.count != 1 {
            return ErrorValue()
        }

        return SingleValue<String>(args[0].toString())
    }
}

public struct UnknownFunction: Function {
    public init() {}

    public func call(_ args: [Value]) -> Value {
        return ErrorValue()
    }
}

func parseFunction(_ name: String) -> Function {
    switch name {
        case "split": return Split()
        case "spread": return Spread()
        case "sum": return Sum()
        case "bte": return BTE()
        case "text": return Text()
        default: return UnknownFunction()
    }
}