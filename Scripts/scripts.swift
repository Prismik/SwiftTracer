//
//  scripts.swift
//  scripts
//
//  Created by Francis Beauchamp on 2024-10-10.
//

import Foundation
import ArgumentParser

@main
struct Scripts: ParsableCommand {
    @Argument(help: "The name of the script to run.")
    var runnable: Runnable
    
    @Option(help: "The names of the image inputs for the script being run.")
    var inputs: [String] = []
    
    @Option(help: "The names of the directory containing the outputs of the script being run.")
    var output: String = URL.documentsDirectory.absoluteString
    
    mutating func run() throws {
        switch runnable {
        case .gradient:
            guard let input = inputs.first else { fatalError("Missing input to compute gradients from") }
            guard let img = Image(filename: input)?.read() else { fatalError("Could not read image") }
            
            Gradients(image: img, outputDirectory: output).run()
        case .mse:
            guard inputs.count == 2, let first = inputs.first, let second = inputs.last else { fatalError("Missing input to compute gradients from") }
            guard let original = Image(filename: first)?.read() else { fatalError("Could not read image") }
            guard let compared = Image(filename: second)?.read() else { fatalError("Could not read image") }
            
            MeanSquaredError(original: original, compared: compared).run()
        case .psnr:
            guard inputs.count == 2, let first = inputs.first, let second = inputs.last else { fatalError("Missing input to compute gradients from") }
            guard let original = Image(filename: first)?.read() else { fatalError("Could not read image") }
            guard let compared = Image(filename: second)?.read() else { fatalError("Could not read image") }
            
            PeakSignalToNoiseRatio(original: original, compared: compared).run()
        }
        
    }
}

enum Runnable: String, ExpressibleByArgument, CaseIterable {
    case gradient
    case mse
    case psnr
}
