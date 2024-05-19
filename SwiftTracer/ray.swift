//
//  ray.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation

class Ray {
    struct Distance {
        let min: Float
        let max: Float
    }

    /// Origin
    let o: Point3
    /// Direction
    let d: Vec3
    private(set) var t: Distance
    
    convenience init() {
        self.init(origin: Point3(0, 0, 0), direction: Vec3())
    }

    init(origin: Point3, direction: Vec3) {
        self.o = origin
        self.d = direction
        self.t = Distance(min: 0.0001, max: Float.greatestFiniteMagnitude)
    }
    
    func withinRange(min: Float, max: Float) -> Self {
        self.t = Distance(min: min, max: max)
        return self
    }

    func pointAt(t: Float) -> Point3 {
        return self.o + t * self.d
    }
}
