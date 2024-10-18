//
//  shiftMapping.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

enum ShiftMappingOperator: String, Decodable {
    case rsp
    case pathReconnection
}

struct AnyShiftMappingOperator: Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case params
    }
    
    let wrapped: ShiftMapping
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ShiftMappingOperator.self, forKey: .type)
        switch type {
        case .rsp:
            wrapped = RandomSequenceReplay()
        case .pathReconnection:
            wrapped = PathReconnection()
        }
    }
}

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
    var sampler: Sampler! { get set }

    /// Tries calculating the contribution of a shifted pixel, returning nil when the shift fails.
    func shift(
        pixel: Vec2,
        offset: Vec2,
        params: ShiftMapParams
    ) -> Color
    
    func initialize(sampler: Sampler, integrator: SamplerIntegrator & PathSpaceIntegrator, scene: Scene)
}

final class RandomSequenceReplay: ShiftMapping {
    unowned var sampler: Sampler!
    unowned var integrator: SamplerIntegrator!
    unowned var scene: Scene!
    
    func initialize(sampler: Sampler, integrator: SamplerIntegrator & PathSpaceIntegrator, scene: Scene) {
        self.sampler = sampler
        self.integrator = integrator
        self.scene = scene
    }

    func shift(pixel: Vec2, offset: Vec2, params: ShiftMapParams) -> Color {
        guard let seed = params.seed else { fatalError("Wrong params provided to \(String(describing: self))") }
        let pixel = pixel + offset
        guard pixel.x >= 0, pixel.y >= 0, pixel.x < scene.camera.resolution.x, pixel.y < scene.camera.resolution.y else { return .zero }
        sampler.rng.state = seed
        return integrator.li(pixel: pixel, scene: scene, sampler: sampler)
    }
}

final class PathReconnection: ShiftMapping {
    struct Stats {
        var successfulConnections: Int = 0
        var failedConnections: Int = 0
        var total: Int { successfulConnections + failedConnections }
    }

    unowned var sampler: Sampler!
    unowned var integrator: PathSpaceIntegrator!
    unowned var scene: Scene!

    var stats = Stats()

    func initialize(sampler: Sampler, integrator: SamplerIntegrator & PathSpaceIntegrator, scene: Scene) {
        self.sampler = sampler
        self.integrator = integrator
        self.scene = scene
        
    }
    
    func shift(pixel: Vec2, offset: Vec2, params: ShiftMapParams) -> Color {
        guard let path = params.path, let seed = params.seed else { fatalError("Wrong params provided to \(String(describing: self))") }

        let pixel = pixel + offset
        guard pixel.x >= 0, pixel.y >= 0, pixel.x < scene.camera.resolution.x, pixel.y < scene.camera.resolution.y else { return .zero }
        
        var connectable = false
        sampler.rng.state = seed
        let (contrib, offsetPath) = integrator.li(pixel: pixel, scene: scene, sampler: sampler, stop: { shiftedPath in
            guard shiftedPath.edges.count > 1, path.edges.count > shiftedPath.edges.count else { return false }
            let index = shiftedPath.vertices.count - 1
            let b = path.vertices[index]
            let b1 = path.vertices[index+1]
            let valid = b.connectable && shiftedPath.connectable(with: b1, within: scene)
            if valid { connectable = true }
            
            return valid
        })
        
        guard connectable else {
            stats.failedConnections += 1
            return contrib
        }

        guard let connectedPath = offsetPath.connect(to: path, at: offsetPath.vertices.count, integrator: integrator, scene: scene, sampler: sampler) else {
            stats.failedConnections += 1
            return .zero
        }

        stats.successfulConnections += 1
        return connectedPath.contribution
    }
}
