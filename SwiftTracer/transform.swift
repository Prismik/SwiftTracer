//
//  transform.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation
import simd

struct AnyTransform {
    
}

struct Transform {
    enum GenericKey: String, CodingKey {
        case transform
    }

    let m: Mat4
    let mInv: Mat4
    
    init(m: Mat4) {
        self.init(m: m, mInv: m.inverse)
    }
    
    private init(m: Mat4, mInv: Mat4) {
        self.m = m
        self.mInv = mInv
    }
    
    func inverse() -> Transform {
        return Transform(m: mInv, mInv: m)
    }
    
    func vector(_ v: Vec3) -> Vec3 {
        return (m * v.extend(scalar: 0)).truncate()
    }
    
    func normal(_ n: Vec3) -> Vec3 {
        return (mInv.transpose * n.extend(scalar: 0)).truncate()
    }
    
    func point(_ p: Point3) -> Point3 {
        let v = m * p.toHomogeneous()
        return Point3.fromHomogeneous(vector: v)
    }
    
    func ray(_ r: Ray) -> Ray {
        return Ray(
            origin: point(r.o),
            direction: vector(r.d)
        ).withinRange(min: r.t.min, max: r.t.max)
    }
}

extension Transform: Decodable {
    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            let matrices = try container.decode([Mat4].self)
            var result = Mat4.identity()
            for m in matrices {
                result = m * result
            }
            
            self.init(m: result)
        } catch {
            // Only one matrix-transform
            let matrix = try Mat4(from: decoder)
            self.init(m: matrix)
        }
    }
}
