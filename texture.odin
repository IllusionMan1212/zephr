package zephr

import "core:log"
import "core:mem"
import "core:net"
import "core:path/filepath"
import "core:strings"

import gl "vendor:OpenGL"
import "vendor:cgltf"
import stb "vendor:stb/image"

TextureType :: enum {
    DIFFUSE,
    SPECULAR,
    NORMAL,
    METALLIC_ROUGHNESS,
    EMISSIVE,
}

Texture :: struct {
    id:   TextureId,
    type: TextureType,
}

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
    path_c_str := strings.clone_to_cstring(path, context.temp_allocator)
    data := stb.load(path_c_str, &width, &height, &channels, 0)
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
        face_c_str := strings.clone_to_cstring(face, context.temp_allocator)
        data := stb.load(face_c_str, &width, &height, &nr_channels, 0)
        if data == nil {
            log.errorf("Failed to load cubemap texture: \"%s\"", face)
            return 0
        }
        defer stb.image_free(data)

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

// TODO: multithread this for faster model loading
@(private)
process_texture :: proc(
    tex: ^cgltf.texture,
    type: TextureType,
    gltf_file_path: cstring,
    textures_map: ^map[cstring]TextureId,
) -> Texture {
    context.logger = logger

    texture := Texture {
        type = type,
        id   = 0,
    }

    // TODO: handle the case where the texture is already loaded for embedded textures (.glb)

    if tex.image_.uri in textures_map {
        texture.id = textures_map[tex.image_.uri]
        log.debug("tex already loaded:", tex.image_.uri)
    } else {
        sampler := tex.sampler

        if tex.image_.buffer_view == nil {
            image_uri, _ := net.percent_decode(string(tex.image_.uri))
            is_absolute := filepath.is_abs(image_uri)
            tex_path :=
                is_absolute ? image_uri : filepath.join([]string{filepath.dir(string(gltf_file_path)), image_uri})

            if sampler != nil {
                texture.id = load_texture(
                    tex_path,
                    type == .DIFFUSE || type == .EMISSIVE,
                    true,
                    sampler.wrap_s != 0 ? sampler.wrap_s : gl.REPEAT,
                    sampler.wrap_t != 0 ? sampler.wrap_t : gl.REPEAT,
                    sampler.min_filter != 0 ? sampler.min_filter : gl.LINEAR_MIPMAP_LINEAR,
                    sampler.mag_filter != 0 ? sampler.mag_filter : gl.LINEAR,
                )
            } else {
                texture.id = load_texture(tex_path, type == .DIFFUSE || type == .EMISSIVE)
            }

            textures_map[tex.image_.uri] = texture.id
        } else {
            data := mem.ptr_offset(transmute([^]byte)tex.image_.buffer_view.buffer.data, tex.image_.buffer_view.offset)
            data_len := tex.image_.buffer_view.size

            if sampler != nil {
                texture.id = load_texture_from_memory(
                    data,
                    cast(i32)data_len,
                    type == .DIFFUSE || type == .EMISSIVE,
                    true,
                    sampler.wrap_s != 0 ? sampler.wrap_s : gl.REPEAT,
                    sampler.wrap_t != 0 ? sampler.wrap_t : gl.REPEAT,
                    sampler.min_filter != 0 ? sampler.min_filter : gl.LINEAR_MIPMAP_LINEAR,
                    sampler.mag_filter != 0 ? sampler.mag_filter : gl.LINEAR,
                )
            } else {
                texture.id = load_texture_from_memory(data, cast(i32)data_len, type == .DIFFUSE || type == .EMISSIVE)
            }
        }
    }

    return texture
}
