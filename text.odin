package zephr

import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:path/filepath"
import "core:strings"

import gl "vendor:OpenGL"

import FT "3rdparty/freetype"

Character :: struct {
    size:       m.vec2,
    bearing:    m.vec2,
    advance:    u32,
    tex_coords: [4]m.vec2,
}

Font :: struct {
    atlas_tex_id: TextureId,
    characters:   [128]Character,
}

// GlyphInstance needs to be 100 bytes (meaning no padding) otherwise the data we send to the shader
// is misaligned and we get rendering errors
#assert(size_of(GlyphInstance) == 100)

GlyphInstance :: struct #packed {
    pos:            m.vec4,
    tex_coords_idx: u32,
    color:          m.vec4,
    model:          m.mat4,
}

GlyphInstanceList :: [dynamic]GlyphInstance

@(private)
FONT_PIXEL_SIZE :: 100
@(private)
LINE_HEIGHT :: 2.0

@(private)
font_shader: ^Shader
@(private)
font_vao: u32
@(private)
font_instance_vbo: u32


init_freetype :: proc(font_path: cstring) -> i32 {
    context.logger = logger

    ft: FT.Library
    if (FT.Init_FreeType(&ft) != 0) {
        return -1
    }

    face: FT.Face
    err := FT.New_Face(ft, font_path, 0, &face)
    if (err != 0) {
        log.errorf("FT.New_Face returned: %d", err)
        return -2
    }

    // sets the variable font to be bold
    /* if ((face->face_flags & FT_FACE_FLAG_MULTIPLE_MASTERS)) { */
    /*   printf("[INFO] Got a variable font\n"); */
    /*   FT_MM_Var *mm; */
    /*   FT_Get_MM_Var(face, &mm); */

    /*   FT_Set_Var_Design_Coordinates(face, mm->num_namedstyles, mm->namedstyle[mm->num_namedstyles - 4].coords); */

    /*   FT_Done_MM_Var(ft, mm); */
    /* } */

    FT.Set_Pixel_Sizes(face, 0, FONT_PIXEL_SIZE)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    pen_x, pen_y: u32

    /* FT_UInt glyph_idx; */
    /* FT_ULong c = FT_Get_First_Char(face, &glyph_idx); */

    tex_width, tex_height: u32
    for i in 32 ..< 128 {
        if (FT.Load_Char(face, cast(FT.ULong)i, .RENDER) != 0) {
            log.errorf("Failed to load glyph for char '0x%x'", i)
        }

        /* FT_Render_Glyph(face->glyph, FT_RENDER_MODE_SDF); */

        tex_width += face.glyph.bitmap.width + 1
        tex_height = max(tex_height, face.glyph.bitmap.rows)
    }

    pixels := make([dynamic]u8, tex_width * tex_height)
    defer delete(pixels)

    for i in 32 ..< 128 {
        /* while (glyph_idx) { */
        if (FT.Load_Char(face, cast(FT.ULong)i, .RENDER) != 0) {
            log.errorf("Failed to load glyph for char '0x%x'", i)
        }

        /* FT_Render_Glyph(face->glyph, FT_RENDER_MODE_SDF); */

        bmp := &face.glyph.bitmap

        if (pen_x + bmp.width >= tex_width) {
            pen_x = 0
            pen_y += cast(u32)(1 + (face.size.metrics.height >> 6))
        }

        for row in 0 ..< bmp.rows {
            for col in 0 ..< bmp.width {
                x := pen_x + col
                y := pen_y + row
                pixels[y * tex_width + x] = bmp.buffer[row * cast(u32)bmp.pitch + col]
            }
        }

        atlas_x0 := cast(f32)pen_x / cast(f32)tex_width
        atlas_y0 := cast(f32)pen_y / cast(f32)tex_height
        atlas_x1 := cast(f32)(pen_x + bmp.width) / cast(f32)tex_width
        atlas_y1 := cast(f32)(pen_y + bmp.rows) / cast(f32)tex_height

        top_left := m.vec2{atlas_x0, atlas_y1}
        top_right := m.vec2{atlas_x1, atlas_y1}
        bottom_right := m.vec2{atlas_x1, atlas_y0}
        bottom_left := m.vec2{atlas_x0, atlas_y0}

        character: Character

        character.tex_coords[0] = top_left
        character.tex_coords[1] = top_right
        character.tex_coords[2] = bottom_right
        character.tex_coords[3] = bottom_left
        character.advance = cast(u32)face.glyph.advance.x
        character.size = m.vec2{cast(f32)face.glyph.bitmap.width, cast(f32)face.glyph.bitmap.rows}
        character.bearing = m.vec2{cast(f32)face.glyph.bitmap_left, cast(f32)face.glyph.bitmap_top}

        zephr_ctx.font.characters[i] = character

        pen_x += bmp.width + 1

        /* c = FT_Get_Next_Char(face, c, &glyph_idx); */
    }

    texture: TextureId
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RED,
        cast(i32)tex_width,
        cast(i32)tex_height,
        0,
        gl.RED,
        gl.UNSIGNED_BYTE,
        raw_data(pixels),
    )

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    zephr_ctx.font.atlas_tex_id = texture

    gl.BindTexture(gl.TEXTURE_2D, 0)

    FT.Done_Face(face)
    FT.Done_FreeType(ft)

    return 0
}

