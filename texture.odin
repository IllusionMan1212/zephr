package zephr

import "core:log"

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

TextureId :: u32

load_texture :: proc(
    path: string,
    is_diffuse: bool,
    generate_mipmap := true,
    wrap_s: i32 = gl.REPEAT,
    wrap_t: i32 = gl.REPEAT,
    min_filter: i32 = gl.LINEAR_MIPMAP_LINEAR,
    mag_filter: i32 = gl.LINEAR,
) -> TextureId {
    context.logger = logger

    texture_id: TextureId
    width, height, channels: i32
    data := stb.load(cstring(raw_data(path)), &width, &height, &channels, 0)
    if data == nil {
        log.errorf("Failed to load texture: \"%s\"", path)
        return 0
    }
    defer stb.image_free(data)

    format := gl.RGBA
    internal_format := gl.RGBA

    switch (channels) {
        case 1:
            format = gl.RED
            internal_format = gl.RED
            break
        case 2:
            format = gl.RG
            internal_format = gl.RG
            break
        case 3:
            format = gl.RGB
            internal_format = gl.SRGB
            break
        case 4:
            format = gl.RGBA
            internal_format = gl.SRGB_ALPHA
            break
    }

    if !is_diffuse {
        internal_format = format
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

    gl.GenerateMipmap(gl.TEXTURE_2D)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

    return texture_id
}

load_texture_from_memory :: proc(
    tex_data: rawptr,
    tex_data_len: i32,
    is_diffuse: bool,
    generate_mipmap := true,
    wrap_s: i32 = gl.REPEAT,
    wrap_t: i32 = gl.REPEAT,
    min_filter: i32 = gl.LINEAR_MIPMAP_LINEAR,
    mag_filter: i32 = gl.LINEAR,
) -> TextureId {
    context.logger = logger

    texture_id: TextureId
    width, height, channels: i32
    data := stb.load_from_memory(transmute([^]byte)tex_data, tex_data_len, &width, &height, &channels, 0)
    if data == nil {
        log.error("Failed to load embedded texture")
        return 0
    }
    defer stb.image_free(data)

    format := gl.RGBA
    internal_format := gl.RGBA

    switch (channels) {
        case 1:
            format = gl.RED
            internal_format = gl.RED
            break
        case 2:
            format = gl.RG
            internal_format = gl.RG
            break
        case 3:
            format = gl.RGB
            internal_format = gl.SRGB
            break
        case 4:
            format = gl.RGBA
            internal_format = gl.SRGB_ALPHA
            break
    }

    if !is_diffuse {
        internal_format = format
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

    gl.GenerateMipmap(gl.TEXTURE_2D)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

    return texture_id
}

load_cubemap :: proc(faces_paths: [6]string) -> TextureId {
    cubemap_tex_id: TextureId
    width, height, nr_channels: i32

    gl.GenTextures(1, &cubemap_tex_id)
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, cubemap_tex_id)

    for face, i in faces_paths {
        data := stb.load(cstring(raw_data(face)), &width, &height, &nr_channels, 0)
        if data == nil {
            log.errorf("Failed to load cubemap texture: \"%s\"", face)
            return 0
        }

        gl.TexImage2D(
            gl.TEXTURE_CUBE_MAP_POSITIVE_X + cast(u32)i,
            0,
            gl.RGB,
            width,
            height,
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            data,
        )
    }

    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)

    return cubemap_tex_id
}
