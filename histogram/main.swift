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
