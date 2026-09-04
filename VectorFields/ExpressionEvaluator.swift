//
//  ExpressionEvaluator.swift
//  VectorFields
//
//  Created by Sachin Agrawal on 8/18/26.
//

import Foundation

// MARK: Errors

// Describe every failure of the parser in wording shown straight to the user
enum ExpressionError: Error, LocalizedError {
    case empty
    case unexpectedCharacter(Character)
    case unmatchedClosingParenthesis(column: Int)
    case wrongComponentCount(Int)
    case unknownSymbol(String)
    case functionNeedsParentheses(String)
    case wrongArgumentCount(name: String, expected: String, found: Int)
    case missingOperand
    case unexpectedToken(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "One of the components is empty. Each one needs a number or an expression such as \"x\" or \"sin(y)\"."
        case .unexpectedCharacter(let character):
            return "The character \"\(character)\" is not something this app understands."
        case .unmatchedClosingParenthesis(let column):
            return "There is a \")\" at position \(column) with no \"(\" to match it. Remove it or add the missing \"(\"."
        case .wrongComponentCount(let found):
            return "The vector field must have 3 components separated by commas, but \(found) \(found == 1 ? "was" : "were") found."
        case .unknownSymbol(let name):
            return "\"\(name)\" is not a known function, constant, or variable. The variables are x, y, and z."
        case .functionNeedsParentheses(let name):
            return "\"\(name)\" is a function, so it needs its argument in parentheses, like \(name)(x)."
        case .wrongArgumentCount(let name, let expected, let found):
            return "\(name)() takes \(expected) but was given \(found)."
        case .missingOperand:
            return "An operator is missing a value to work on. Check for a stray +, -, *, /, %, or ^."
        case .unexpectedToken(let text):
            return "Unexpected \"\(text)\" — the expression does not read as valid math."
        }
    }
}

// MARK: Math Library

// Catalog everything the parser is allowed to call or look up
enum MathLibrary {

    // Hold a named function alongside its allowed argument count
    struct Function {
        let minArgs: Int
        let maxArgs: Int
        let apply: ([Double]) -> Double

        // Describe the argument count in words for the error message
        var arityDescription: String {
            if maxArgs == Int.max { return "\(minArgs) or more arguments" }
            if minArgs == maxArgs { return minArgs == 1 ? "1 argument" : "\(minArgs) arguments" }
            return "\(minArgs) to \(maxArgs) arguments"
        }
    }

    // Keep the function table below readable with builders for common argument counts
    private static func unary(_ body: @escaping (Double) -> Double) -> Function {
        Function(minArgs: 1, maxArgs: 1) { body($0[0]) }
    }

    private static func binary(_ body: @escaping (Double, Double) -> Double) -> Function {
        Function(minArgs: 2, maxArgs: 2) { body($0[0], $0[1]) }
    }

    // Define the named values that can be used anywhere a number can
    static let constants: [String: Double] = [
        "pi": Double.pi,
        "π": Double.pi,
        "tau": Double.pi * 2,
        "τ": Double.pi * 2,
        "e": M_E,
        "phi": (1 + 5.0.squareRoot()) / 2,
        "φ": (1 + 5.0.squareRoot()) / 2
    ]

    // Define the single letters that stand for a point in the field
    static let variables: Set<Character> = ["x", "y", "z"]

