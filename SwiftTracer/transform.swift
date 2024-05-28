//
//  transform.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-17.
//

import Foundation
import simd

struct Transform {
    let m: Mat4
    let mInv: Mat4
    
    /*
    private let translation: Vec3
    private let scale: Vec3
    private let rotation: Mat3
    */
    
    init(m: Mat4) {
        self.init(m: m, mInv: m.inverse)
    }
    
    private init(m: Mat4, mInv: Mat4) {
        self.m = m
        self.mInv = mInv
        
        /*
        let col1 = m[0]
        let col2 = m[1]
        let col3 = m[2]
        let col4 = m[3]
        self.translation = Vec3(col4[0], col4[1], col4[2])
        
        
        let sx = Vec3(col1[0], col1[1], col1[2]).length
        let sy = Vec3(col2[0], col2[1], col2[2]).length
        let sz = Vec3(col3[0], col3[1], col3[2]).length
        self.scale = Vec3(sx, sy, sz)
        
        self.rotation = Mat3(
            SIMD3<Float>.init(col1[0] / sx, col1[1] / sx, col1[2] / sx),
            SIMD3<Float>.init(col2[0] / sy, col2[1] / sy, col2[2] / sy),
            SIMD3<Float>.init(col3[0] / sz, col3[1] / sz, col3[2] / sz)
        )
         */
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
    // TODO Move into custom mat4 decoding?
    init(from decoder: Decoder) throws {
        do {
            let matrix = try Mat4(from: decoder)
            self.init(m: matrix)
        } catch {
            self.init(m: Mat4.identity(), mInv: Mat4.identity())
        }
    }
}
