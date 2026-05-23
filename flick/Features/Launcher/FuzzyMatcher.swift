import Foundation

enum FuzzyMatcher {
    static func score(query: String, against target: String) -> Double {
        guard !query.isEmpty else { return 1.0 }

        let q = query.lowercased()
        let t = target.lowercased()

        let tChars = Array(t)
        let qChars = Array(q)

        var matchedIndices: [Int] = []
        var tIndex = 0

        for ch in qChars {
            var found = false
            while tIndex < tChars.count {
                if tChars[tIndex] == ch {
                    matchedIndices.append(tIndex)
                    tIndex += 1
                    found = true
                    break
                }
                tIndex += 1
            }
            if !found { return 0 }
        }

        var score = 1.0

        for i in 1 ..< matchedIndices.count where matchedIndices[i] == matchedIndices[i - 1] + 1 {
            score += 0.1
        }

        if t.hasPrefix(q) {
            score += 0.5
        }

        score /= Double(tChars.count)

        return score
    }

    static func bestScore(query: String, title: String, keywords: [String]) -> Double {
        let titleScore = score(query: query, against: title)
        let kwScore = keywords.map { score(query: query, against: $0) }.max() ?? 0
        return max(titleScore, kwScore)
    }
}
