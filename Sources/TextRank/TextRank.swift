//
//  File.swift
//
//
//  Created by Joshua on 1/1/21.
//

import Foundation

public class TextRank {
    public var text: String {
        didSet {
            textToSentences()
        }
    }

    public var graph: TextGraph
    public var sentences = [Sentence]()
    public var summarizationFraction: Float = 0.2
    public var graphDamping: Float = 0.85
    public var stopwords = [String]() {
        didSet {
            textToSentences()
        }
    }

    public init() {
        text = ""
        graph = TextGraph(damping: graphDamping)
    }

    public init(text: String) {
        self.text = text
        graph = TextGraph(damping: graphDamping)
        textToSentences()
    }

    public init(text: String, summarizationFraction: Float = 0.2, graphDamping: Float = 0.85) {
        self.text = text
        self.summarizationFraction = summarizationFraction
        self.graphDamping = graphDamping
        graph = TextGraph(damping: graphDamping)
        textToSentences()
    }

    func textToSentences() {
        sentences = TextRank.splitIntoSentences(text, additionalStopwords: stopwords).filter { $0.length > 0 }
    }
}

extension TextRank {
    public func runPageRank() throws -> TextGraph.PageRankResult {
        buildGraph()
        return try graph.runPageRank()
    }

    /// Build the TextGraph using the sentences as nodes.
    func buildGraph() {
        graph.clearGraph()
        var numberOfErrors = 0
        for (i, s1) in sentences.enumerated() {
            for s2 in sentences[(i + 1) ..< sentences.count] {
                do {
                    try graph.addEdge(from: s1, to: s2, withWeight: similarity(s1, s2))
                } catch {
                    numberOfErrors += 1
                }
            }
        }
    }

    /// Calculate the similarity of two senntences.
    /// - Parameters:
    ///   - a: First sentence.
    ///   - b: Second sentence.
    /// - Returns: Returns a float for how simillar the two sentences are. The larger the greater
    ///   simillarity, the greater the value. Zero is the minimum value.
    func similarity(_ a: Sentence, _ b: Sentence) -> Float {
        if a.words.count == 0 || b.words.count == 0 { return 0.0 }
        let commonWordCount = Float(a.words.intersection(b.words).count)
        let totalWordCount = log10(Float(a.words.count)) + log10(Float(b.words.count))
        return totalWordCount == 0.0 ? 0.0 : commonWordCount / totalWordCount
    }
}

extension TextRank {
    /// Split text into sentences.
    /// - Parameter text: Original text.
    /// - Returns: An array of sentences.
    static func splitIntoSentences(_ text: String, additionalStopwords stopwords: [String] = [String]()) -> [Sentence] {
        if text.isEmpty { return [] }
        
        let sentences = text.sentences()
        var x = [Sentence]()
        
        for sentence in sentences {
            x.append(Sentence(text: sentence, originalTextIndex: x.count, additionalStopwords: stopwords))
        }
        
//        text.enumerateSubstrings(in: text.range(of: text)!, options: [.bySentences, .localized]) { substring, _, _, _ in
//            if let substring = substring, !substring.isEmpty {
//                x.append(
//                    Sentence(text: substring.trimmingCharacters(in: .whitespacesAndNewlines),
//                             originalTextIndex: x.count,
//                             additionalStopwords: stopwords)
//                )
//            }
//        }
        return Array(Set(x))
    }
}

// Filtering and organizing ranked results.
public extension TextRank {
    /// Filter the results of PageRank by percentile.
    /// - Parameters:
    ///   - results: The results of running PageRank.
    ///   - percentile: The top percentile to filter.
    /// - Returns: A node list of only the top percentile requested.
    func filterTopSentencesFrom(_ results: TextGraph.PageRankResult, top percentile: Float) -> TextGraph.NodeList {
        let idx = Int(Float(results.results.count) * percentile)
        let cutoffScore: Float = results.results.values.sorted()[min(idx, results.results.count - 1)]
        var filteredNodeList: TextGraph.NodeList = [:]
        for (sentence, value) in results.results {
            if value >= cutoffScore {
                filteredNodeList[sentence] = value
            }
        }
        return filteredNodeList
    }
}


extension String {
    func sentences() -> [String] {
        // A very basic implementation using punctuation to split sentences
        // This can be improved or made more sophisticated based on your requirements
        let pattern = "[.!?]"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = self as NSString
        let range = NSRange(location: 0, length: nsString.length)

        var start = 0
        var sentences = [String]()

        regex.enumerateMatches(in: self, options: [], range: range) { (match, _, _) in
            if let match = match {
                let sentence = nsString.substring(with: NSRange(location: start, length: match.range.location - start)).trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                start = match.range.location + match.range.length
            }
        }

        // Add the last sentence if there is any
        let lastSentence = nsString.substring(from: start).trimmingCharacters(in: .whitespaces)
        if !lastSentence.isEmpty {
            sentences.append(lastSentence)
        }

        return sentences
    }
}
