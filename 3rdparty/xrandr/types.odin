package xrandr

import x11 "vendor:x11/xlib"

RROutput :: x11.XID
RRCrtc :: x11.XID
RRMode :: x11.XID

Rotation :: u16 // Possibly an enum too like Connection and SubpixelOrder

XRRModeFlags :: bit_set[XRRModeBits;u64]

@(private)
XRRModeBits :: enum u8 {
    RR_HSyncPositive  = 0,
    RR_HSyncNegative  = 1,
    RR_VSyncPositive  = 2,
    RR_VSyncNegative  = 3,
    RR_Interlace      = 4,
    RR_DoubleScan     = 5,
    RR_CSync          = 6,
    RR_CSyncPositive  = 7,
    RR_CSyncNegative  = 8,
    RR_HSkewPresent   = 9,
    RR_BCast          = 10,
    RR_PixelMultiplex = 11,
    RR_DoubleClock    = 12,
    RR_ClockDivideBy2 = 13,
}

Connection :: enum u16 {
    RR_Connected         = 0,
    RR_Disconnected      = 1,
    RR_UnknownConnection = 2,
}

SubpixelOrder :: enum u16 {
    Unknown = 0,
    HorizontalRGB = 1,
    HorizontalBGR = 2,
    VerticalRGB = 3,
    VerticalBGR = 4,
    None = 5,
}

#assert(size_of(XRRModeInfo) == 80)
XRRModeInfo :: struct {
    id:         RRMode,
    width:      u32,
    height:     u32,
    dotClock:   u64,
    hSyncStart: u32,
    hSyncEnd:   u32,
    hTotal:     u32,
    hSkew:      u32,
    vSyncStart: u32,
    vSyncEnd:   u32,
    vTotal:     u32,
    name:       cstring,
    nameLength: u32,
    modeFlags:  XRRModeFlags,
}

#assert(size_of(XRRScreenSize) == 16)
XRRScreenSize :: struct {
    width, height:   i32,
    mwidth, mheight: i32,
}

#assert(size_of(XRRScreenResources) == 64)
XRRScreenResources :: struct {
    timestamp:       x11.Time,
    configTimestamp: x11.Time,
    ncrtc:           i32,
    crtcs:           [^]RRCrtc,
    noutput:         i32,
    outputs:         [^]RROutput,
    nmode:           i32,
    modes:           [^]XRRModeInfo,
}

#assert(size_of(XRROutputInfo) == 96)
XRROutputInfo :: struct {
    timestamp:      x11.Time,
    crtc:           RRCrtc,
    name:           cstring,
    nameLen:        i32,
    mm_width:       u64,
    mm_height:      u64,
    connection:     Connection,
    subpixel_order: SubpixelOrder,
    ncrtc:          i32,
    crtcs:          [^]RRCrtc,
    nclone:         i32,
    clones:         [^]RROutput,
    nmode:          i32,
    npreferred:     i32,
    modes:          [^]RRMode,
}

XRRCrtcInfo :: struct {
    timestamp:     x11.Time,
    x, y:          i32,
    width, height: u32,
    mode:          RRMode,
    rotation:      Rotation,
    noutput:       i32,
    outputs:       [^]RROutput,
    rotations:     Rotation,
    npossible:     i32,
    possible:      [^]RROutput,
}
