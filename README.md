<div align="center">

# SwiftTracer - A physically based rendering engine

![Platform](https://badgen.net/badge/platform/macos?list=%7C)
![Language](https://img.shields.io/badge/Swift-5.x-green?logo=swift)

</div>

This is my work in progress implementation of a physically based rendering engine that is inspired by PBRT, Mitsuba and many other contributors in the field.

# Content

## Documentation

You can have a look at the [documentation](https://prismik.github.io/SwiftTracer/documentation/swifttracer/), where you'll find more details on the supported bsdf, as well as the formalism to build json scenes.

## Publication

- <a href="https://github.com/Prismik/SwiftTracer/blob/main/publication/Rapport_final_beauchamp-francis.pdf" target="_blank">Langevin Monte Carlo with finite différence</a>

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
