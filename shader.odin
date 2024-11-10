#+feature dynamic-literals
package zephr

import "core:container/queue"
import "core:log"
import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:os"
import "core:strings"

import "logger"

import gl "vendor:OpenGL"

USING_GLES :: #config(USING_GLES, ODIN_PLATFORM_SUBTARGET == .Android)

when RELEASE_BUILD || ODIN_PLATFORM_SUBTARGET == .Android {
    g_shaders := [ShaderFileType]ShaderFile{
        .UI_VERT = { src = #load("assets/shaders/ui.vert"), type = .VERT },
        .UI_FRAG = { src = #load("assets/shaders/ui.frag"), type = .FRAG },
        .FONT_VERT = { src = #load("assets/shaders/font.vert"), type = .VERT },
        .FONT_FRAG = { src = #load("assets/shaders/font.frag"), type = .FRAG },
        .COLOR_CHOOSER = { src = #load("assets/shaders/color_chooser.frag"), type = .FRAG },
        .MESH_VERT = { src = #load("assets/shaders/mesh.vert"), type = .VERT },
        .MESH_FRAG = { src = #load("assets/shaders/mesh.frag"), type = .FRAG },
    }
} else {
    g_shaders := [ShaderFileType]ShaderFile{
        .UI_VERT = { path = "assets/shaders/ui.vert", type = .VERT },
        .UI_FRAG = { path = "assets/shaders/ui.frag", type = .FRAG },
        .FONT_VERT = { path = "assets/shaders/font.vert", type = .VERT },
        .FONT_FRAG = { path = "assets/shaders/font.frag", type = .FRAG },
        .COLOR_CHOOSER = { path = "assets/shaders/color_chooser.frag", type = .FRAG },
        .MESH_VERT = { path = "assets/shaders/mesh.vert", type = .VERT },
        .MESH_FRAG = { path = "assets/shaders/mesh.frag", type = .FRAG },
    }
}

@(rodata)
shader_type_to_gl_type := [ShaderType]gl.Shader_Type{
    .VERT = .VERTEX_SHADER,
    .FRAG = .FRAGMENT_SHADER,
    .GEOM = .GEOMETRY_SHADER,
}

extension_to_shader_type := map[string]ShaderType {
    ".vert" = .VERT,
    ".frag" = .FRAG,
    ".geom" = .GEOM,
}

ShaderFileType :: enum {
    UI_VERT,
    UI_FRAG,
    FONT_VERT,
    FONT_FRAG,
    COLOR_CHOOSER,
    MESH_VERT,
    MESH_FRAG,
}

ShaderType :: enum {
    VERT,
    FRAG,
    GEOM,
}

ShaderFile :: struct {
    path: string,
    src:  string,
    type: ShaderType,
}

Shader :: struct {
    program:       u32,
    files: [ShaderType]ShaderFile,
}

preprocess_shaders :: proc() {
    for type in ShaderFileType {
        when RELEASE_BUILD || ODIN_PLATFORM_SUBTARGET == .Android {
            shader_src := g_shaders[type].src
            when USING_GLES {
                g_shaders[type].src = strings.join({"#version 320 es\nprecision mediump float;\n", shader_src}, "")
            } else {
                g_shaders[type].src = strings.join({"#version 330 core\n", shader_src}, "")
            }
        } else {
            shader := g_shaders[type]
            shader_asset := get_asset(shader.path)
            defer free_asset(shader_asset)
            delete(g_shaders[type].src)

            g_shaders[type].src = strings.join({"#version 330 core\n", string(shader_asset.data)}, "")
        }
    }
}

create_shader :: proc(shader_files: []ShaderFile) -> (shader: ^Shader, ok: bool) {
    shader = new(Shader)
    shader_ids := make([]u32, len(shader_files))
    defer delete(shader_ids)

    for sh, i in shader_files {
        id, _ok := gl.compile_shader_from_source(sh.src, shader_type_to_gl_type[sh.type])
        shader_ids[i] = id
        if !_ok {
            compile_msg, compile_type, link_msg, link_type := gl.get_last_error_messages()

            log.error("Failed to create shader")
            log.error("\tCompile message:", compile_msg)
            log.error("\tShader type:", compile_type)
            log.error("\tLink message:", link_msg)
            log.error("\tShader type:", link_type)
        }
    }

    defer for id in shader_ids {
        gl.DeleteShader(id)
    }

    program, _ok := gl.create_and_link_program(shader_ids)

    if !_ok {
        compile_msg, compile_type, link_msg, link_type := gl.get_last_error_messages()

        log.error("Failed to create shader")
        log.error("\tCompile message:", compile_msg)
        log.error("\tShader type:", compile_type)
        log.error("\tLink message:", link_msg)
        log.error("\tShader type:", link_type)
    }

    // Attach program and the data about the shader files to the shader.
    shader.program = program
    for file in shader_files {
        shader.files[file.type] = file
    }

    append(&zephr_ctx.shaders, shader)

    return shader, true
}

update_shader :: proc(shader: ^Shader, shader_files: []ShaderFile) -> bool {
    shader_ids := make([]u32, len(shader_files))
    defer delete(shader_ids)

    for sh, i in shader_files {
        shader_ids[i] = gl.compile_shader_from_source(sh.src, shader_type_to_gl_type[sh.type]) or_return
    }

    defer for id in shader_ids {
        gl.DeleteShader(id)
    }

    program := gl.create_and_link_program(shader_ids) or_return

    gl.DeleteProgram(shader.program)
    shader.program = program

    return true
}

@(private, disabled = RELEASE_BUILD || ODIN_PLATFORM_SUBTARGET == .Android)
update_shaders_if_changed :: proc() {
    when ODIN_PLATFORM_SUBTARGET != .Android {
    context.logger = logger.logger

    if queue.len(zephr_ctx.changed_shaders_queue) == 0 {
        return
    }

    file := queue.front_ptr(&zephr_ctx.changed_shaders_queue)
    queue.pop_front(&zephr_ctx.changed_shaders_queue)

    if file != nil {
        for shader in &zephr_ctx.shaders {
            if filepath.base(shader.files[.VERT].path) == file^ || filepath.base(shader.files[.FRAG].path) == file^ || filepath.base(shader.files[.GEOM].path) == file^ {
                log.debugf("Hot-reloading shaders that depend on \"%s\"", file^)

                type := extension_to_shader_type[filepath.ext(file^)]
                shader_files := make([dynamic]ShaderFile, 0, len(shader.files))
                defer delete(shader_files)

                shader_asset := get_asset(shader.files[type].path)
                defer free_asset(shader_asset)
                if len(shader_asset.data) == 0 {
                    log.errorf(
                        "Failed to hot-reload shader with ID %d (File read error). Vert: \"%s\", Frag: \"%s\", Geom: \"%s\". ",
                        shader.program,
                        shader.files[.VERT].path,
                        shader.files[.FRAG].path,
                        shader.files[.GEOM].path,
                    )

                    return
                }

                delete(shader.files[type].src)
                shader.files[type].src = strings.join({"#version 330 core\n", string(shader_asset.data)}, "")

                for file in shader.files {
                    if file.path == "" {
                        continue
                    }
                    append(&shader_files, file)
                }

                new_shader_ok := update_shader(shader, shader_files[:])

                if !new_shader_ok {
                    log.errorf(
                        "Failed to hot-reload shader with ID %d (Compilation error). Vert: \"%s\", Frag: \"%s\", Geom: \"%s\". ",
                        shader.program,
                        shader.files[.VERT].path,
                        shader.files[.FRAG].path,
                        shader.files[.GEOM].path,
                    )

                    return
                }
            }
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
