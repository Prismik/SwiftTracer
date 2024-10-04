//
//  distribution.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-28.
//

import Foundation

struct DistributionOneDimention {
    private(set) var elements: [Float] = []
    private(set) var cdf: [Float] = []

    init(count: Int) {
        elements.reserveCapacity(count)
    }
    
    mutating func add(_ element: Float) {
        elements.append(element)
    }
    
    mutating func normalize() {
        cdf.reserveCapacity(elements.count + 1)
        var current: Float = 0
        let count = Float(elements.count)
        for e in elements {
            cdf.append(current)
            current += e / count
        }
        
        if current != 0 {
            cdf = cdf.map { $0 / current }
        }
        
        cdf.removeLast()
        cdf.append(1.0)
    }
    
    func sampleDiscrete(_ value: Float) -> Int {
        switch cdf.binarySearch(value) {
        case (let v, true):
            return v
        case (let v, false):
            return max(v - 1, 0)
        }
    }
}
