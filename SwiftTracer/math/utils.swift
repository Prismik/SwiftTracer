//
//  utils.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-20.
//

import Foundation
import Progress

enum Utils {
    static func directionFrom(phi: Float, theta: Float) -> Vec3 {
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        
        return Vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta)
    }
    
    static func sphericalCoordinatesFrom(direction: Vec3) -> (Float, Float) {
        let t = direction.z.acos()
        if t.isNaN || t.isInfinite {
            print("Error in spherical coordinates")
            print("z: \(direction.z)")
        }
        return (atan2f(-direction.y, -direction.x) + .pi, direction.z.acos())
    }
    
    static func pixelToDirection(p: Vec2, imageSize: Vec2) -> Vec3 {
        return directionFrom(
            phi: p.x * 2 * .pi / imageSize.x,
            theta: p.y * .pi / imageSize.y
        )
    }
    
    static func directionToPixel(d: Vec3, imageSize: Vec2) -> Vec2 {
        let sc = sphericalCoordinatesFrom(direction: d)
        return Vec2(
            sc.0 * imageSize.x / (2 * .pi),
            sc.1 * imageSize.y / .pi
        )
    }

    static func generateHistogram(pdfFunc: (Vec3) -> Float, sampleFunc: (Vec2) -> Vec3, nsp: Int, sampler: Sampler) -> (Array2d<Color>, Array2d<Color>, Array2d<Color>) {
        let imageSize = Vec2(512, 256)
        var integral: Float = 0
        let pdf = Array2d(x: Int(imageSize.x), y: Int(imageSize.y), value: Float(0))
        var nanOrInf = false
        for y in Progress(0 ..< Int(imageSize.y)) {
            for x in 0 ..< Int(imageSize.x) {
                var accumulator: Float = 0
                for _ in 0 ..< nsp {
                    let imagePosition = Vec2(Float(x), Float(y)) + sampler.next2()
                    let direction = pixelToDirection(p: imagePosition, imageSize: imageSize)
                    let sinTheta: Float = max(1 - direction.z * direction.z, 0).squareRoot()
                    let pixelArea: Float = .pi / imageSize.y
                        * .pi * 2 / imageSize.x
                        * sinTheta
                    let pdfValue = pdfFunc(direction)
                    if pdfValue.isInfinite || pdfValue.isNaN {
                        print("PDF is NaN or Inf at (\(x), \(y))")
                        nanOrInf = true
                        continue
                    }
                    
                    accumulator += pdfValue
                    integral += pdfValue * pixelArea
                }
                
                pdf.set(value: accumulator / Float(nsp), x, y)
            }
        }
        
        integral /= Float(nsp)
        
        // compute histogram
        let histogram = Array2d(x: Int(imageSize.x), y: Int(imageSize.y), value: Float(0))
        let normalisation: Float = 1 / (.pi * 2 * .pi * Float(nsp))
        for _ in Progress(0 ..< Int(imageSize.y)) {
            for _ in 0 ..< Int(imageSize.x) {
                for _ in 0 ..< nsp {
                    let rnd = sampler.next2()
                    let direction = sampleFunc(rnd)
                    let isInfinite = direction.x.isInfinite || direction.y.isInfinite || direction.z.isInfinite
                    let isNan = direction.x.isNaN || direction.y.isNaN || direction.z.isNaN
                    if isInfinite && !isNan {
                        if !nanOrInf {
                            print("Invalid sample for random number: \(rnd)")
                        }
                        nanOrInf = true
                        continue
                    }
                    
                    if direction.dot(direction) == 0 {
                        continue
                    }
                    
                    let pixel = directionToPixel(d: direction, imageSize: imageSize)
                    if pixel.x >= imageSize.x || pixel.y >= imageSize.y {
                        continue
                    }
                    
                    let sinTheta: Float = max(1 - direction.z * direction.z, 0).squareRoot()
                    let weight = normalisation / sinTheta
                    let current = histogram.get(Int(pixel.x), Int(pixel.y))
                    histogram.set(value: current + weight, Int(pixel.x), Int(pixel.y))
                }
            }
        }
        
        var pdf1d = Array(repeating: Float(0), count: Int(imageSize.x) * Int(imageSize.y))
        for y in 0 ..< Int(imageSize.y) {
            for x in 0 ..< Int(imageSize.x) {
                pdf1d[y * Int(imageSize.x) + x] = pdf.get(x, y)
            }
        }
        pdf1d.sort()
        var exposure = pdf1d[Int(Float(pdf1d.count) * 0.9995)]
        if exposure == 0 {
            exposure = 1
        }
        
        func color(_ t: Float) -> Color {
            let c0 = Color(0.2777273272234177, 0.005407344544966578, 0.3340998053353061)
            let c1 = Color(0.1050930431085774, 1.404613529898575, 1.384590162594685)
            let c2 = Color(-0.3308618287255563, 0.214847559468213, 0.09509516302823659)
            let c3 = Color(-4.634230498983486, -5.799100973351585, -19.33244095627987)
            let c4 = Color(6.228269936347081, 14.17993336680509, 56.69055260068105)
            let c5 = Color(4.776384997670288, -13.74514537774601, -65.35303263337234)
            let c6 = Color(-5.435455855934631, 4.645852612178535, 26.3124352495832)

            let a = t * (c5 + t * c6)
            let b = c4 + a
            let c = c3 + t * b
            let d = c2 + t * c
            let e = c1 + t * d
            return c0 + t * e
        }

        let histogramImage = Array2d(x: Int(imageSize.x), y: Int(imageSize.y), value: Color())
        let pdfImage = Array2d(x: Int(imageSize.x), y: Int(imageSize.y), value: Color())
        let diffImage = Array2d(x: Int(imageSize.x), y: Int(imageSize.y), value: Color())
        var difference: Float = 0
        for y in 0 ..< Int(imageSize.y) {
            for x in 0 ..< Int(imageSize.x) {
                let pdfVal = pdf.get(x, y)
                let histogramVal = histogram.get(x, y)
                let diff = pdfVal - histogramVal
                difference += diff
                
                let pdfColor = color(pdfVal / exposure)
                let histogramColor = color(histogramVal / exposure)
                let diffColor = diff < 0
                    ? Color(-diff / exposure, 0, 0)
                    : Color(0, diff / exposure, 0)
                
                pdfImage.set(value: pdfColor, x, y)
                histogramImage.set(value: histogramColor, x, y)
                diffImage.set(value: diffColor, x, y)
            }
        }
        
        return (pdfImage, histogramImage, diffImage)
    }
}

extension Float {
    var isPair: Bool {
        return self.truncatingRemainder(dividingBy: 2) == 0
    }

    func toRadians() -> Self {
        return self * Float.pi / 180
    }
    
    func clamped(_ lower: Float, _ upper: Float) -> Float {
        let t = self < lower ? lower : self
        return t > upper ? upper : t
    }
    
    func pow(_ n: Float) -> Float {
        return Darwin.pow(self, n)
    }
    
    func acos() -> Float {
        return Darwin.acos(self)
    }
    
    func cos() -> Float {
        return Darwin.cos(self)
    }
    
    func sin() -> Float {
        return Darwin.sin(self)
    }
    
    func abs() -> Float {
        return Swift.abs(self)
    }
    
    func modulo(_ other: Float) -> Float {
        let r = self.truncatingRemainder(dividingBy: other)
        return r < 0
            ? r + other
            : r
    }
}
