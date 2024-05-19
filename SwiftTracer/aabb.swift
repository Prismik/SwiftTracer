//
//  aabb.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

struct AABB {
    var min: Point3
    var max: Point3
    
    init() {
        self.init(
            min: Point3(Float.infinity, Float.infinity, Float.infinity),
            max: Point3(-Float.infinity, -Float.infinity, -Float.infinity) // TODO Double check
        )
    }
    
    init(min: Point3, max: Point3) {
        self.min = min
        self.max = max
    }
    
    mutating func extend(with other: Point3) {
        self.min.x = Swift.min(self.min.x, other.x)
        self.min.y = Swift.min(self.min.y, other.y)
        self.min.z = Swift.min(self.min.z, other.z)
        
        self.max.x = Swift.max(self.max.x, other.x)
        self.max.y = Swift.max(self.max.y, other.y)
        self.max.z = Swift.max(self.max.z, other.z)
    }
    
    /// Compute intersection with bounding box
    ///
    /// See http://psgraphics.blogspot.de/2016/02/new-simple-ray-box-test-from-andrew.html
    func hit(r: Ray) -> Float? {
        var tMin = r.t.min
        var tMax = r.t.max
        
        for d in 0..<3 {
            // Inverse ray distance (can be optimized if this information is cached inside the ray structure)
            let dInv = 1 / r.d[d]
            
            var t0 = (self.min[d] - r.o[d]) * dInv
            var t1 = (self.max[d] - r.o[d]) * dInv
            
            // When the direction is inverse, we will hit the plane "max" before "min".
            // Thus, we will swap the two distances so t0 is always the minimum.
            if dInv < 0 {
                swap(&t0, &t1)
            }
            
            
            tMin = Swift.max(tMin, t0)
            tMax = Swift.min(tMax, t1)
            
            guard tMin < tMax else { return nil }
        }
        
        return tMin
    }

    func center() -> Point3 {
        return 0.5 * Point3(
            self.min.x + self.max.x,
            self.min.y + self.max.y,
            self.min.z + self.max.z
        )
    }

    func diagonal() -> Vec3 {
        return self.max - self.min
    }
    
    func area() -> Float {
        let e = diagonal()
        return 2 * (e.x * e.y + e.y * e.z + e.z * e.x)
    }

    func sanitized() -> Self {
        var copy = self
        let diagonal = copy.diagonal()
        for i in 0..<3 {
            if diagonal[i] < 2e-4 {
                copy.min[i] -= 1e-4
                copy.max[i] += 1e-4
            }
        }
        
        return copy
    }
    
    func merge(with other: AABB) -> Self {
        return AABB(
            min: Point3(
                Swift.min(self.min.x, other.min.x),
                Swift.min(self.min.y, other.min.y),
                Swift.min(self.min.z, other.min.z)
            ),
            max: Point3(
                Swift.max(self.max.x, other.max.x),
                Swift.max(self.max.y, other.max.y),
                Swift.max(self.max.z, other.max.z)
            )
        )
    }
}
