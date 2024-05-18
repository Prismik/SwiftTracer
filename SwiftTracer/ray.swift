//
//  ray.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation

struct Ray {
    let o: Point3
    let d: Vec3
    let tMin: Float
    let tMax: Float
    
    init() {
        self.init(origin: Point3(0, 0, 0), direction: Vec3())
    }

    init(origin: Point3, direction: Vec3) {
        self.o = origin
        self.d = direction
        self.tMin = 0.0001
        self.tMax = Float.greatestFiniteMagnitude
    }
    
    func pointAt(t: Float) -> Point3 {
        return self.o + t * self.d
    }
}
