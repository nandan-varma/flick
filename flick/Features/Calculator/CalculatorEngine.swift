import Foundation

enum CalculatorEngine {
    private static let expressionRegex = try! NSRegularExpression(pattern: #"^[\d\s\+\-\*\/\(\)\.\%\^]+$"#)
    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.maximumSignificantDigits = 10
        f.usesSignificantDigits = true
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        return f
    }()

    private static func sanitize(_ query: String) -> String {
        var s = query.trimmingCharacters(in: .whitespaces)
        if s.hasSuffix("=") { s = String(s.dropLast()).trimmingCharacters(in: .whitespaces) }
        return s
    }

    static func isExpression(_ query: String) -> Bool {
        let s = sanitize(query)
        guard s.count >= 2 else { return false }
        let range = NSRange(s.startIndex..., in: s)
        return expressionRegex.firstMatch(in: s, range: range) != nil
    }

    static func evaluate(_ query: String) -> String? {
        let s = sanitize(query)
        guard !s.isEmpty else { return nil }
        let formatted = s.replacingOccurrences(of: "^", with: "**")
        let expr = NSExpression(format: formatted)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else { return nil }
        let v = result.doubleValue
        guard !v.isNaN, !v.isInfinite else { return nil }
        if v.truncatingRemainder(dividingBy: 1) == 0 { return String(Int64(v)) }
        return decimalFormatter.string(from: result)
    }
}
