// +build linux
package xfixes

import x11 "vendor:x11/xlib"
foreign import xfixes "system:Xfixes"

@(link_prefix = "XFixes")
foreign xfixes {
    HideCursor :: proc(display: ^x11.Display, window: x11.Window) ---
    ShowCursor :: proc(display: ^x11.Display, window: x11.Window) ---
}