init_fonts :: proc(font_path: string) -> i32 {
    context.logger = logger
    font_vbo, font_ebo: u32

    font_path_c_str := strings.clone_to_cstring(font_path, context.temp_allocator)
    res := init_freetype(font_path_c_str)
    if (res != 0) {
        return res
    }

    l_font_shader, success := create_shader(relative_path("shaders/font.vert"), relative_path("shaders/font.frag"))

    if (!success) {
        log.fatal("Failed to create font shader")
        return -2
    }

    font_shader = l_font_shader

    gl.GenVertexArrays(1, &font_vao)
    gl.GenBuffers(1, &font_vbo)
    gl.GenBuffers(1, &font_instance_vbo)
    gl.GenBuffers(1, &font_ebo)

    quad_vertices := [4][2]f32 {
        {0.0, 1.0}, // top left
        {1.0, 1.0}, // top right
        {1.0, 0.0}, // bottom right
        {0.0, 0.0}, // bottom left
    }

    quad_indices := [6]u32{0, 1, 2, 2, 3, 0}

    gl.BindVertexArray(font_vao)

    // font quad vbo
    gl.BindBuffer(gl.ARRAY_BUFFER, font_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(quad_vertices), &quad_vertices, gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), 0)

    // font instance vbo
    gl.BindBuffer(gl.ARRAY_BUFFER, font_instance_vbo)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), 0)
    gl.VertexAttribDivisor(1, 1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribIPointer(2, 1, gl.INT, size_of(GlyphInstance), size_of(m.vec4))
    gl.VertexAttribDivisor(2, 1)
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), (size_of(m.vec4) + size_of(i32)))
    gl.VertexAttribDivisor(3, 1)
    gl.EnableVertexAttribArray(4)
    gl.EnableVertexAttribArray(5)
    gl.EnableVertexAttribArray(6)
    gl.EnableVertexAttribArray(7)
    gl.VertexAttribPointer(4, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), (size_of(m.vec4) * 2 + size_of(i32)))
    gl.VertexAttribPointer(5, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), (size_of(m.vec4) * 3 + size_of(i32)))
    gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), (size_of(m.vec4) * 4 + size_of(i32)))
    gl.VertexAttribPointer(7, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), (size_of(m.vec4) * 5 + size_of(i32)))
    gl.VertexAttribDivisor(4, 1)
    gl.VertexAttribDivisor(5, 1)
    gl.VertexAttribDivisor(6, 1)
    gl.VertexAttribDivisor(7, 1)

    // font ebo
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, font_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(quad_indices), &quad_indices, gl.STATIC_DRAW)

    use_shader(font_shader)

    for i in 32 ..< 128 {
        for j in 0 ..< 4 {
            buf: [24]byte
            text := fmt.bprintf(buf[:], "texcoords[%d]", (i - 32) * 4 + j)
            text_c_str := strings.clone_to_cstring(text, context.temp_allocator)
            set_vec2f(
                font_shader,
                text_c_str,
                zephr_ctx.font.characters[i].tex_coords[j].x,
                zephr_ctx.font.characters[i].tex_coords[j].y,
            )
        }
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    return 0
}


calculate_text_size :: proc(text: string, font_size: u32) -> m.vec2 {
    scale := cast(f32)font_size / FONT_PIXEL_SIZE
    size: m.vec2 = ---
    w: f32 = 0
    h: f32 = 0
    max_bearing_h: f32 = 0

    // NOTE: I don't like looping through the characters twice, but it's fine for now
    for i in 0 ..< len(text) {
        ch := zephr_ctx.font.characters[text[i]]
        max_bearing_h = max(max_bearing_h, ch.bearing.y)
    }

    for i in 0 ..< len(text) {
        ch := zephr_ctx.font.characters[text[i]]
        w += cast(f32)ch.advance / 64

        // remove bearing of first character
        if (i == 0 && len(text) > 1) {
            w -= ch.bearing.x
        }

        // remove the trailing width of the last character
        if (i == len(text) - 1) {
            w -= ((cast(f32)ch.advance / 64) - (ch.bearing.x + ch.size.x))
        }

        // if we only have one character in the text, then remove the bearing width
        if (len(text) == 1) {
            w -= (ch.bearing.x)
        }

        h = max(h, max_bearing_h - ch.bearing.y + ch.size.y)

        if (text[i] == '\n') {
            w = 0
            h += max_bearing_h
        }
    }
    size.x = w * scale
    size.y = h * scale

    return size
}

