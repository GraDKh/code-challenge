class Functions {
    static func split(_ args: [Value]) -> Value {
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

    static func spread(_ args: [Value]) -> Value {
        return SpreadValue(args)
    }

    static func asNumber(_ val: Value) -> Double? {
        if let number = val as? SingleValue<Double> {
            return number.val
        } else if let str = val as? SingleValue<String> {
            if let number = Double(str.val) {
                return number
            }
        }

        return nil
    }

    static func sum(_ args: [Value]) -> Value {
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

    static func bte(_ args: [Value]) -> Value {
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

    static func text(_ args: [Value]) -> Value {
        if args.count != 1 {
            return ErrorValue()
        }

        return SingleValue<String>(args[0].toString())
    }
}