package zephr

import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:log"
import "core:strings"

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

@(private = "file")
vao: u32
@(private = "file")
vbo: u32
@(private = "file")
ebo: u32
@(private = "file")
ui_shader: ^Shader

@(private)
init_drawing :: proc() {
    indices := [6]u32{0, 1, 2, 2, 3, 1}

    shader, ok := create_shader({g_shaders[.UI_VERT], g_shaders[.UI_FRAG]})
    if !ok {
        log.error("Failed to load ui shaders")
        return
    }
    ui_shader = shader

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.EnableVertexAttribArray(3)
    gl.EnableVertexAttribArray(4)
    gl.EnableVertexAttribArray(5)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), 0)
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4))
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4) * 2)
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4) * 3)
    gl.VertexAttribPointer(4, 4, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4) * 4)
    gl.VertexAttribPointer(5, 2, gl.FLOAT, gl.FALSE, size_of(DrawableInstance), size_of(m.vec4) * 5)
    gl.VertexAttribDivisor(0, 1)
    gl.VertexAttribDivisor(1, 1)
    gl.VertexAttribDivisor(2, 1)
    gl.VertexAttribDivisor(3, 1)
    gl.VertexAttribDivisor(4, 1)
    gl.VertexAttribDivisor(5, 1)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

    gl.BindVertexArray(0)
}

@(private)
instance_rect :: proc(rect: Rect, color: Color, border_thickness: f32, border_smoothness: f32) {
    inst: DrawableInstance
    inst.rect = rect
    inst.colors[0] = color
    inst.colors[1] = color
    inst.colors[2] = color
    inst.colors[3] = color
    inst.border_thickness = border_thickness
    inst.border_smoothness = border_smoothness

    append(&ui_state.curr_draw_cmd.drawables, inst)
}

@(private)
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

ui_draw :: proc(projection: m.mat4) {
    projection := projection

    root := ui_state.root

    iter_children :: proc(node: ^Box) {
        for child := node.first; child != nil; child = child.next {
            if .DrawBackground in child.flags {
                instance_rect(child.rect, child.background_color, 0, 0)
            }

            if .DrawBorder in child.flags {
                instance_rect(child.rect, child.border_color, child.border_thickness, child.border_smoothness)
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

    use_shader(ui_shader)
    set_mat4f(ui_shader, "projection", projection)
    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    // Append the last remaining draw command if we have any.
    if len(ui_state.curr_draw_cmd.drawables) > 0 {
        append(&ui_state.draw_cmds, ui_state.curr_draw_cmd)
    }

    for cmd in ui_state.draw_cmds {
        gl.BufferData(gl.ARRAY_BUFFER, size_of(DrawableInstance) * len(cmd.drawables), raw_data(cmd.drawables), gl.STATIC_DRAW)
        if cmd.has_texture {
            set_int(ui_shader, "blur", cast(i32)cmd.blur)
            set_int(ui_shader, "hasTexture", 1)
            gl.BindTexture(gl.TEXTURE_2D, cmd.tex)
        } else {
            set_int(ui_shader, "hasTexture", 0)
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