draw_text :: proc(text: string, font_size: u32, constraints: UiConstraints, color: Color, alignment: Alignment) {
    glyph_instance_list := get_glyph_instance_list_from_text(text, font_size, constraints, color, alignment)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, zephr_ctx.font.atlas_tex_id)
    gl.BindVertexArray(font_vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, font_instance_vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        size_of(GlyphInstance) * len(glyph_instance_list),
        raw_data(glyph_instance_list),
        gl.DYNAMIC_DRAW,
    )

    gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, cast(i32)len(glyph_instance_list))

    gl.BindVertexArray(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)

    delete(glyph_instance_list)
}

draw_text_batch :: proc(batch: ^GlyphInstanceList) {
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, zephr_ctx.font.atlas_tex_id)
    gl.BindVertexArray(font_vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, font_instance_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(GlyphInstance) * len(batch), raw_data(batch^), gl.DYNAMIC_DRAW)

    gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, cast(i32)len(batch))

    gl.BindVertexArray(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)

    delete(batch^)
}

get_glyph_instance_list_from_text :: proc(
    text: string,
    font_size: u32,
    constraints: UiConstraints,
    color: Color,
    alignment: Alignment,
) -> GlyphInstanceList {
    constraints := constraints
    use_shader(font_shader)
    text_color := m.vec4 {
        cast(f32)color.r / 255,
        cast(f32)color.g / 255,
        cast(f32)color.b / 255,
        cast(f32)color.a / 255,
    }

    set_mat4f(font_shader, "projection", zephr_ctx.projection)

    rect: Rect

    apply_constraints(&constraints, &rect.pos, &rect.size)

    text_size := calculate_text_size(text, FONT_PIXEL_SIZE)
    font_scale := cast(f32)font_size / FONT_PIXEL_SIZE * rect.size.x

    apply_alignment(alignment, &constraints, m.vec2{text_size.x * font_scale, text_size.y * font_scale}, &rect.pos)

    model := m.identity(m.mat4)
    model = m.mat4Scale(m.vec3{font_scale, font_scale, 1}) * model

    model = m.mat4Translate(m.vec3{-text_size.x * font_scale / 2, -text_size.y * font_scale / 2, 0}) * model
    model = m.mat4Scale(m.vec3{constraints.scale.x, constraints.scale.y, 1}) * model
    model = m.mat4Translate(m.vec3{text_size.x * font_scale / 2, text_size.y * font_scale / 2, 0}) * model

    // rotate around the center point of the text
    model = m.mat4Translate(m.vec3{-text_size.x * font_scale / 2, -text_size.y * font_scale / 2, 0}) * model
    model = m.mat4Rotate(m.vec3{0, 0, 1}, m.radians(constraints.rotation)) * model
    model = m.mat4Translate(m.vec3{text_size.x * font_scale / 2, text_size.y * font_scale / 2, 0}) * model

    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    max_bearing_h: f32 = 0
    for i in 0 ..< len(text) {
        ch := zephr_ctx.font.characters[text[i]]
        max_bearing_h = max(max_bearing_h, ch.bearing.y)
    }

    first_char_bearing_w := zephr_ctx.font.characters[text[0]].bearing.x

    glyph_instance_list: GlyphInstanceList
    reserve(&glyph_instance_list, 16)

    // we use the original text and character sizes in the loop and then we just
    // scale up or down the model matrix to get the desired font size.
    // this way everything works out fine and we get to transform the text using the
    // model matrix
    c := 0
    x: u32 = 0
    y: f32 = 0
    for c != len(text) {
        ch := zephr_ctx.font.characters[text[c]]
        // subtract the bearing width of the first character to remove the extra space
        // at the start of the text and move every char to the left by that width
        xpos := (cast(f32)x + (ch.bearing.x - first_char_bearing_w))
        ypos := y + (text_size.y - ch.bearing.y - (text_size.y - max_bearing_h))

        if (text[c] == '\n') {
            x = 0
            y += max_bearing_h + (36 * LINE_HEIGHT)
            c += 1
            continue
        }

        instance := GlyphInstance {
            pos            = m.vec4{xpos, ypos, ch.size.x, ch.size.y},
            tex_coords_idx = cast(u32)text[c] - 32,
            color          = text_color,
            model          = model,
        }

        append(&glyph_instance_list, instance)

        x += (ch.advance >> 6)
        c += 1
    }

    return glyph_instance_list
}

add_text_instance :: proc(
    batch: ^GlyphInstanceList,
    text: string,
    font_size: u32,
    constraints: UiConstraints,
    color: Color,
    alignment: Alignment,
) {
    glyph_instance_list := get_glyph_instance_list_from_text(text, font_size, constraints, color, alignment)

    append(batch, ..glyph_instance_list[:])

    delete(glyph_instance_list)
}
