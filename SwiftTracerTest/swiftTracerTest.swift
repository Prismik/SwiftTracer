//
//  swiftTracerTest.swift
//  SwiftTracerTest
//
//  Created by Francis Beauchamp on 2024-05-21.
//

import XCTest

final class SwiftTracerTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testVec2JsonConversion() throws {
        let v = """
        [
            5,
            0.111
        ]
        """
        
        let jsonVec = Data(v.utf8)
        let decoder = JSONDecoder()
        let v2 = try XCTUnwrap(try? decoder.decode(Vec2.self, from: jsonVec))
        XCTAssertEqual(v2.x, 5)
        XCTAssertEqual(v2.y, 0.111)
    }
    
    func testVec3JsonConversion() throws {
        let v = """
        [
            5,
            0.111,
            888
        ]
        """
        
        let jsonVec = Data(v.utf8)
        let decoder = JSONDecoder()
        let v2 = try XCTUnwrap(try? decoder.decode(Vec3.self, from: jsonVec))
        XCTAssertEqual(v2.x, 5)
        XCTAssertEqual(v2.y, 0.111)
        XCTAssertEqual(v2.z, 888)
    }
    
    func testMat3JsonDecoding() throws {
        let m = """
        [
            [1, 4, 7],
            [2, 5, 8],
            [3, 6, 9]
        ]
        """
        
        let json = Data(m.utf8)
        let decoder = JSONDecoder()
        let m2 = try XCTUnwrap(try? decoder.decode(Mat3.self, from: json))
        XCTAssertEqual(m2[0], [1, 2, 3])
        XCTAssertEqual(m2[1], [4, 5, 6])
        XCTAssertEqual(m2[2], [7, 8, 9])
    }
    
    func testMat4JsonDecoding() throws {
        let m = """
        [
            [1, 5,  9, 13],
            [2, 6, 10, 14],
            [3, 7, 11, 15],
            [4, 8, 12, 16]
        ]
        """
        
        let json = Data(m.utf8)
        let decoder = JSONDecoder()
        let m2 = try XCTUnwrap(try? decoder.decode(Mat4.self, from: json))
        XCTAssertEqual(m2[0], [1, 2, 3, 4])
        XCTAssertEqual(m2[1], [5, 6, 7, 8])
        XCTAssertEqual(m2[2], [9, 10, 11, 12])
        XCTAssertEqual(m2[3], [13, 14, 15, 16])
    }
    
    func testTextureDecoding() throws {
        let colorTextureData = """
            [0.1, 0.2, 0.3]
        """
        
        let scalarTextureData = """
            0.6
        """
        
        let colorJson = Data(colorTextureData.utf8)
        let scalarJson = Data(scalarTextureData.utf8)
        
        let decoder = JSONDecoder()
        
        let t1 = try XCTUnwrap(try? decoder.decode(Texture<Color>.self, from: colorJson))
        let t2 = try XCTUnwrap(try? decoder.decode(Texture<Float>.self, from: scalarJson))
        
        XCTAssertEqual(t1.get(uv: Vec2(), p: Point3()), Color(0.1, 0.2, 0.3))
        XCTAssertEqual(t2.get(uv: Vec2(), p: Point3()), 0.6)
    }
    
    func testDiffuseDecoding() throws {
        let diffuseData = """
        {
            "name": "d",
            "type": "diffuse",
            "albedo": [0.1, 0.2, 0.3]
        }
        """
        
        let json = Data(diffuseData.utf8)
        
        let decoder = JSONDecoder()
        let any = try decoder.decode(AnyMaterial.self, from: json)
        let diffuse = try XCTUnwrap(any.wrapped as? Diffuse)
        XCTAssertEqual(diffuse.texture.get(uv: Vec2(), p: Point3()), Color(0.1, 0.2, 0.3))
    }
    
    func testMetalDecoding() throws {
        let metalData = """
        {
            "name": "m",
            "type": "metal",
            "ks": [0.1, 0.2, 0.3],
            "roughness": 0.7
        }
        """
        
        let json = Data(metalData.utf8)
        
        let decoder = JSONDecoder()
        let any = try decoder.decode(AnyMaterial.self, from: json)
        let metal = try XCTUnwrap(any.wrapped as? Metal)
        XCTAssertEqual(metal.texture.get(uv: Vec2(), p: Point3()), Color(0.1, 0.2, 0.3))
        XCTAssertEqual(metal.roughness.get(uv: Vec2(), p: Point3()), 0.7)
    }
    
    func testDielectricDecoding() throws {
        let dielectricData = """
        {
            "name": "m",
            "type": "dielectric",
            "ks": [0.1, 0.2, 0.3],
            "etaExt": 0.9,
            "etaInt": 1.1
        }
        """
        
        let json = Data(dielectricData.utf8)
        
        let decoder = JSONDecoder()
        let any = try decoder.decode(AnyMaterial.self, from: json)
        let dielectric = try XCTUnwrap(any.wrapped as? Dielectric)
        XCTAssertEqual(dielectric.texture.get(uv: Vec2(), p: Point3()), Color(0.1, 0.2, 0.3))
        XCTAssertEqual(dielectric.etaExterior, 0.9)
        XCTAssertEqual(dielectric.etaInterior, 1.1)
    }
    
    func testShapeDecoding() throws {
        let sphereData = """
        {
            "type": "sphere",
            "radius": 5,
            "transform": {
                "o": [0, -1, 0],
                "x": [1, 0, 0],
                "y": [0, 0, -1],
                "z": [0, 1, 0]
            },
            "solidAngle": true,
            "material": "diffuse"
        }
        """
        
        let material = Diffuse(texture: Texture<Color>.constant(value: Color()))
        let materials = ["diffuse": material]
        let json = Data(sphereData.utf8)
        
        let decoder = JSONDecoder()
        let any = try decoder.decode(AnyShape.self, from: json)
        let shape = any.unwrapped(materials: materials)
        let sphere = try XCTUnwrap(shape as? Sphere)
        XCTAssertEqual(sphere.radius, 5)
        XCTAssertEqual(sphere.solidAngle, true)
    }
    
    func testShapeListDecoding() throws {
        let shapesData = """
        [
            {
                "type": "sphere",
                "radius": 5,
                "transform": {
                    "o": [0, -1, 0],
                    "x": [1, 0, 0],
                    "y": [0, 0, -1],
                    "z": [0, 1, 0]
                },
                "solidAngle": true,
                "material": "diffuse"
            },
            {
                "type": "quad",
                "transform": {
                    "o": [0, -1, 0],
                    "x": [1, 0, 0],
                    "y": [0, 0, -1],
                    "z": [0, 1, 0]
                },
                "size": 100,
                "material": "diffuse"
            }
        ]
        """
        let material = Diffuse(texture: Texture<Color>.constant(value: Color()))
        let materials = ["diffuse": material]
        let json = Data(shapesData.utf8)
        
        let decoder = JSONDecoder()
        let anyShapes = try decoder.decode([AnyShape].self, from: json)
        for a in anyShapes {
            let shape = a.unwrapped(materials: materials)
            switch a.type {
            case .sphere:
                let concrete = try XCTUnwrap(shape as? Sphere)
                XCTAssertEqual(concrete.radius, 5)
                XCTAssertEqual(concrete.solidAngle, true)
            case .quad:
                let concrete = try XCTUnwrap(shape as? Quad)
                XCTAssertEqual(concrete.halfSize, Vec2(50, 50))
                XCTAssertEqual(concrete.transform.m, Mat4(Vec4(1, 0, 0, 0), Vec4(0, 0, -1, 0), Vec4(0, 1, 0, 0), Vec4(0, -1, 0, 1)))
            }
            
        }
    }
}
