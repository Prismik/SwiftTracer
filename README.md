# SwiftTracer - A physically based rendering engine [WIP]

This is my (currently) work in progress implementation of a physically based rendering engine that is inspired by PBRT, Mitsuba and many other contributors in the field.

# Content

## Materials (surface interactions)

### Diffuse

Material with a simple lambertian reflection.

**Parameters**

| Name          | Type      | Usage  |
| ------------- | --------- | ------ |
| albedo        | Texture   | Color of the surface $\in [0 ... 1]$ (probability of light being reflected at a given wavelength) | 

### Metal

Material with perfectly specular reflections and rough reflections.

**Parameters**

| Name          | Type      | Usage  |
| ------------- | --------- | ------ |
| ks            | Texture   | Color of the surface (probability of light being reflected at a given wavelength). |
| roughness     | Texture   | Roughness of the reflection $\in [0 ... 1]$. 0 roughness means a perfectly specular (delta), while other values are rough reflections. |

### Dielectric (glass)

Material with glass-like properties. It tends to cause a lot more noise than other materials (partly because of caustics).

**Parameters**

| Name          | Type      | Usage  |
| ------------- | --------- | ------ |
| ks            | Texture   | Color of the surface (probability of light being reflected at a given wavelength). |
| eta_int       | Float     | Interior index of refraction. |
| eta_ext       | Float     | Exterior index of refraction. |

### Blend

Material with a linear combination of two different materials. Any of the other materials can be combined into a Blend instance by using the alpha value.

**Parameters**

| Name          | Type      | Usage  |
| ------------- | --------- | ------ |
| alpha         | Texture   | The blend parameter used to choose which material to render for a sampled Float value. Values $\in [0 ... alpha[$ will render **m1**, while values $\in [alpha ... 1]$ will render **m2**. |
| m1            | Material  | The first material part of the blending process. |
| m2            | Material  | The second material part of the blending process. |

### NormalMap

Material that encapsulates normal information as a texture, which will affect the shading normal of an associated material. It allows to visually add surface detail without changing the geometry of an object.

**Parameters**

| Name          | Type      | Usage  |
| ------------- | --------- | ------ |
| normals       | Texture   | The normal values, where each channel of a pixel in the RGB image is used to encode a normal direction (R: x, G: y, B: z). |
| material      | Material  | The material that will see it's shading normal perturbed by the normals texture. |

# What is not (yet) available

There is a lot of stuff that have not been implemented yet, and among them we count these notable features:

- Subsurface scattering
- Advanced pseudo-random number sampling
- Advanced light sampling
- Volumetric interactions
- Anisotropic metal reflections
- Rough dielectric materials
- etc.

# Special mentions

This code takes influence by a number of very helpful work and publications made by others. I would like to take the time to mention them as some of my code was greatly influenced by them.

- A good starter to get a simple ray tracer: [Peter Shirley's Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html)
- Excellent resource for many physically based rendering techniques: [PBRT](https://pbr-book.org)
- An open source (and highly optimized) physically based renderer: [Mitsuba](http://www.mitsuba-renderer.org)
- Teacher at ÉTS who gives an excellent class on physicalled based rendering: [Adrien Gruson](https://github.com/beltegeuse)
