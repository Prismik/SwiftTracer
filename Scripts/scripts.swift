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
            guard let encoding = EncodingIdentifier(filename: input) else { fatalError("Invalid input file encoding") }
            let image = Image(encoding: encoding)
            guard let url = URL(string: "file://\(input)") else { fatalError("Invalid input file") }
            guard let pixels = image.read(file: url) else { return }
            
            Gradients(image: pixels, outputDirectory: output).run()
        case .mse:
            guard inputs.count == 2, let first = inputs.first, let second = inputs.last else { fatalError("Missing input to compute gradients from") }
            
            guard let originalEncoding = EncodingIdentifier(filename: first) else { fatalError("Invalid input file encoding") }
            let original = Image(encoding: originalEncoding)
            guard let originalUrl = URL(string: first) else { fatalError("Invalid input file") }
            guard let originalImage = original.read(file: originalUrl) else { fatalError("Could not read image") }
            
            guard let comparedEncoding = EncodingIdentifier(filename: second) else { fatalError("Invalid input file encoding") }
            let compared = Image(encoding: comparedEncoding)
            guard let comparedUrl = URL(string: second) else { fatalError("Invalid input file") }
            guard let comparedImage = compared.read(file: comparedUrl) else { fatalError("Could not read image") }
            
            MeanSquaredError(original: originalImage, compared: comparedImage).run()
        case .psnr:
            guard inputs.count == 2, let first = inputs.first, let second = inputs.last else { fatalError("Missing input to compute gradients from") }
            
            guard let originalEncoding = EncodingIdentifier(filename: first) else { fatalError("Invalid input file encoding") }
            let original = Image(encoding: originalEncoding)
            guard let originalUrl = URL(string: first) else { fatalError("Invalid input file") }
            guard let originalImage = original.read(file: originalUrl) else { fatalError("Could not read image") }
            
            guard let comparedEncoding = EncodingIdentifier(filename: second) else { fatalError("Invalid input file encoding") }
            let compared = Image(encoding: comparedEncoding)
            guard let comparedUrl = URL(string: second) else { fatalError("Invalid input file") }
            guard let comparedImage = compared.read(file: comparedUrl) else { fatalError("Could not read image") }
            
            PeakSignalToNoiseRatio(original: originalImage, compared: comparedImage).run()
        }
        
    }
}

enum Runnable: String, ExpressibleByArgument, CaseIterable {
    case gradient
    case mse
    case psnr
}
