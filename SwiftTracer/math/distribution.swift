//
//  distribution.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-09-28.
//

import Foundation

struct DistributionOneDimention {
    private(set) var elements: [Float] = []
    private(set) var cdf: [Float] = []
    private(set) var integral: Float = 0

    init(count: Int) {
        elements.reserveCapacity(count)
    }
    
    mutating func add(_ element: Float) {
        elements.append(element)
    }
    
    mutating func normalize() {
        cdf.reserveCapacity(elements.count + 1)
        var current: Float = 0
        let count = Float(elements.count)
        for e in elements {
            cdf.append(current)
            current += e / count
        }
        
        if current != 0 {
            cdf = cdf.map { $0 / current }
        }
        
        cdf.removeLast()
        cdf.append(1.0)
        integral = current
    }
    
    func sampleDiscrete(_ value: Float) -> Int {
        switch cdf.binarySearch(value) {
        case (let v, true):
            return v
        case (let v, false):
            return max(v - 1, 0)
        }
    }
    
    func sampleContinuous(_ value: Float) -> Float {
        let i = sampleDiscrete(value)
        let dv = value - cdf[i]
        let pdf = self.pdf(i)
        let adjusted = if pdf > 0 { dv / pdf } else { dv }
        return Float(i) + adjusted
    }
    
    func pdf(_ i: Int) -> Float {
        return cdf[i + 1] - cdf[i]
    }
}

struct DistributionTwoDimension {
    let marginal: DistributionOneDimention
    let conditionals: [DistributionOneDimention]
    
    init(texture: PixelBuffer) {
        var marginal = DistributionOneDimention(count: texture.height)
        self.conditionals = (0 ..< texture.height).map { y in
            var conditional = DistributionOneDimention(count: texture.width)
            for x in (0 ..< texture.width) {
                let pixel: Color = texture[x, y]
                conditional.add(pixel.luminance)
            }
            
            conditional.normalize()
            marginal.add(conditional.integral)
            return conditional
        }
        
        marginal.normalize()
        self.marginal = marginal
    }

    func sampleContinuous(uv: Vec2) -> Vec2 {
        let y = marginal.sampleContinuous(uv.y)
        let x = conditionals[Int(y)].sampleContinuous(uv.x)

        return Vec2(x, y)
    }
    
    func pdf(uv: Vec2) -> Float {
        return conditionals[Int(uv.y)].elements[Int(uv.x)] / marginal.integral
    }
}
