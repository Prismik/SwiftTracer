# ``SwiftTracer``

A physically based rendering engine.

## Overview

This is a work in progress implementation of a physically based rendering engine that is inspired by PBRT, Mitsuba and many other contributors in the field. To start rendering, simply create a json scene and provide it to the ``Render`` command line program.

## Topics

### Materials

- <doc:Materials>
- <doc:Texture>
- ``Material``
- ``Diffuse``
- ``Metal``
- ``Dielectric``
- ``Blend``
- ``NormalMap``

### Shapes

- ``Shape``
- ``Sphere``
- ``Quad``
- ``Triangle``
- ``Mesh``

### Lights

- ``Light``
- ``AreaLight``
- ``PointLight``
- ``SpotLight``

### Integrators

- ``Integrator``
- ``DirectIntegrator``
- ``NormalIntegrator``
- ``PathIntegrator``
- ``UvIntegrator``

### Maths

We use several convenience typealiases to bridge with the unfriendly simd types that are used for matrices and vectors maths.

- <doc:Maths>
- ``Vec2``
- ``Vec3``
- ``Color``
- ``Point3``
- ``Vec4``
- ``Mat3``
- ``Mat4``
