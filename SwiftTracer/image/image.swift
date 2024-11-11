//
//  image.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-26.
//

import Foundation

class Image {
    let encoding: EncodingIdentifier

    private let encoder: ImageEncoding
    // TODO Fallback on pfm when exr not available, and change file extension. Alternatively, find linux compatible implementation of exr
    init(encoding: EncodingIdentifier) {
        self.encoding = encoding
        self.encoder = switch encoding {
            case .jpg: JPG()
            case .png: PNG()
            case .pfm: PFM()
            case .exr: EXR()
        }
    }
    /// Reads the bytes of the associated file found at the path `filename` given in the initializer. The content will be returned as an `Array2d` where values between 0 and 1.
    /// > Note: The pixel values are converted from standard RGB to linear RGB.
    func read(file: URL) -> Array2d<Color>? {
        return encoder.read(file: file)
    }

    /// Attempts to write the pixel values (RGB) into a new file at the path `filename`.
    ///
    /// > Note: The pixel values are converted from linear RGB to [standard RGB](https://en.wikipedia.org/wiki/SRGB).
    func write(img: Array2d<Color>, to filename: String, directory: String = URL.documentsDirectory.absoluteString) -> Bool {
        guard let url = URL(string: "\(directory)/\(filename)") else { return false }
        return encoder.write(img: img, to: url)
    }
}
