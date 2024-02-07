// +build linux
package xinput2

import x11 "vendor:x11/xlib"

foreign import xinput2 "system:Xi"

@(link_prefix = "XI")
foreign xinput2 {
    SelectEvents :: proc(display: ^x11.Display, window: x11.Window, masks: [^]EventMask, num_masks: i32) -> i32 ---
    QueryVersion :: proc(display: ^x11.Display, major: ^i32, minor: ^i32) -> x11.Status ---
}

SetMask :: proc(ptr: [^]u8, event: EventType) {
    ptr[cast(i32)event >> 3] |= (1 << cast(uint)((cast(i32)event) & 7))
}

MaskIsSet :: proc(ptr: [^]u8, event: i32) -> bool {
    return (ptr[event >> 3] & (1 << cast(uint)((event) & 7))) != 0
}
