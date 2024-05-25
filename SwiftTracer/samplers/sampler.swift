//
//  sampler.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

protocol Sampler {
    func next() -> Float
    func next2() -> Vec2
    
    var nbSamples: Int { get }
}
