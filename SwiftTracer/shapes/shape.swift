//
//  Shape.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2023-12-14.
//

import Foundation

protocol Shape {
    func hit()
    func aabb()
    func sampleDirect()
    func pdfDirect()
    func material()
}
