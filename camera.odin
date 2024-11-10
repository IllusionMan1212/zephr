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
    near:        f32,
    far:         f32,
    view_mat:    m.mat4,
    proj_mat:    m.mat4,
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
    near        = 0.05,
    far         = 5,
    view_mat    = 1, // 1 is identity mat
    proj_mat    = 1,
}

@(private)
editor_camera: Camera = DEFAULT_CAMERA

new_camera :: proc(pitch: f32 = 0, yaw: f32 = -90, fov: f32 = 45, near: f32 = 0.05, far: f32 = 40) -> Camera {
    front := m.vec3 {
        m.cos(m.radians(pitch)) * m.cos(m.radians(yaw)),
        m.sin(m.radians(pitch)),
        m.cos(m.radians(pitch)) * m.sin(m.radians(yaw)),
    }

    position := m.vec3{0, 0, 0}
    up := m.vec3{0, 1, 0}
    window_size := get_window_size()

    view_mat := m.mat4LookAt(position, position + front, up)
    projection := m.mat4Perspective(m.radians(fov), window_size.x / window_size.y, near, far)

    return Camera {
        position = m.vec3{0, 0, 0},
        front = m.normalize(front),
        up = m.vec3{0, 1, 0},
        yaw = yaw,
        pitch = pitch,
        speed = 5,
        sensitivity = 0.05,
        fov = fov,
        near = near,
        far = far,
        view_mat = view_mat,
        proj_mat = projection,
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

get_editor_camera :: proc() -> ^Camera {
    return &editor_camera
}

get_frustum_corners_world_space :: proc(camera: ^Camera) -> (corners: [8]m.vec4) {
    inv := m.inverse(camera.proj_mat * camera.view_mat)

    i := 0
    for x in 0 ..< 2 {
        for y in 0 ..< 2 {
            for z in 0 ..< 2 {
                pt := inv * m.vec4{(2.0 * f32(x)) - 1.0, (2.0 * f32(y)) - 1.0, (2.0 * f32(z)) - 1.0, 1.0}
                corners[i] = pt / pt.w
                i += 1
            }
        }
    }

    return
}
