# Math extensions

Learn how to define vectors and matrices in your scenes.

## Overview

For all of the vector types (``Color``,``Vec2``  ``Vec3``, ``Vec4``), you can define them in your scenes by using arrays. There are many ways to create the matrix types (``Mat3`` and ``Mat4``) which we will also cover in this article. 

> Note: The scalars are `Float` and will work with any the following formats.
> - Exponent: `7.549790126404332e-08`
> - No fractional part: `1`
> - Normal float: `0.75`

### Vectors

For vectors in the form of `(X,Y)`, you can define them as a 2 scalars array.
```json
{
    "<Vector property>": [<X>, <Y>]
}
```

For vectors in the form of `(X,Y,Z)`, you can define them as a 3 scalars array.
```json
{
    "<Vector property>": [<X>, <Y>, <Z>]
}
```

For vectors in the form of `(X,Y,Z,W)`, you can define them as a 4 scalars array.

```json
{
    "<Vector property>": [<X>, <Y>, <Z>, <W>]
}
```

### Matrices

Matrices are column based. You can define them with one of the many different forms, depending on what makes more sense for your use case.

@TabNavigator {
   @Tab("XYZ") {
      `XYZ` matrices are defined as an optional translation component `o` _(defaults to 0)_ and the transform parts encoded in 3 optional ``Vec3`` _(defaults to unit vector in the given axis)_.
      
      > Tip: Setting any of the `xyz` values to a unit vector will define the coordinate system, resulting in simple rotations for a camera.
      
      @Row {
          @Column {

              ```json
              {
                  "o": [<X>, <Y>, <Z>],
                  "x": [<X>, <Y>, <Z>]
                  "y": [<X>, <Y>, <Z>]
                  "z": [<X>, <Y>, <Z>]
              }
              ```
          }
          
          @Column {
              
              ```
              ┌                        ┐
              │ <X.x>, <X.y>, <X.z>, 0 │
              │ <Y.x>, <Y.y>, <Y.z>, 0 │
              │ <Z.x>, <Z.y>, <Z.z>, 0 │
              │ <O.x>, <O.y>, <O.z>, 1 │
              └                        ┘
              ```
          }
      }
   }
  
   @Tab("Scale") {
      `Scale` matrices are defined as a single scalar for a uniform `XYZ` scale factor, or as a ``Vec3`` that will become the values of a diagonal matrix.
      
      
      @Row {
          @Column {
              Example with a single scalar

              ```json
              {
                  "scale": <scalar>
              }
              ```
          }
          
          @Column {
              
              ```
              ┌               ┐
              │ <s>,  0,   0  │
              │  0,  <s>,  0  │
              │  0,   0,  <s> │
              └               ┘
              ```
          }
      }

      @Row {
          @Column {
              Example with a ``Vec3``
              
              ```json
              {
                  "scale": [<X>, <Y>, <Z>]
              }
              ```
          }

          @Column {
              ```
              ┌               ┐
              │ <X>,  0,   0  │
              │  0,  <Y>,  0  │
              │  0,   0,  <Z> │
              └               ┘
              ```
          }
      }
   }
  
   @Tab("Axis-Angle") {
      `Axis-Angle` matrices are defined as an optional angle in degrees *(defaulting to 0)* and an optional axis around which the rotation occurs (defaulting to `X`).
      
      > Note: The axis around which the rotation occurs is equal to 1. The others are equal to 0.
      
      ```json
      {
          "axis": [0, 0, 1],
          "angle": <scalar>
      }
      ```
   }
   
   @Tab("Rotation") {
      `Rotation` matrices are defined as a single ``Vec3`` for subsequent yaw pitch roll degrees rotations, following the order of `Y -> X -> Z`. 
      
      ```json
      {
          "rotation": [<X>, <Y>, <Z>]
      }
      ```
   }
   
   @Tab("Translate") {
      `Translate` matrices are defined as a single ``Vec3``.
      
      ```json
      {
          "translate": [<X>, <Y>, <Z>]
      }
      ```
   }
   
   @Tab("Look at") {
      `Look at` matrices are defined as several ``Vec3`` that will get converted into a matrix that looks from at position to a given direction.
      
      > Note: This is mainly used for camera position matrices, where `from` is the camera origin, `at` defines the looking direction (`from - at`) and `up` is a unit vector pointing at the top of the camera.  
      
      ```json
      {
          "from": [<X>, <Y>, <Z>],
          "at": [<X>, <Y>, <Z>],
          "up": [<X>, <Y>, <Z>]
      }
      ```
   }
   
   @Tab("Matrix") {
       `Matrix` is defined as a single array of column based scalars.

       ```json
       {
           "matrix": [
               <c0r0>, <c0r1>, <c0r2>,
               <c1r0>, <c1r1>, <c1r2>,
               <c2r0>, <c2r1>, <c2r2>
           ]
       }
       ```
   }
   
   @Tab("Raw") {
       `Raw` matrices are defined as an array of rows.
       
       ```json
       {
           "<Matrix property>": [
               [<c0r0>, <c1r0>, <c2r0>]
               [<c0r1>, <c1r1>, <c2r1>],
               [<c0r2>, <c1r2>, <c2r2>]
           ]
       }
       ```
   }
}
