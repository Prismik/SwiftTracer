# Using materials

Learn how to define materials in your scenes.

## Overview

Each material is defined by a single json object. Depending on the type of your material, you will have to provide different properties, although many of them are going to be of the ``Texture`` type. You can find out more about the different forms that a texture can take in <doc:TextureHowto>.

The material json object is always composed of a `type` which is used to bridge from a ``AnyMaterial/TypeIdentifier`` to a concrete implementation of a ``Material``. It also has a **unique** name and some type specific properties that we will cover in this article. 

```json
{
    "type": "<TypeIdentifier>",
    "name": "unique identifier",
    <Type specific properties>
}
```

### Diffuse

A diffuse material has an associated texture, codified in the json as `albedo`. This property describes the wavelength of the light that will get reflected by the material.

To create a purely red material, you would add the following material to your list of materials:

```json
{
    "type": "diffuse",
    "name": "unique identifier",
    "albedo": [1, 0, 0]
}
```

### Metal

A metal material has 2 associated textures; `roughness` for the roughness of the reflection (0 being fully specular), and `ks` for the wavelength of the light that gets reflected.

```json
{
    "type": "metal",
    "name": "unique identifier",
    "ks": [1, 0, 0],
    "roughness": 0
}
```

### Dielectric

### Blend

### NormalMap

