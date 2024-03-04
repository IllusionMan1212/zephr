// +build linux
package xrandr

import x11 "vendor:x11/xlib"

foreign import xrandr "system:Xrandr"

foreign xrandr {
    XRRSizes :: proc(display: ^x11.Display, screen: i32, nsizes: ^i32) -> [^]XRRScreenSize ---
    XRRGetScreenResources :: proc(display: ^x11.Display, window: x11.Window) -> ^XRRScreenResources ---
    XRRFreeScreenResources :: proc(resources: ^XRRScreenResources) ---
    XRRGetOutputInfo :: proc(display: ^x11.Display, resources: ^XRRScreenResources, output: RROutput) -> ^XRROutputInfo ---
    XRRFreeOutputInfo :: proc(output_info: ^XRROutputInfo) ---
    XRRGetCrtcInfo :: proc(display: ^x11.Display, resources: ^XRRScreenResources, crtc: RRCrtc) -> ^XRRCrtcInfo ---
    XRRFreeCrtcInfo :: proc(crtc_info: ^XRRCrtcInfo) ---
}
