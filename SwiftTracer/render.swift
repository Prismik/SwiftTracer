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
        print(input)
        print(output)
        print(String(spp))
        
        let example = Scene.Example.simple.create()
        let decoder = JSONDecoder()
        do {
            let scene = try decoder.decode(Scene.self, from: example)
            let integrator = NormalIntegrator()
            let sampler = IndependantSampler()
            let pixels = integrator.render(scene: scene, sampler: sampler)
            let image = Image(array: pixels)
            if image.save(to: "test.png") {
                print("Success")
            } else {
                print("Failure")
            }
        } catch {
            print("Error while parsing scene")
        }
        
        
    }
}
