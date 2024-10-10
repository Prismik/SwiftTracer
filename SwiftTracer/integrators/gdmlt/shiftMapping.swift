//
//  shiftMapping.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

// TODO Allow for plug and play of other types of integrators
struct ShiftMapParams {
    let seed: UInt64?
    let path: Path?

    init(seed: UInt64? = nil, path: Path? = nil) {
        self.seed = seed
        self.path = path
    }
}

protocol ShiftMapping {
    var sampler: Sampler { get set }

    func shift(
        pixel: Vec2,
        offset: Vec2,
        params: ShiftMapParams
    ) -> Color
}

final class RandomSequenceReplay: ShiftMapping {
    var sampler: Sampler
    
    private let integrator: SamplerIntegrator
    private let scene: Scene

    init(integrator: SamplerIntegrator, scene: Scene, sampler: Sampler) {
        self.integrator = integrator
        self.scene = scene
        self.sampler = sampler
    }

    func shift(
        pixel: Vec2,
        offset: Vec2,
        params: ShiftMapParams
    ) -> Color {
        guard let seed = params.seed else { fatalError("Wrong params provided to \(String(describing: self))") }
        let pixel = pixel + offset
        guard pixel.x > 0, pixel.y > 0, pixel.x < scene.camera.resolution.x - 1, pixel.y < scene.camera.resolution.y - 1 else { return .zero }
        sampler.rng.state = seed
        return integrator.li(pixel: pixel, scene: scene, sampler: sampler)
    }
}

final class PathReconnection: ShiftMapping {
    var sampler: Sampler
    
    private let integrator: PathIntegrator
    private let scene: Scene

    init(integrator: PathIntegrator, scene: Scene, sampler: Sampler) {
        self.integrator = integrator
        self.scene = scene
        self.sampler = sampler
    }

    func shift(pixel: Vec2, offset: Vec2, params: ShiftMapParams) -> Color {
        guard let path = params.path else { fatalError("Wrong params provided to \(String(describing: self))") }
        let pixel = pixel + offset
        var shiftedPath = Path.start(at: CameraVertex())
        _ = integrator.li(pixel: pixel, scene: scene, sampler: sampler)
        /*{
            let currentLength = shiftedPath.vertices.count
            // End tracing here, connect path to base path
            if path.vertices[currentLength].connectable {
                // TODO Iterate over all of edges/vertices from (currentLength ... end) and add them to shiftedPath
                return false
            }
            
            return true
        }*/
        
        // TODO Find way to get shiftedPath to return it's contrib
        // TODO Look into the path for valid reconnections
        return .zero
    }
    
    
}

private extension Vertex {
    // TODO Look into ratio for almost specular interactions + look into manifold exploration
    var connectable: Bool {
        if let surfaceVertex = self as? SurfaceVertex {
            return !surfaceVertex.intersection.shape.material.hasDelta(
                uv: surfaceVertex.intersection.uv,
                p: surfaceVertex.position
            )
        }
        
        return false
    }
}
