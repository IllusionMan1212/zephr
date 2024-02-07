package zephr

import m "core:math/linalg/glsl"

Camera :: struct {
    position:    m.vec3,
    front:       m.vec3,
    up:          m.vec3,
    yaw:         f32,
    pitch:       f32,
    speed:       f32,
    sensitivity: f32,
    fov:         f32,
}

DEFAULT_CAMERA :: Camera {
    position    = m.vec3{0, 1, 3},
    front       = m.vec3{0, 0, -1},
    up          = m.vec3{0, 1, 0},
    yaw         = -90,
    pitch       = 0,
    speed       = 5,
    sensitivity = 0.05,
    fov         = 45,
}