    // List every callable function keyed by its lowercased name
    static let functions: [String: Function] = [
        // Trigonometry in radians
        "sin": unary(Foundation.sin),
        "sine": unary(Foundation.sin),
        "cos": unary(Foundation.cos),
        "cosine": unary(Foundation.cos),
        "tan": unary(Foundation.tan),
        "tangent": unary(Foundation.tan),
        "csc": unary { 1 / Foundation.sin($0) },
        "cosecant": unary { 1 / Foundation.sin($0) },
        "sec": unary { 1 / Foundation.cos($0) },
        "secant": unary { 1 / Foundation.cos($0) },
        "cot": unary { Foundation.cos($0) / Foundation.sin($0) },
        "cotangent": unary { Foundation.cos($0) / Foundation.sin($0) },

        // Inverse trigonometry
        "asin": unary(Foundation.asin),
        "arcsin": unary(Foundation.asin),
        "acos": unary(Foundation.acos),
        "arccos": unary(Foundation.acos),
        "atan": unary(Foundation.atan),
        "arctan": unary(Foundation.atan),
        "acsc": unary { Foundation.asin(1 / $0) },
        "arccsc": unary { Foundation.asin(1 / $0) },
        "asec": unary { Foundation.acos(1 / $0) },
        "arcsec": unary { Foundation.acos(1 / $0) },
        "acot": unary { Double.pi / 2 - Foundation.atan($0) },
        "arccot": unary { Double.pi / 2 - Foundation.atan($0) },
        "atan2": binary(Foundation.atan2),

        // Hyperbolic and inverse hyperbolic
        "sinh": unary(Foundation.sinh),
        "cosh": unary(Foundation.cosh),
        "tanh": unary(Foundation.tanh),
        "csch": unary { 1 / Foundation.sinh($0) },
        "sech": unary { 1 / Foundation.cosh($0) },
        "coth": unary { Foundation.cosh($0) / Foundation.sinh($0) },
        "asinh": unary(Foundation.asinh),
        "arcsinh": unary(Foundation.asinh),
        "acosh": unary(Foundation.acosh),
        "arccosh": unary(Foundation.acosh),
        "atanh": unary(Foundation.atanh),
        "arctanh": unary(Foundation.atanh),

        // Exponentials and logarithms
        "exp": unary(Foundation.exp),
        "ln": unary(Foundation.log),
        "log2": unary(Foundation.log2),
        "log10": unary(Foundation.log10),

        // Take base 10 with one argument or base b with two
        "log": Function(minArgs: 1, maxArgs: 2) { args in
            args.count == 1 ? Foundation.log10(args[0]) : Foundation.log(args[1]) / Foundation.log(args[0])
        },

        // Powers and roots
        "sqrt": unary { $0.squareRoot() },
        "cbrt": unary(Foundation.cbrt),
        "pow": binary(Foundation.pow),
        "root": binary { degree, value in
            // Keep odd roots of negatives real the way a hand calculation would
            if value < 0, degree.truncatingRemainder(dividingBy: 2) == 1 {
                return -Foundation.pow(-value, 1 / degree)
            }
            return Foundation.pow(value, 1 / degree)
        },
        "hypot": Function(minArgs: 2, maxArgs: Int.max) { args in
            args.reduce(0) { $0 + $1 * $1 }.squareRoot()
        },

        // Rounding and sign
        "abs": unary(Swift.abs),
        "sign": unary { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) },
        "sgn": unary { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) },
        "floor": unary(Foundation.floor),
        "ceil": unary(Foundation.ceil),
        "ceiling": unary(Foundation.ceil),
        "round": unary(Foundation.round),
        "trunc": unary(Foundation.trunc),

        // Comparison and clamping
        "min": Function(minArgs: 1, maxArgs: Int.max) { $0.min() ?? 0 },
        "max": Function(minArgs: 1, maxArgs: Int.max) { $0.max() ?? 0 },
        "clamp": Function(minArgs: 3, maxArgs: 3) { Swift.min(Swift.max($0[0], $0[1]), $0[2]) },
        "mod": binary { $0.truncatingRemainder(dividingBy: $1) },

        // Convert angles for anyone who thinks in degrees
        "radians": unary { $0 * Double.pi / 180 },
        "degrees": unary { $0 * 180 / Double.pi }
    ]
}

// MARK: Syntax Repair

// Scan parentheses with a stack to validate and repair input
enum ExpressionSyntax {

    // Hold the three components of a vector field alongside notes about any repairs
    struct Components {
        let expressions: [String]
        let notes: [String]
    }

