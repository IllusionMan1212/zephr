package zephr

import "core:log"

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

TextureId :: u32

load_texture :: proc(path: cstring) -> TextureId {
  context.logger = logger

  texture_id: TextureId
  width, height, channels: i32
  data := stb.load(path, &width, &height, &channels, 0)
  if data == nil {
    log.errorf("Failed to load texture: \"%s\"", path)
  }
  defer stb.image_free(data)

  format := gl.RGBA

  switch (channels) {
    case 1:
      format = gl.RED
      break
    case 2:
      format = gl.RG
      break
    case 3:
      format = gl.RGB
      break
    case 4:
      format = gl.RGBA
      break
  }

  gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

  gl.GenTextures(1, &texture_id)
  gl.BindTexture(gl.TEXTURE_2D, texture_id)

  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

  gl.TexImage2D(gl.TEXTURE_2D, 0, cast(i32)format, width, height, 0, cast(u32)format, gl.UNSIGNED_BYTE, data)

  gl.GenerateMipmap(gl.TEXTURE_2D)

  gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

  return texture_id
}
