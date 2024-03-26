// based on system packaged freetype 2.11.1 on Ubuntu 22.04
// @INCOMPLETE
package freetype

when ODIN_OS == .Linux {foreign import freetype "system:freetype"}
when ODIN_OS == .Windows {foreign import freetype "libs/freetype.lib"}

@(link_prefix = "FT_")
foreign freetype {
    Init_FreeType :: proc(lib: ^Library) -> FT_Error ---
    New_Face :: proc(lib: Library, file_pathname: cstring, face_index: FT_Long, face: ^Face) -> FT_Error ---
    Set_Pixel_Sizes :: proc(face: Face, pixel_width: FT_UInt, pixel_height: FT_UInt) -> FT_Error ---
    Load_Char :: proc(face: Face, char_code: ULong, load_flags: LoadFlags) -> FT_Error ---
    Render_Glyph :: proc(slot: FT_GlyphSlot, render_mode: FT_Render_Mode_) -> FT_Error ---
    Done_Face :: proc(face: Face) -> FT_Error ---
    Done_FreeType :: proc(lib: Library) -> FT_Error ---
}
