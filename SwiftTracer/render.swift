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
    
    mutating func run() throws {
        let out = output ?? "out.png"
        guard let example = Scene.Example(rawValue: input) else {
            fatalError("Trying to load scene which doesn't exist: \(input)")
        }

        Render.run(input: example, output: out)
    }
}

enum Render {
    static func run(input: Scene.Example, output: String) {
        do {
            let decoder = JSONDecoder()
            let scene = try decoder.decode(Scene.self, from: input.create())
            let clock = ContinuousClock()
            let time = clock.measure {
                let pixels = scene.render()
                let image = Image(array: pixels)
                if image.write(to: output) {
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