    // Return whatever parentheses are left open after walking the string with a stack
    private static func scan(_ input: String) throws -> [Int] {
        var stack: [Int] = []

        for (offset, character) in input.enumerated() {
            if character == "(" {
                stack.append(offset)
            } else if character == ")" {
                guard !stack.isEmpty else {
                    throw ExpressionError.unmatchedClosingParenthesis(column: offset + 1)
                }
                stack.removeLast()
            }
        }

        return stack
    }

    // Find the closer matching an opening parenthesis at the start of the string
    private static func indexOfMatchingClose(forOpenAtStartOf input: String) -> String.Index? {
        guard input.first == "(" else { return nil }

        var depth = 0
        var index = input.startIndex

        while index < input.endIndex {
            let character = input[index]
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = input.index(after: index)
        }

        return nil
    }

    // Split on commas at parenthesis depth zero so a call with two arguments stays whole
    static func splitTopLevel(_ input: String, separator: Character = ",") -> [String] {
        var pieces: [String] = []
        var current = ""
        var depth = 0

        for character in input {
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
            }

            if character == separator && depth == 0 {
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        pieces.append(current)
        return pieces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    // Close every parenthesis the stack says is still open by appending to the end
    private static func closingOpenParentheses(_ input: String) throws -> String {
        let leftovers = try scan(input)
        guard !leftovers.isEmpty else { return input }
        return input + String(repeating: ")", count: leftovers.count)
    }

    // Peel off parentheses that wrap the whole field only when they hide the commas
    private static func unwrappingOuterParentheses(_ input: String) -> String {
        var text = input
        var candidate = input

        // Commit only to a layer that exposes commas so a single wrapped component survives
        while let closingIndex = indexOfMatchingClose(forOpenAtStartOf: candidate),
              closingIndex == candidate.index(before: candidate.endIndex) {
            candidate = String(candidate.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            if splitTopLevel(candidate).count > 1 { text = candidate }
        }

        return text
    }

    // Turn a raw field string into its three components and repair what can be repaired
    static func components(of input: String) throws -> Components {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExpressionError.empty }

        var notes: [String] = []

        // Close everything at the end then split on top level commas
        let closed = try closingOpenParentheses(trimmed)
        let text = unwrappingOuterParentheses(closed)
        let parts = splitTopLevel(text)

        if closed != trimmed { notes.append("A missing closing parenthesis was added for you.") }
        if text != closed { notes.append("The parentheses around the whole vector field were removed.") }

        if parts.count == 3 {
            return Components(expressions: parts, notes: notes)
        }

        // Otherwise split on every comma and balance each piece as its own component
        if closed != trimmed {
            let pieces = trimmed.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if pieces.count == 3, let repaired = try? pieces.map({ try closingOpenParentheses($0) }) {
                return Components(expressions: repaired,
                                  notes: ["A missing closing parenthesis was added for you."])
            }
        }

        throw ExpressionError.wrongComponentCount(parts.count)
    }
}

// MARK: Tokenizer

// Represent the smallest pieces an expression is made of
private enum Token: Equatable {
    case number(Double)
    case identifier(String)
    case symbol(Character)

    // Describe this token for when it shows up somewhere it should not
    var description: String {
        switch self {
        case .number(let value): return "\(value)"
        case .identifier(let name): return name
        case .symbol(let character): return String(character)
        }
    }
}

private enum Tokenizer {

    private static let operators: Set<Character> = ["+", "-", "*", "/", "%", "^", "(", ")", ","]

    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        let characters = Array(input)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            // Skip whitespace since it only ever separates tokens
            if character.isWhitespace {
                index += 1
                continue
            }

            // Read numbers including a decimal point and scientific notation
            if character.isNumber || (character == "." && index + 1 < characters.count && characters[index + 1].isNumber) {
                var literal = ""

                while index < characters.count, characters[index].isNumber || characters[index] == "." {
                    literal.append(characters[index])
                    index += 1
                }

                // Treat e as an exponent only when actual digits follow it
                if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                    var lookahead = index + 1
                    if lookahead < characters.count, characters[lookahead] == "+" || characters[lookahead] == "-" {
                        lookahead += 1
                    }
                    if lookahead < characters.count, characters[lookahead].isNumber {
                        while index < characters.count, index <= lookahead || characters[index].isNumber {
                            literal.append(characters[index])
                            index += 1
                        }
                    }
                }

                guard let value = Double(literal) else {
                    throw ExpressionError.unexpectedToken(literal)
                }

                tokens.append(.number(value))
                continue
            }

            // Read a name that could be a function or constant or variable
            if character.isLetter || character == "_" {
                var name = ""

                while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" {
                    name.append(characters[index])
                    index += 1
                }

                tokens.append(.identifier(name.lowercased()))
                continue
            }

