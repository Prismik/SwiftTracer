//
//  rngTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-09-28.
//

import XCTest
@testable import SwiftTracer

final class RngTest: XCTestCase {
    func testSameSeedYieldsSameResult() {
        var rng1 = RNG(seed: 125)
        var rng2 = RNG(seed: 125)
        
        XCTAssert(rng1.next() == rng2.next())
    }
    
    func testDifferentSeedYieldsDifferentResult() {
        var rng1 = RNG(seed: 125)
        var rng2 = RNG(seed: 129)
        
        let n1 = rng1.next()
        let n2 = rng2.next()
        XCTAssert(n1 != n2)
    }
}
