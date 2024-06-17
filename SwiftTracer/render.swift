//
//  main.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation
import ArgumentParser

@main
struct Tracer: ParsableCommand {
    @Argument(help: "The scene file to load as an input.")
    var input: String
    
    @Option(help: "The name for the image output.")
    var output: String?
    
    @Option(name: .shortAndLong, help: "The number of samples per pixel.")
    var spp: Int?
    
    mutating func run() throws {
        let samples = spp ?? 16
        let out = output ?? "out.png"
        Render.run(input: input, output: out, spp: samples)
    }
}

enum Render {
    static func run(input: String, output: String, spp: Int) {
        do {
            let example = try Scene.Example.veach.create()
            let decoder = JSONDecoder()
            let scene = try decoder.decode(Scene.self, from: example)
            let integrator = PathIntegrator(mis: true)
            let sampler = IndependantSampler(nspp: spp)
            let clock = ContinuousClock()
            let time = clock.measure {
                let pixels = integrator.render(scene: scene, sampler: sampler)
                let image = Image(array: pixels)
                if image.write(to: "test.png") {
                    print("#Intersection: \(Scene.NB_INTERSECTION)")
                    print("#rays: \(Scene.NB_TRACED_RAYS)")
                    print("ratio: \(Float(Scene.NB_INTERSECTION) / Float(Scene.NB_TRACED_RAYS))")
                } else {
                    print("Failure")
                }
            }
            print("Render time: \(time)")
        } catch {
            print(error)
            print("Error while parsing scene")
        }
    }
}
