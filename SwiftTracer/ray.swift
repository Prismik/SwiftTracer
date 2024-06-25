//
//  ray.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation

public class Ray {
    struct Distance {
        let min: Float
        let max: Float
        
        func with(min: Float) -> Distance {
            return Distance(min: min, max: max)
        }
        
        func with(max: Float) -> Distance {
            return Distance(min: min, max: max)
        }

        var range: ClosedRange<Float> { min ... max }
    }

    /// Origin
    let o: Point3
    /// Direction
    let d: Vec3
    
    var t: Distance
    
    convenience init() {
        self.init(origin: Point3(0, 0, 0), direction: Vec3())
    }

    init(origin: Point3, direction: Vec3) {
        self.o = origin
        self.d = direction
        self.t = Distance(min: 0.0001, max: Float.greatestFiniteMagnitude)
    }
    
    func with(min: Float) -> Self {
        self.t = t.with(min: min)
        return self
    }

    func with(max: Float) -> Self {
        self.t = t.with(max: max)
        return self
    }

    func withinRange(min: Float, max: Float) -> Self {
        self.t = Distance(min: min, max: max)
        return self
    }

    func pointAt(t: Float) -> Point3 {
        return self.o + t * self.d
    }
}
