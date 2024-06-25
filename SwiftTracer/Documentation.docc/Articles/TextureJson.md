# Using textures

Learn how to define textures in your scenes.

## Overview

Textures in this project are a general concept that are mapping points from a certain domain (in this case, _(u, v)_), to values in a different domain. There are several implementations of textures which are contained in the ``Texture`` enumeration.

### Constant

This texture type is used when the value is constant over the whole domain. There are two ways that you can define this type of value in your scenes.

With a single `Float` value.
```json
{
    "<Texture property>": 1.0,
}
```

With a `Vec3` value.
```json
{
    "<Texture property>": [0.5, 1, 0.5],
}
```

### Texture map

This texture type is used when an image is used to represent varying values over the domain. Every pixel will be able to have their individual constant value (`Float` or `Vec3`). In the json, you can define such textures with just their filename.

```json
{
    "<Texture property>": "<absolute path to your image>"
}
```


### Cherkerboard

The last type that can be used is mostly useful for test scenes and debugging purposes. You can generate a checkerboard (similar to the squares on a chess board) by creating a json node at your texture property value, and adding the following properties:

- **Type**: will always be "checkerboard2d"
- **uv_scale**: _optional_ ``Vec2`` parameter to define the scale of the checkerboard squares
- **uv_offset**: _optional_ ``Vec2`` parameter to define the offset of the checkerboard squares

```json
"<Texture property>": {
    "type" : "checkerboard2d",
    "uv_scale" : [100, 100],
    "uv_offset": [5, 5]
}
```
