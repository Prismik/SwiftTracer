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
            let theta = try container.decode(Float.self, forKey: .theta)
            let phi = try container.decode(Float.self, forKey: .phi)
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
enum Tests: String {
    case metal
    
    func create() throws -> Data {
        guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "json", subdirectory: "assets") else {
            fatalError("Trying to load obj that does not exist")
        }
        
        return try Data(contentsOf: url)
    }
}

let data = try Tests.metal.create()
let decoder = JSONDecoder()
let test = try decoder.decode(HistogramTest.self, from: data)
let sampler: Sampler = IndependantSampler(nspp: 1)
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
