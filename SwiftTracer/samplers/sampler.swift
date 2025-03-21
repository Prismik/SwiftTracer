//
//  sampler.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-24.
//

import Foundation

/// Box type for ``Sampler`` protocol that allows to decode pseudo-random number samplers in a type agnostic way.
struct AnySampler: Decodable {
    enum TypeIdentifier: String, Codable {
        case independent
        case pssmlt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case params
        case nspp
        case largeStepRatio
    }
    
    let wrapped: Sampler
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeIdentifier.self, forKey: .type)
        switch type {
        case .independent:
            let nspp = try container.decodeIfPresent(Int.self, forKey: .nspp) ?? 10
            self.wrapped = IndependentSampler(nspp: nspp)
        case .pssmlt:
            let params = try container.nestedContainer(keyedBy: PSSMLTSampler.CodingKeys.self, forKey: .params)
            let nspp = try container.decodeIfPresent(Int.self, forKey: .nspp) ?? 10
            let largeStepRatio = try container.decodeIfPresent(Float.self, forKey: .largeStepRatio) ?? 0.3
            let mutator = try params.decode(AnyMutator.self, forKey: .mutation)
            self.wrapped = PSSMLTSampler(nbSamples: nspp, largeStepRatio: largeStepRatio, mutator: mutator.wrapped.init())
        }
    }
}

protocol Sampler: AnyObject {
    func next() -> Float
    func next2() -> Vec2
    func gen() -> Float
    func copy() -> Self
    func new(nspp: Int) -> Self
    var nbSamples: Int { get }
    var rng: RNG { get set }
}
