package zephr_ui

import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:log"
import "core:mem"

import gl "vendor:OpenGL"

@(private = "file")
vao: u32
@(private = "file")
vbo: u32
@(private = "file")
ebo: u32
@(private = "file")
ui_shader: u32

@(private)
engine_rel_path := filepath.dir(#file)

@(private)
create_resource_path :: proc(path: string) -> string {
    return filepath.join({engine_rel_path, path})
}

init_drawing :: proc() {
    indices := [6]u32{0, 1, 2, 2, 3, 1}

    shader_id, ok := gl.load_shaders("/home/illusion/Desktop/repos/fLWac/engine/shaders/ui2.vert", "/home/illusion/Desktop/repos/fLWac/engine/shaders/ui2.frag")
    if !ok {
        log.error("Failed to load ui shaders")
    }
    ui_shader = shader_id

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), 0)
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4))
    gl.VertexAttribDivisor(0, 1)
    gl.VertexAttribDivisor(1, 1)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

    gl.BindVertexArray(0)
}

instance_rect :: proc(rect: Rect, bg_color: Color) {
    inst: DrawableInstance
    inst.rect = rect
    inst.colors[0] = bg_color
    inst.colors[1] = bg_color
    inst.colors[2] = bg_color
    inst.colors[3] = bg_color

    append(&ui_state.drawables, inst)
}

draw_instances :: proc(projection: m.mat4) {
    projection := projection
    gl.UseProgram(ui_shader)
    gl.UniformMatrix4fv(gl.GetUniformLocation(ui_shader, "projection"), 1, false, raw_data(&projection))

    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(DrawableInstance) * len(ui_state.drawables), raw_data(ui_state.drawables), gl.STATIC_DRAW)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, cast(i32)len(ui_state.drawables))
}

