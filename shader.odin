package zephr

import m "core:math/linalg/glsl"

import gl "vendor:OpenGL"

Shader :: struct {
    program: u32,
}

create_shader :: proc(vertex_path: string, fragment_path: string) -> (Shader, bool) {
    shader: Shader

    program, success := gl.load_shaders(vertex_path, fragment_path)
    shader.program = program

    return shader, success
}

use_shader :: proc(shader: Shader) {
    gl.UseProgram(shader.program)
}

set_mat4f :: proc(shader: Shader, name: cstring, mat4: m.mat4, transpose: bool = false) {
    mat4 := mat4
    loc := gl.GetUniformLocation(shader.program, name)
    gl.UniformMatrix4fv(loc, 1, transpose, raw_data(&mat4))
}

set_float :: proc(shader: Shader, name: cstring, val: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1f(loc, val)
}

set_int :: proc(shader: Shader, name: cstring, val: i32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform1i(loc, val)
}

set_bool :: proc(shader: Shader, name: cstring, val: bool) {
    set_int(shader, name, cast(i32)val)
}

set_vec2f :: proc(shader: Shader, name: cstring, val1: f32, val2: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform2f(loc, val1, val2)
}

set_vec3f :: proc(shader: Shader, name: cstring, val1: f32, val2: f32, val3: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform3f(loc, val1, val2, val3)
}

set_vec4f :: proc(shader: Shader, name: cstring, val1: f32, val2: f32, val3: f32, val4: f32) {
    loc := gl.GetUniformLocation(shader.program, name)
    gl.Uniform4f(loc, val1, val2, val3, val4)
}
