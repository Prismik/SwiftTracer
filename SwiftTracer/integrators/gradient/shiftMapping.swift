//
//  shiftMapping.swift
//  SwiftTracer
//
//  Created by Francis Beauchamp on 2024-10-08.
//

enum ShiftMappingOperator: String, Decodable {
    case rsr
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
        case .rsr:
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

enum ShiftResult {
    case successful(path: Path, weight: Float)
    case failed(weight: Float)
}

struct Shift {
    let result: ShiftResult
    let contrib: Color
}

protocol ShiftMapping {
    var sampler: Sampler! { get set }

    /// Tries calculating the contribution of a shifted pixel, returning nil when the shift fails.
    func shift(
        pixel: Vec2,
        offset: Vec2,
        params: ShiftMapParams
    ) -> Shift
    
    func initialize(sampler: Sampler, integrator: SamplerIntegrator & GradientDomainIntegrator, scene: Scene)
}

final class RandomSequenceReplay: ShiftMapping {
    unowned var sampler: Sampler!
    unowned var integrator: SamplerIntegrator!
    unowned var scene: Scene!
    
    func initialize(sampler: Sampler, integrator: SamplerIntegrator & GradientDomainIntegrator, scene: Scene) {
        self.sampler = sampler
        self.integrator = integrator
        self.scene = scene
    }

    func shift(pixel: Vec2, offset: Vec2, params: ShiftMapParams) -> Shift {
        guard let seed = params.seed else { fatalError("Wrong params provided to \(String(describing: self))") }
        let pixel = pixel + offset
        guard pixel.x >= 0, pixel.y >= 0, pixel.x < scene.camera.resolution.x, pixel.y < scene.camera.resolution.y else { return Shift(result: .failed(weight: 1), contrib: .zero) }
        sampler.rng.state = seed
        // TODO Rework the way we interact with path
        let path = Path.start(at: CameraVertex())
        let contrib = integrator.li(pixel: pixel, scene: scene, sampler: sampler)
        return Shift(result: .successful(path: path, weight: 0.5), contrib: contrib)
    }
}

final class PathReconnection: ShiftMapping {
    struct Stats {
        var successfulConnections: Int = 0
        var failedConnections: Int = 0
        var total: Int { successfulConnections + failedConnections }
    }

    unowned var sampler: Sampler!
    var integrator: SamplerIntegrator!
    unowned var scene: Scene!

    var stats = Stats()

    func initialize(sampler: Sampler, integrator: SamplerIntegrator & GradientDomainIntegrator, scene: Scene) {
        self.sampler = sampler
        self.integrator = integrator
        self.scene = scene
        
    }
    
    func shift(pixel: Vec2, offset: Vec2, params: ShiftMapParams) -> Shift {
        guard let path = params.path, let seed = params.seed else { fatalError("Wrong params provided to \(String(describing: self))") }

        let pixel = pixel + offset
        guard pixel.x >= 0, pixel.y >= 0, pixel.x < scene.camera.resolution.x, pixel.y < scene.camera.resolution.y else {
            return Shift(result: .failed(weight: 1), contrib: .zero)
        }
        
        var connectable = false
        sampler.rng.state = seed
        // TODO Rework how we do this
        let result = integrator.li(pixel: pixel, scene: scene, sampler: sampler)
        
        guard connectable else {
            stats.failedConnections += 1
            return Shift(result: .failed(weight: 1), contrib: .zero)
        }

//        guard let connectedPath = offsetPath.connect(to: path, at: offsetPath.vertices.count, integrator: integrator, scene: scene) else {
//            stats.failedConnections += 1
//            return Shift(result: .failed(weight: 1), contrib: .zero)
//        }

        stats.successfulConnections += 1
//        let w = path.pdf / (path.pdf + connectedPath.pdf * connectedPath.jacobian)
        let w: Float = 0.5
        let newPath = Path.start(at: CameraVertex())
        return Shift(result: .successful(path: newPath, weight: w), contrib: result)
    }
}
