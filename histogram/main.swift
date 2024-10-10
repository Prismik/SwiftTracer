//
//  main.swift
//  histogram
//
//  Created by Francis Beauchamp on 2024-06-10.
//

import Foundation

struct Direction: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
        case theta
        case phi
        case wo
    }

    let name: String
    let wo: Vec3
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        do {
            self.wo = try container.decode(Vec3.self, forKey: .wo)
        } catch {
            let theta = try container.decode(Float.self, forKey: .theta).toRadians()
            let phi = try container.decode(Float.self, forKey: .phi).toRadians()
            self.wo = Vec3(
                theta.sin() * phi.cos(),
                theta.sin() * phi.sin(),
                theta.cos()
            )
        }
    }
}

struct HistogramTest: Decodable {
    enum CodingKeys: String, CodingKey {
        case material
        case directions
    }
    
    let material: Material
    let directions: [Direction]
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let anyMaterial = try container.decode(AnyMaterial.self, forKey: .material)
        let directions = try container.decode([Direction].self, forKey: .directions)
        self.material = anyMaterial.wrapped
        self.directions = directions
    }
}

struct ShapeTest: Decodable {
    enum CodingKeys: String, CodingKey {
        case shapes
    }
    
    let shapes: [Shape]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let anyShapes = try container.decode([AnyShape].self, forKey: .shapes)
        self.shapes = anyShapes.map { $0.unwrapped(materials: ["nd": DiffuseLight(texture: .constant(value: .zero))]) }
    }
}

enum Tests: String {
    case metal
    case sphere
    case quad
    case triangle
    case group

    func create() throws -> Data {
        guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "json", subdirectory: "assets") else {
            fatalError("Trying to load asset that does not exist")
        }
        
        return try Data(contentsOf: url)
    }
}

func generateHistogram(pdfFunc: (Vec3) -> Float, sampleFunc: (Vec2) -> Vec3, nsp: Int, sampler: Sampler) -> (Array2d<Color>, Array2d<Color>, Array2d<Color>) {
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
                let sinTheta: Float = max(1 - direction.z * direction.z, 0).sqrt()
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
            
            pdf[x, y] = accumulator / Float(nsp)
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
                
                let sinTheta: Float = max(1 - direction.z * direction.z, 0).sqrt()
                let weight = normalisation / sinTheta
                let (x, y): (Int, Int) = (Int(pixel.x), Int(pixel.y))
                let current = histogram[x, y]
                histogram[x, y] = current + weight
            }
        }
    }
    
    var pdf1d = Array(repeating: Float(0), count: Int(imageSize.x) * Int(imageSize.y))
    for y in 0 ..< Int(imageSize.y) {
        for x in 0 ..< Int(imageSize.x) {
            pdf1d[y * Int(imageSize.x) + x] = pdf[x, y]
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
            let pdfVal = pdf[x, y]
            let histogramVal = histogram[x, y]
            let diff = pdfVal - histogramVal
            difference += diff
            
            let pdfColor = color(pdfVal / exposure)
            let histogramColor = color(histogramVal / exposure)
            let diffColor = diff < 0
                ? Color(-diff / exposure, 0, 0)
                : Color(0, diff / exposure, 0)
            
            pdfImage[x, y] = pdfColor
            histogramImage[x, y] = histogramColor
            diffImage[x, y] = diffColor
        }
    }
    
    return (pdfImage, histogramImage, diffImage)
}

let data = try Tests.group.create()
let decoder = JSONDecoder()
let sampler: Sampler = IndependantSampler(nspp: 1)
if let test = try? decoder.decode(HistogramTest.self, from: data) {
    for direction in test.directions {
        let (pdf, histogram, diff) = Utils.generateHistogram(pdfFunc: { wi in
            return test.material.pdf(wo: direction.wo, wi: wi, uv: Vec2(), p: Point3())
        }, sampleFunc: { sample in
            if let s = test.material.sample(wo: direction.wo, uv: Vec2(), p: Point3(), sample: sample) {
                return s.wi
            } else {
                return Vec3()
            }
        }, nsp: 50, sampler: sampler)
        
        if !Image(array: pdf).write(to: "\(direction.name)-pdf.png") {
            print("Error saving pnf image")
        }
        
        if !Image(array: histogram).write(to: "\(direction.name)-hist.png") {
            print("Error saving histogram image")
        }
        
        if !Image(array: diff).write(to: "\(direction.name)-diff.png") {
            print("Error saving diff image")
        }
    }
} else {
    let test = try decoder.decode(ShapeTest.self, from: data)
    let shape: Shape
    if test.shapes.count == 1 {
        shape = test.shapes[0]
    } else {
        let group = ShapeGroup()
        for s in test.shapes {
            group.add(shape: s)
        }
        
        shape = group
    }
    let (pdf, histogram, diff) = Utils.generateHistogram(pdfFunc: { wi in
        let r = Ray(origin: Point3(), direction: wi)
        guard let its = shape.hit(r: r) else { return 0 }
        return shape.pdfDirect(shape: its.shape, p: Point3(), y: its.p, n: its.n)
    }, sampleFunc: { sample in
        func visible(p0: Point3, p1: Point3) -> Bool {
            var d = p1 - p0
            var dist = d.length
            d /= dist
            dist -= 0.0002
            let r = Ray(origin: p0, direction: d).with(max: dist)
            return shape.hit(r: r) == nil
        }
        
        let source = shape.sampleDirect(p: Point3(), sample: sample)
        let d = (source.y - Point3()).normalized()
        
        return visible(p0: Point3(), p1: source.y)
            ? d
            : Vec3()
    }, nsp: 50, sampler: sampler)
    
    if !Image(array: pdf).write(to: "\(type(of: shape))-pdf.png") {
        print("Error saving pnf image")
    }
    
    if !Image(array: histogram).write(to: "\(type(of: shape))-hist.png") {
        print("Error saving histogram image")
    }
    
    if !Image(array: diff).write(to: "\(type(of: shape))-diff.png") {
        print("Error saving diff image")
    }
}