            // Handle single character symbols that need no lookahead
            if operators.contains(character) {
                tokens.append(.symbol(character))
                index += 1
                continue
            }

            throw ExpressionError.unexpectedCharacter(character)
        }

        return tokens
    }
}

// MARK: Compiled Expression

// Hold a parsed expression ready to evaluate at as many points as needed
struct CompiledExpression {
    let source: String
    private let body: (Double, Double, Double) -> Double

    fileprivate init(source: String, body: @escaping (Double, Double, Double) -> Double) {
        self.source = source
        self.body = body
    }

    // Evaluate at a point and return nil when the result is not a usable number
    func value(x: Double, y: Double, z: Double) -> Double? {
        let result = body(x, y, z)
        return result.isFinite ? result : nil
    }
}

// MARK: Parser

// Compile an expression into a closure and throw a Swift error on anything invalid
struct ExpressionParser {

    private let tokens: [Token]
    private var position = 0

    private init(tokens: [Token]) {
        self.tokens = tokens
    }

    // Compile text into an evaluable expression as the single entry point
    static func compile(_ expression: String) throws -> CompiledExpression {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExpressionError.empty }

        var parser = ExpressionParser(tokens: try Tokenizer.tokenize(trimmed))
        let body = try parser.parseExpression()

        // Anything left over means the expression did not read as a single value
        if let leftover = parser.peek() {
            throw ExpressionError.unexpectedToken(leftover.description)
        }

