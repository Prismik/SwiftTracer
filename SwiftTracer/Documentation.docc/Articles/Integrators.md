# Using integrators

Learn how to use integrators in your scenes.

## Overview

A scene can be rendered by one integrator at a time, which has it's own dedicated json object. There will be scenes for which a given integration method will be more optimal than others, but in general there are no "one fits all" solution to this.

The integrator json object is always composed of a `type` which is used to bridge from a ``IntegratorType`` to a concrete implementation of a ``Integrator``. Additionally, some integrators can be configured with parameters that are specific to them. Those will be found under the `params` node and the way to format it accordingly will be covered in this article.

```json
{
    "type": "<IntegratorType>",
    "params": { <Type specific properties> },
}
```

### Path

<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->

### Direct

### UV

### Normal

### PSSMLT
