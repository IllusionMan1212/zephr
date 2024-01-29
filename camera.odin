package zephr

import m "core:math/linalg/glsl"

Camera :: struct {
    position: m.vec3,
    front: m.vec3,
    up: m.vec3,
    yaw: f32,
    pitch: f32,
    speed: f32,
    sensitivity: f32,
    fov: f32,
}

DEFAULT_CAMERA :: Camera {
    position = m.vec3 {0, 1, 3},
    front = m.vec3 {0, 0, -1},
    up = m.vec3 {0, 1, 0},
    yaw = -90,
    pitch = 0,
    speed = 100000,
    sensitivity = 0.05,
    fov = 45,
}

move_camera_view :: proc(camera: ^Camera, xoffset: f32, yoffset: f32) {
    if !zephr_ctx.mouse.captured { return }
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

    front := m.vec3{
        m.cos(m.radians(camera.pitch)) * m.cos(m.radians(camera.yaw)),
        m.sin(m.radians(camera.pitch)),
        m.cos(m.radians(camera.pitch)) * m.sin(m.radians(camera.yaw)),
    }

    camera.front = m.normalize(front)
}

move_camera :: proc(camera: ^Camera, key: Scancode) {
    // TODO: moving is awkward because a single keypress is sent, then a few milliseconds go by and then a whole bunch are sent.
    // TODO: another problem is that two keys can't be pressed at once, so you can't move diagonally.

    if key == .W {
      camera.position += camera.front * camera.speed
    }
    if key == .S {
        camera.position -= camera.front * camera.speed
    }
    if key == .A {
      camera.position -= m.normalize((m.cross(camera.front, camera.up))) * camera.speed
    }
    if key == .D {
      camera.position += m.normalize((m.cross(camera.front, camera.up))) * camera.speed
    }
}