        return CompiledExpression(source: trimmed, body: body)
    }

    // MARK: Token Helpers

    private func peek() -> Token? {
        position < tokens.count ? tokens[position] : nil
    }

    private mutating func advance() {
        position += 1
    }

    private mutating func match(_ character: Character) -> Bool {
        guard peek() == .symbol(character) else { return false }
        advance()
        return true
    }

    private mutating func expect(_ character: Character) throws {
        guard match(character) else {
            throw ExpressionError.unexpectedToken(peek()?.description ?? "end of expression")
        }
    }

    // MARK: Grammar

    private typealias Node = (Double, Double, Double) -> Double

    // Parse a run of terms joined by plus or minus
    private mutating func parseExpression() throws -> Node {
        var left = try parseTerm()

        while let token = peek(), token == .symbol("+") || token == .symbol("-") {
            let isAddition = token == .symbol("+")
            advance()
            let right = try parseTerm()
            let lhs = left
            left = isAddition ? { lhs($0, $1, $2) + right($0, $1, $2) }
                              : { lhs($0, $1, $2) - right($0, $1, $2) }
        }

        return left
    }

    // Parse a run of values joined by multiplication or division or remainder
    private mutating func parseTerm() throws -> Node {
        var left = try parseUnary()

        while let token = peek() {
            let lhs = left

            if token == .symbol("*") {
                advance()
                let right = try parseUnary()
                left = { lhs($0, $1, $2) * right($0, $1, $2) }
            } else if token == .symbol("/") {
                advance()
                let right = try parseUnary()
                left = { lhs($0, $1, $2) / right($0, $1, $2) }
            } else if token == .symbol("%") {
                advance()
                let right = try parseUnary()
                left = { lhs($0, $1, $2).truncatingRemainder(dividingBy: right($0, $1, $2)) }
            } else if startsAValue(token) {
                // Multiply implicitly so values written next to each other mean what they look like
                let right = try parseUnary()
                left = { lhs($0, $1, $2) * right($0, $1, $2) }
            } else {
                break
            }
        }

        return left
    }

    // Report whether a token can begin a value which keeps implicit multiplication safe
    private func startsAValue(_ token: Token) -> Bool {
        switch token {
        case .number, .identifier: return true
        case .symbol(let character): return character == "("
        }
    }

    // Parse a leading plus or minus in front of a power
    private mutating func parseUnary() throws -> Node {
        if match("-") {
            let operand = try parseUnary()
            return { -operand($0, $1, $2) }
        }

        if match("+") {
            return try parseUnary()
        }

        return try parsePower()
    }

    // Parse a power as right associative so the exponent itself can be negative
    private mutating func parsePower() throws -> Node {
        let base = try parsePrimary()

        guard match("^") else { return base }

        let exponent = try parseUnary()
        return { x, y, z in
            let baseValue = base(x, y, z)
            let exponentValue = exponent(x, y, z)

            // Handle the negative bases where pow would return NaN but the result is real
            if baseValue < 0 {
                // Follow the parity of an integer exponent to get the sign
                if exponentValue == exponentValue.rounded() {
                    let magnitude = Foundation.pow(-baseValue, exponentValue)
                    return exponentValue.truncatingRemainder(dividingBy: 2) == 0 ? magnitude : -magnitude
                }

                // Handle an odd root written as a fraction such as one third
                let reciprocal = 1 / exponentValue
                let rounded = reciprocal.rounded()
                if Swift.abs(reciprocal - rounded) < 1e-9, rounded.truncatingRemainder(dividingBy: 2) != 0 {
                    return -Foundation.pow(-baseValue, exponentValue)
                }
            }

            return Foundation.pow(baseValue, exponentValue)
        }
    }

    // Parse a number or constant or variable or call or parenthesised expression
    private mutating func parsePrimary() throws -> Node {
        guard let token = peek() else { throw ExpressionError.missingOperand }

        switch token {
        case .number(let value):
            advance()
            return { _, _, _ in value }

        case .identifier(let name):
            advance()
            return try resolveIdentifier(name)

        case .symbol("("):
            advance()
            let inner = try parseExpression()
            try expect(")")
            return inner

        case .symbol(let character):
            throw ExpressionError.unexpectedToken(String(character))
        }
    }

    // Turn a name into a function call or constant or variable or product of variables
    private mutating func resolveIdentifier(_ name: String) throws -> Node {
        // Treat a name followed by an opening parenthesis as a call
        if peek() == .symbol("(") {
            guard let function = MathLibrary.functions[name] else {
                throw ExpressionError.unknownSymbol(name)
            }

            advance()
            var arguments: [Node] = []

            if !match(")") {
                repeat {
                    arguments.append(try parseExpression())
                } while match(",")
                try expect(")")
            }

            guard arguments.count >= function.minArgs, arguments.count <= function.maxArgs else {
                throw ExpressionError.wrongArgumentCount(name: name,
                                                         expected: function.arityDescription,
                                                         found: arguments.count)
            }

            let apply = function.apply
            return { x, y, z in apply(arguments.map { $0(x, y, z) }) }
        }

        // Look up a bare constant
        if let constant = MathLibrary.constants[name] {
            return { _, _, _ in constant }
        }

        // Look up a bare variable
        if name.count == 1, let character = name.first, MathLibrary.variables.contains(character) {
            switch character {
            case "x": return { x, _, _ in x }
            case "y": return { _, y, _ in y }
            default:  return { _, _, z in z }
            }
        }

        // Multiply a run of variables written together so xy means x times y
        if name.allSatisfy({ MathLibrary.variables.contains($0) }) {
            let characters = Array(name)
            return { x, y, z in
                characters.reduce(1.0) { product, character in
                    switch character {
                    case "x": return product * x
                    case "y": return product * y
                    default:  return product * z
                    }
                }
            }
        }

        // Give a more specific hint for a known function name used without parentheses
        if MathLibrary.functions[name] != nil {
            throw ExpressionError.functionNeedsParentheses(name)
        }

        throw ExpressionError.unknownSymbol(name)
    }
}
