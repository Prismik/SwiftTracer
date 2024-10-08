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
        Render.run(input: input, output: out)
    }
}

enum Render {
    static func run(input: String, output: String) {
        do {
            let decoder = JSONDecoder()
            let url = URL(fileURLWithPath: input)
            guard let data = try? Data(contentsOf: url) else {
                fatalError("Trying to load scene which doesn't exist: \(input)")
            }
            let scene = try decoder.decode(Scene.self, from: data)
            let clock = ContinuousClock()
            let time = clock.measure {
                let result = scene.render()
                var successes: Int = 0
                for (i, item) in result.enumerated() {
                    let image = Image(array: item)
                    let id = i == 0 ? "" : "\(i)-"
                    let writeResult = image.write(to: "\(id)\(output)")
                    if writeResult { successes += 1 }
                }
                
                if successes == result.count {
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
