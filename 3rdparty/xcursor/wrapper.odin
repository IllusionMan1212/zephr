// +build linux
package xcursor

import x11 "vendor:x11/xlib"
foreign import xcursor "system:Xcursor"

foreign xcursor {
    @(link_name = "XcursorLibraryLoadCursor")
    LibraryLoadCursor :: proc(display: ^x11.Display, name: cstring) -> x11.Cursor ---
}
