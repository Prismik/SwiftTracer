//
//  integrator.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-05-18.
//

import Foundation

enum IntegratorType {
    case Path
    case Normal
    case UV
    case Direct
    case PathMis
}

protocol Integrator {
    func render()
}

extension Integrator {
    static func from(json: Data) -> Integrator? {
        return nil
    }
}
