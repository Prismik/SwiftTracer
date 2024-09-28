//
//  rng.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-28.
//

import Foundation

// Based on https://github.com/lemire/SwiftWyhash/tree/master
public struct RNG: RandomNumberGenerator {
    var state : UInt64

    public init(seed : UInt64) {
        state = seed
    }
    
    public init() {
        state = UInt64.random(in: 0 ... UInt64.max)
    }

    public mutating func next() -> UInt64 {
        state &+= 0xa0761d6478bd642f
        let mul = state.multipliedFullWidth(by: state ^ 0xe7037ed1a0b428db)
        return mul.high ^ mul.low
    }
}
