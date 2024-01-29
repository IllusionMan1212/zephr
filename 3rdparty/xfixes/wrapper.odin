// +build linux
package xfixes

import x11 "vendor:x11/xlib"
foreign import xfixes "system:Xfixes"

foreign xfixes {
  @(link_name = "XFixesHideCursor")
  HideCursor :: proc(display: ^x11.Display, window: x11.Window) ---
  @(link_name = "XFixesShowCursor")
  ShowCursor :: proc(display: ^x11.Display, window: x11.Window) ---
}
