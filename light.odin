package zephr

import m "core:math/linalg/glsl"

import gl "vendor:OpenGL"

LightType :: enum {
    DIRECTIONAL,
    POINT,
    SPOT,
}

Light :: struct {
    type:     LightType,
    position: m.vec3,
    ambient:  m.vec3,
    diffuse:  m.vec3,
    specular: m.vec3,
    using _:  struct #raw_union {
        direction: m.vec3,
        point:     struct {
            constant:  f32,
            linear:    f32,
            quadratic: f32,
        },
    },
    vao:      u32,
    vbo:      u32,
    ebo:      u32,
}

new_dir_light :: proc(direction, ambient, diffuse, specular: m.vec3) -> Light {
    vao, vbo, ebo: u32
    //odinfmt: disable
    gizmo_verts := [2]m.vec3 {
        {0, 0, 0},
        m.normalize(direction) * 5,
    }
    gizmo_indices := [?]u32{0, 1}
    //odinfmt: enable

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(gizmo_verts), raw_data(&gizmo_verts), gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(gizmo_indices), raw_data(&gizmo_indices), gl.STATIC_DRAW)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    return(
        Light {
            type = .DIRECTIONAL,
            ambient = ambient,
            diffuse = diffuse,
            specular = specular,
            direction = direction,
            vao = vao,
            vbo = vbo,
            ebo = ebo,
        } \
    )
}

new_point_light :: proc(position, ambient, diffuse, specular: m.vec3) -> Light {
    vao, vbo, ebo: u32
    //odinfmt: disable
    gizmo_verts := [4]m.vec3 {
        {1, 1, 0},
        {1, -1, 0},
        {-1, -1, 0},
        {-1, 1, 0},
    }
    gizmo_indices := [?]u32{
        0, 1, 3,
        1, 2, 3,
    }
    //odinfmt: enable

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(gizmo_verts), &gizmo_verts, gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(gizmo_indices), &gizmo_indices, gl.STATIC_DRAW)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    return(
        Light {
            type = .POINT,
            ambient = ambient,
            diffuse = diffuse,
            position = position,
            specular = specular,
            point = {constant = 1.0, linear = 0.09, quadratic = 0.032},
            vao = vao,
            vbo = vbo,
            ebo = ebo,
        } \
    )
}