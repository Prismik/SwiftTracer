//
//  cdf.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-06-27.
//

import Foundation

// Cumulative distribution function
struct CDF {
    var total: Float {
        return integral / Float(values.count - 1)
    }

    /// Normalized cumulative probabilities
    /// > Note: 0 is prepended as the zero probability element. Therefore, the size of that array is n + 1.
    private var values: [Float] = []
    /// Raw elements part of the cdf
    private(set) var elements: [Float] = []
    private(set) var integral: Float = 0

    mutating func build() {
        guard elements.count > 0 else { return }
        // Cumulative
        let probs = elements.reduce(into: [0], { acc, e in
            acc.append(e / Float(elements.count))
        })
        
        // Normalize
        guard let last = probs.last else { return }
        self.values = probs[0 ..< probs.count - 1].map { $0 / last }
        self.values.append(1.0)
        self.integral = last
    }
    
    mutating func add(_ element: Float) {
        elements.append(element)
    }

    /// Gets the pdf value for element `i` of the cdf.
    func pdf(_ i: Int) -> Float {
        return values[i + 1] - values[i]
    }
    
    func sample(s: Float) -> Float {
        precondition(s >= 0)
        precondition(s <= 1)
        let index = self.values.last { $0.isLessThanOrEqualTo(s) }
        return index ?? 0
    }
}
