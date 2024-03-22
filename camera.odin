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

new_camera :: proc(pitch: f32 = 0, yaw: f32 = -90, fov: f32 = 45) -> Camera {
    front := m.vec3 {
        m.cos(m.radians(pitch)) * m.cos(m.radians(yaw)),
        m.sin(m.radians(pitch)),
        m.cos(m.radians(pitch)) * m.sin(m.radians(yaw)),
    }

    return Camera {
        position    = m.vec3{0, 0, 0},
        front       = front,
        up          = m.vec3{0, 1, 0},
        yaw         = yaw,
        pitch       = pitch,
        speed       = 5,
        sensitivity = 0.05,
        fov         = fov,
    }
}

move_camera_view :: proc(camera: ^Camera, xoffset: f32, yoffset: f32) {
    xoffset := xoffset * camera.sensitivity
    yoffset := yoffset * camera.sensitivity

    camera.yaw += xoffset
    camera.pitch += yoffset

    if camera.pitch > 89.0 {
        camera.pitch = 89.0
    }
    if camera.pitch < -89.0 {
        camera.pitch = -89.0
    }

    front := m.vec3 {
        m.cos(m.radians(camera.pitch)) * m.cos(m.radians(camera.yaw)),
        m.sin(m.radians(camera.pitch)),
        m.cos(m.radians(camera.pitch)) * m.sin(m.radians(camera.yaw)),
    }

    camera.front = m.normalize(front)
}
