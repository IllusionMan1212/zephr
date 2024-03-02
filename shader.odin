package zephr

import "core:container/queue"
import "core:log"
import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:strings"

import gl "vendor:OpenGL"

Shader :: struct {
    program:       u32,
    vertex_path:   string,
    fragment_path: string,
}

create_shader :: proc(vertex_path: string, fragment_path: string) -> (^Shader, bool) {
    context.logger = logger

    shader := new(Shader)

    program, success := gl.load_shaders(vertex_path, fragment_path)
    shader.program = program
    shader.vertex_path = vertex_path
    shader.fragment_path = fragment_path

    append(&zephr_ctx.shaders, shader)

    return shader, success
}

@(private, disabled = !ODIN_DEBUG)
update_shaders_if_changed :: proc() {
    context.logger = logger

    if queue.len(zephr_ctx.changed_shaders_queue) == 0 {
        return
    }

    file := queue.front_ptr(&zephr_ctx.changed_shaders_queue)
    queue.pop_front(&zephr_ctx.changed_shaders_queue)

    if file != nil {
        for shader in &zephr_ctx.shaders {
            if filepath.base(shader.vertex_path) == file^ || filepath.base(shader.fragment_path) == file^ {
                log.debugf("Hot-reloading shaders that depend on \"%s\"", file^)

                program, success := gl.load_shaders(shader.vertex_path, shader.fragment_path)
                if !success {
                    log.errorf(
                        "Failed to hot-reload shader %d. Vert: %s, Frag: %s",
                        shader.program,
                        shader.vertex_path,
                        shader.fragment_path,
                    )
                }

                gl.DeleteProgram(shader.program)

                shader.program = program
            }
        }
    }
}

use_shader :: proc(shader: ^Shader) {
    gl.UseProgram(shader.program)
}

set_mat4f :: proc(shader: ^Shader, name: cstring, mat4: m.mat4, transpose: bool = false) {
    mat4 := mat4
    loc := gl.GetUniformLocation(shader.program, name)
    gl.UniformMatrix4fv(loc, 1, transpose, raw_data(&mat4))
}

set_mat4fv :: proc(shader: ^Shader, name: cstring, mat4: []m.mat4, transpose: bool = false) {
    mat4 := mat4
    loc := gl.GetUniformLocation(shader.program, name)
    gl.UniformMatrix4fv(loc, cast(i32)len(mat4), transpose, raw_data(&mat4[0]))
}

set_float :: proc(shader: ^Shader, name: cstring, val: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1f(loc, val)
}

set_float_array :: proc(shader: ^Shader, name: cstring, val: []f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1fv(loc, cast(i32)len(val), raw_data(val))
}

set_int :: proc(shader: ^Shader, name: cstring, val: i32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1i(loc, val)
}

set_bool :: proc(shader: ^Shader, name: cstring, val: bool) {
    set_int(shader, name, cast(i32)val)
}

set_vec2f :: proc(shader: ^Shader, name: cstring, val1: f32, val2: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform2f(loc, val1, val2)
}

set_vec3f :: proc(shader: ^Shader, name: cstring, val1: f32, val2: f32, val3: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform3f(loc, val1, val2, val3)
}

set_vec3fv :: proc(shader: ^Shader, name: cstring, vec: m.vec3) {
    vec := vec
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform3fv(loc, 1, raw_data(&vec))
}

set_vec4f :: proc(shader: ^Shader, name: cstring, val1: f32, val2: f32, val3: f32, val4: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform4f(loc, val1, val2, val3, val4)
}

set_vec4fv :: proc(shader: ^Shader, name: cstring, vec: m.vec4) {
    vec := vec
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform4fv(loc, 1, raw_data(&vec))
}
