//
//  material.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import simd
import Foundation

protocol Material {
    func sample(wo: Vec3)
    func evaluate()
    func pdf()
}

extension Material {
    static func from(json: Data) {
        
    }
}
