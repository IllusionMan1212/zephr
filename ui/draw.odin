package zephr_ui

import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:log"
import "core:strings"
import "../logger"

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

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

load_texture :: proc(
    path: string,
    is_diffuse: bool,
    generate_mipmap := true,
    wrap_s: i32 = gl.REPEAT,
    wrap_t: i32 = gl.REPEAT,
    min_filter: i32 = gl.LINEAR_MIPMAP_LINEAR,
    mag_filter: i32 = gl.LINEAR,
) -> TextureId {
    context.logger = logger.logger

    texture_id: TextureId
    width, height, channels: i32
    path_c_str := strings.clone_to_cstring(path, context.temp_allocator)
    data := stb.load(path_c_str, &width, &height, &channels, 0)
    if data == nil {
        log.errorf("Failed to load texture: \"%s\"", path)
        return 0
    }
    defer stb.image_free(data)

    format := gl.RGBA
    internal_format := gl.RGBA8

    switch (channels) {
        case 1:
            format = gl.RED
            internal_format = gl.R8
            break
        case 2:
            format = gl.RG
            internal_format = gl.RG8
            break
        case 3:
            format = gl.RGB
            internal_format = gl.SRGB8
            break
        case 4:
            format = gl.RGBA
            internal_format = gl.SRGB8_ALPHA8
            break
    }

    if !is_diffuse {
        internal_format = format
    }
    min_filter := min_filter
    if min_filter == gl.LINEAR_MIPMAP_LINEAR && !generate_mipmap {
        min_filter = gl.LINEAR
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    gl.GenTextures(1, &texture_id)
    gl.BindTexture(gl.TEXTURE_2D, texture_id)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_s)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_t)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, min_filter)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, mag_filter)

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        cast(i32)internal_format,
        width,
        height,
        0,
        cast(u32)format,
        gl.UNSIGNED_BYTE,
        data,
    )

    if generate_mipmap {
        gl.GenerateMipmap(gl.TEXTURE_2D)
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

    return texture_id
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
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), 0)
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4))
    gl.VertexAttribIPointer(2, 1, gl.INT, size_of(DrawableInstance), size_of(m.vec4) + (size_of(m.vec4) * 4))
    gl.VertexAttribDivisor(0, 1)
    gl.VertexAttribDivisor(1, 1)
    gl.VertexAttribDivisor(2, 1)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

    gl.BindVertexArray(0)
}

instance_rect :: proc(rect: Rect, color: Color, border_thickness: int) {
    inst: DrawableInstance
    inst.rect = rect
    inst.colors[0] = color
    inst.colors[1] = color
    inst.colors[2] = color
    inst.colors[3] = color
    inst.border_thickness = border_thickness

    append(&ui_state.curr_draw_cmd.drawables, inst)
}

instance_image :: proc(rect: Rect, texture: TextureId, tint: Color, blur: int) {
    inst: DrawableInstance
    inst.rect = rect
    inst.colors[0] = tint
    inst.colors[1] = tint
    inst.colors[2] = tint
    inst.colors[3] = tint
    //inst.has_texture = true

    /* TODO: here's an idea of how to add texture atlas images in the same draw command.
        if the draw command somehow doesn't have rects then
            do what we do now
        else if the draw command has a texture and that texture matches the new texture then
            don't create a new draw command and instead just append to the existing one.

        This still needs some thinking because we need to know when to push the draw command with a lot of instaces 
        of the same texture. We also need to know if this image is allowed to be drawn with regular rects (i.e. icon atlas
        should be allowed to be drawn with regular rects because the icons and the rects will use the same one texture.)

        RADDBG uses a bucket system with nodes that's confusing but it seems like each bucket groups nodes and instaces 
        of rects that can be drawn with a single drawcall somehow, so it checks if the current bucket generation is the 
        same as the last command's generation. Maybe we can somehow emulate that. idk.
    */

    append(&ui_state.draw_cmds, ui_state.curr_draw_cmd)
    ui_state.curr_draw_cmd = {}
    ui_state.curr_draw_cmd.has_texture = true
    ui_state.curr_draw_cmd.tex = texture
    ui_state.curr_draw_cmd.blur = blur

    append(&ui_state.curr_draw_cmd.drawables, inst)
    append(&ui_state.draw_cmds, ui_state.curr_draw_cmd)
    ui_state.curr_draw_cmd = {}
}

draw :: proc(projection: m.mat4) {
    context.logger = logger.logger
    projection := projection

    root := ui_state.root

    iter_children :: proc(node: ^Box) {
        for child := node.first; child != nil; child = child.next {
            // TODO: passing the border thickness here isn't needed.
            if .DrawBorder in child.flags {
                instance_rect(child.rect, child.border_color, 2)
            }

            // TODO: make this configurable ??? or just hardcode it to 1px. OR just implement the border in the shader. IDK
            if .DrawBackground in child.flags {
                new_rect := child.rect
                if .DrawBorder in child.flags {
                    new_rect.min += 2
                    new_rect.max -= 2
                }
                instance_rect(new_rect, child.background_color, 0)
            }

            if child.custom_draw != nil {
                child.custom_draw(child, child.custom_draw_user_data)
            }

            //for box := child; box != nil; box = box.parent {
            //}

            iter_children(child)
        }
    }

    iter_children(root)

    gl.UseProgram(ui_shader)
    gl.UniformMatrix4fv(gl.GetUniformLocation(ui_shader, "projection"), 1, false, raw_data(&projection))
    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    // Append the last remaining draw command if we have any.
    if len(ui_state.curr_draw_cmd.drawables) > 0 {
        append(&ui_state.draw_cmds, ui_state.curr_draw_cmd)
    }

    for cmd in ui_state.draw_cmds {
        gl.BufferData(gl.ARRAY_BUFFER, size_of(DrawableInstance) * len(cmd.drawables), raw_data(cmd.drawables), gl.STATIC_DRAW)
        if cmd.has_texture {
            gl.Uniform1i(gl.GetUniformLocation(ui_shader, "blur"), cast(i32)cmd.blur)
            gl.Uniform1i(gl.GetUniformLocation(ui_shader, "hasTexture"), 1)
            gl.BindTexture(gl.TEXTURE_2D, cmd.tex)
        } else {
            gl.Uniform1i(gl.GetUniformLocation(ui_shader, "hasTexture"), 0)
        }
        gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, cast(i32)len(cmd.drawables))

        gl.BindTexture(gl.TEXTURE_2D, 0)

        delete(cmd.drawables)
    }

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    ui_state.curr_draw_cmd = {}
    clear(&ui_state.draw_cmds)
}
