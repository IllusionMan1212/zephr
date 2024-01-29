// +build linux
// +private
package zephr

import "core:log"
import m "core:math/linalg/glsl"

import x11 "vendor:x11/xlib"
import gl "vendor:OpenGL"
import "vendor:stb/image"

import "3rdparty/glx"
import "3rdparty/xcursor"
import "3rdparty/xfixes"
import "3rdparty/xinput2"

// TODO: In the future, I should either push events to the event queue here or
//       make the queue a windows-only global.
OsEvent :: x11.XEvent
OsCursor :: x11.Cursor

@(private="file")
PropModeReplace :: 0
@(private="file")
XA_ATOM         :: x11.Atom(4)
@(private="file")
XA_STRING       :: x11.Atom(31)
@(private="file")
XA_CARDINAL     :: x11.Atom(6)

@(private="file")
x11_display  : ^x11.Display
@(private="file")
x11_window   : x11.Window
@(private="file")
x11_colormap : x11.Colormap
@(private="file")
glx_context  : glx.Context
@(private="file")
window_delete_atom : x11.Atom
@(private="file")
xinput_opcode : i32

@(private="file")
evdev_scancode_to_zephr_scancode_map := []Scancode {
  0 = .NULL,
  1 = .ESCAPE,
  2 = .KEY_1,
  3 = .KEY_2,
  4 = .KEY_3,
  5 = .KEY_4,
  6 = .KEY_5,
  7 = .KEY_6,
  8 = .KEY_7,
  9 = .KEY_8,
  10 = .KEY_9,
  11 = .KEY_0,
  12 = .MINUS,
  13 = .EQUALS,
  14 = .BACKSPACE,
  15 = .TAB,
  16 = .Q,
  17 = .W,
  18 = .E,
  19 = .R,
  20 = .T,
  21 = .Y,
  22 = .U,
  23 = .I,
  24 = .O,
  25 = .P,
  26 = .LEFT_BRACKET,
  27 = .RIGHT_BRACKET,
  28 = .ENTER,
  29 = .LEFT_CTRL,
  30 = .A,
  31 = .S,
  32 = .D,
  33 = .F,
  34 = .G,
  35 = .H,
  36 = .J,
  37 = .K,
  38 = .L,
  39 = .SEMICOLON,
  40 = .APOSTROPHE,
  41 = .GRAVE,
  42 = .LEFT_SHIFT,
  43 = .BACKSLASH,
  44 = .Z,
  45 = .X,
  46 = .C,
  47 = .V,
  48 = .B,
  49 = .N,
  50 = .M,
  51 = .COMMA,
  52 = .PERIOD,
  53 = .SLASH,
  54 = .RIGHT_SHIFT,
  55 = .KP_MULTIPLY,
  56 = .LEFT_ALT,
  57 = .SPACE,
  58 = .CAPS_LOCK,
  59 = .F1,
  60 = .F2,
  61 = .F3,
  62 = .F4,
  63 = .F5,
  64 = .F6,
  65 = .F7,
  66 = .F8,
  67 = .F9,
  68 = .F10,
  69 = .NUM_LOCK_OR_CLEAR,
  70 = .SCROLL_LOCK,
  71 = .KP_7,
  72 = .KP_8,
  73 = .KP_9,
  74 = .KP_MINUS,
  75 = .KP_4,
  76 = .KP_5,
  77 = .KP_6,
  78 = .KP_PLUS,
  79 = .KP_1,
  80 = .KP_2,
  81 = .KP_3,
  82 = .KP_0,
  83 = .KP_PERIOD,
  // 84
  85 = .LANG5, // KEY_ZENKAKUHANKAKU
  86 = .NON_US_BACKSLASH, // KEY_102ND
  87 = .F11,
  88 = .F12,
  89 = .INTERNATIONAL1, // KEY_RO,
  90 = .LANG3, // KEY_KATAKANA
  91 = .LANG4, // KEY_HIRAGANA
  92 = .INTERNATIONAL4, // KEY_HENKAN
  93 = .INTERNATIONAL2, // KEY_KATAKANAHIRAGANA
  94 = .INTERNATIONAL5, // KEY_MUHENKAN
  95 = .INTERNATIONAL5, // KEY_KPJOCOMMA
  96 = .KP_ENTER,
  97 = .RIGHT_CTRL,
  98 = .KP_DIVIDE,
  99 = .SYSREQ,
  100 = .RIGHT_ALT,
  101 = .NULL, // KEY_LINEFEED
  102 = .HOME,
  103 = .UP,
  104 = .PAGE_UP,
  105 = .LEFT,
  106 = .RIGHT,
  107 = .END,
  108 = .DOWN,
  109 = .PAGE_DOWN,
  110 = .INSERT,
  111 = .DELETE,
  112 = .NULL, // KEY_MACRO
  113 = .MUTE,
  114 = .VOLUME_DOWN,
  115 = .VOLUME_UP,
  116 = .POWER,
  117 = .KP_EQUALS,
  118 = .KP_PLUS_MINUS,
  119 = .PAUSE,
  // 120
  121 = .KP_COMMA,
  122 = .LANG1, // KEY_HANGUEL
  123 = .LANG2, // KEY_HANJA
  124 = .INTERNATIONAL3, // KEY_YEN
  125 = .LEFT_META,
  126 = .RIGHT_META,
  127 = .APPLICATION, // KEY_COMPOSE
  128 = .STOP,
  129 = .AGAIN,
  130 = .NULL, // KEY_PROPS
  131 = .UNDO,
  132 = .NULL, // KEY_FRONT
  133 = .COPY,
  134 = .NULL, // KEY_OPEN
  135 = .PASTE,
  136 = .FIND,
  137 = .CUT,
  138 = .HELP,
  139 = .MENU,
  140 = .NULL, // CALCULATOR
  141 = .NULL, // KEY_SETUP
  142 = .NULL, // SLEEP
  143 = .NULL, // KEY_WAKEUP
  144 = .NULL, // KEY_FILE
  145 = .NULL, // KEY_SENDFILE
  146 = .NULL, // KEY_DELETEFILE
  147 = .NULL, // KEY_XFER
  148 = .NULL, // KEY_PROG1
  149 = .NULL, // KEY_PROG2
  150 = .NULL, // WWW
  151 = .NULL, // KEY_MSDOS
  152 = .NULL, // KEY_COFFEE
  153 = .NULL, // KEY_DIRECTION
  154 = .NULL, // KEY_CYCLEWINDOWS
  155 = .NULL, // MAIL
  156 = .NULL, // AC_BOOKMARKS
  157 = .NULL, // COMPUTER
  158 = .NULL, // AC_BACK
  159 = .NULL, // AC_FORWARD
  160 = .NULL, // KEY_CLOSECD
  161 = .NULL, // EJECT
  162 = .NULL, // KEY_EJECTCLOSECD
  163 = .NULL, // AUDIO_NEXT
  164 = .NULL, // AUDIO_PLAY
  165 = .NULL, // AUDIO_PREV
  166 = .NULL, // AUDIO_STOP
  167 = .NULL, // KEY_RECORD
  168 = .NULL, // AUDIO_REWIND
  169 = .NULL, // KEY_PHONE
  170 = .NULL, // KEY_ISO
  171 = .NULL, // KEY_CONFIG
  172 = .NULL, // AC_HOME
  173 = .NULL, // AC_REFRESH
  174 = .NULL, // KEY_EXIT
  175 = .NULL, // KEY_MOVE
  176 = .NULL, // KEY_EDIT
  177 = .NULL, // KEY_SCROLLUP
  178 = .NULL, // KEY_SCROLLDOWN
  179 = .KP_LEFT_PAREN,
  180 = .KP_RIGHT_PAREN,
  181 = .NULL, // KEY_NEW
  182 = .NULL, // KEY_REDO
  183 = .F13,
  184 = .F14,
  185 = .F15,
  186 = .F16,
  187 = .F17,
  188 = .F18,
  189 = .F19,
  190 = .F20,
  191 = .F21,
  192 = .F22,
  193 = .F23,
  194 = .F24,
  // 195-199
  200 = .NULL, // KEY_PLAYCD
  201 = .NULL, // KEY_PAUSECD
  202 = .NULL, // KEY_PROG3
  203 = .NULL, // KEY_PROG4
  // 204
  205 = .NULL, // KEY_SUSPEND
  206 = .NULL, // KEY_CLOSE
  207 = .NULL, // KEY_PLAY
  208 = .NULL, // AUDIO_FASTFORWARD
  209 = .NULL, // KEY_BASSBOOST
  210 = .NULL, // KEY_PRINT
  211 = .NULL, // KEY_HP
  212 = .NULL, // KEY_CAMERA
  213 = .NULL, // KEY_SOUND
  214 = .NULL, // KEY_QUESTION
  215 = .NULL, // KEY_EMAIL
  216 = .NULL, // KEY_CHAT
  217 = .NULL, // AC_SEARCH
  218 = .NULL, // KEY_CONNECT
  219 = .NULL, // KEY_FINANCE
  220 = .NULL, // KEY_SPORT
  221 = .NULL, // KEY_SHOP
  222 = .ALT_ERASE,
  223 = .CANCEL,
  224 = .NULL, // BRIGHTNESS_DOWN
  225 = .NULL, // BRIGHNESS_UP
  226 = .NULL, // KEY_MEDIA
  227 = .NULL, // DISPLAY_SWITCH
  228 = .NULL, // KBD_ILLUM_TOGGLE
  229 = .NULL, // KBD_ILLUM_DOWN
  230 = .NULL, // KBD_ILLUM_UP
  231 = .NULL, // KEY_SEND
  232 = .NULL, // KEY_REPLY
  233 = .NULL, // KEY_FORWARDEMAIL
  234 = .NULL, // KEY_SAVE
  235 = .NULL, // KEY_DOCUMENTS
  236 = .NULL, // KEY_BATTERY
}

@(private="file")
x11_go_fullscreen :: proc() {
  // remove the resizing constraint before going fullscreen so WMs such as gnome
  // can add the _NET_WM_ACTION_FULLSCREEN action to the _NET_WM_ALLOWED_ACTIONS atom
  // and properly fullscreen the window
  size_hints := x11.XAllocSizeHints()

  zephr_ctx.window.pre_fullscreen_size = zephr_ctx.window.size
  if (size_hints != nil) {
    size_hints.flags = {.PPosition, .PSize}
    size_hints.width = cast(i32)zephr_ctx.window.size.x
    size_hints.height = cast(i32)zephr_ctx.window.size.y
    x11.XSetWMNormalHints(x11_display, x11_window, size_hints)
    x11.XFree(size_hints)
  }

  xev: x11.XEvent
  wm_state := x11.XInternAtom(x11_display, "_NET_WM_STATE", false)
  fullscreen := x11.XInternAtom(x11_display, "_NET_WM_STATE_FULLSCREEN", false)
  xev.type = .ClientMessage
  xev.xclient.window = x11_window
  xev.xclient.message_type = wm_state
  xev.xclient.format = 32
  xev.xclient.data.l[0] = 1 // _NET_WM_STATE_ADD
  xev.xclient.data.l[1] = cast(int)fullscreen
  xev.xclient.data.l[2] = 0
  x11.XSendEvent(x11_display, x11.XDefaultRootWindow(x11_display), false,
  {.SubstructureNotify, .SubstructureRedirect}, &xev)
}

@(private="file")
x11_return_fullscreen :: proc() {
  xev: x11.XEvent
  wm_state := x11.XInternAtom(x11_display, "_NET_WM_STATE", false)
  fullscreen := x11.XInternAtom(x11_display, "_NET_WM_STATE_FULLSCREEN", false)
  xev.type = .ClientMessage
  xev.xclient.window = x11_window
  xev.xclient.message_type = wm_state
  xev.xclient.format = 32
  xev.xclient.data.l[0] = 0 // _NET_WM_STATE_REMOVE
  xev.xclient.data.l[1] = cast(int)fullscreen
  xev.xclient.data.l[2] = 0
  x11.XSendEvent(x11_display, x11.XDefaultRootWindow(x11_display), false,
  {.SubstructureNotify, .SubstructureRedirect}, &xev)

  // restore the resizing constraint as well as the pre-fullscreen window size
  // when returning from fullscreen
  size_hints := x11.XAllocSizeHints()

  if (size_hints != nil) {
    size_hints.flags = {.PPosition, .PSize}
    size_hints.width = cast(i32)zephr_ctx.window.pre_fullscreen_size.x
    size_hints.height = cast(i32)zephr_ctx.window.pre_fullscreen_size.y
    if (zephr_ctx.window.non_resizable) {
      size_hints.flags |= {.PMinSize, .PMaxSize}
      size_hints.min_width = cast(i32)zephr_ctx.window.pre_fullscreen_size.x
      size_hints.min_height = cast(i32)zephr_ctx.window.pre_fullscreen_size.y
      size_hints.max_width = cast(i32)zephr_ctx.window.pre_fullscreen_size.x
      size_hints.max_height = cast(i32)zephr_ctx.window.pre_fullscreen_size.y
    }
    x11.XSetWMNormalHints(x11_display, x11_window, size_hints)
    x11.XFree(size_hints)
  }
}

backend_toggle_fullscreen :: proc(fullscreen: bool) {
  if fullscreen {
    x11_return_fullscreen()
  } else {
    x11_go_fullscreen()
  }
}

@(private="file")
x11_assign_window_icon :: proc(icon_path: cstring, window_title: cstring) {
  icon_width, icon_height: i32
  icon_data := image.load(icon_path, &icon_width, &icon_height, nil, 4)
  defer image.image_free(icon_data)
  assert(icon_data != nil, "Failed to load icon image")

  target_size := 2 + icon_width * icon_height

  data := make([]u64, target_size)
  defer delete(data)

  // first two elements are width and height
  data[0] = cast(u64)icon_width
  data[1] = cast(u64)icon_height

  for i in 0..<(icon_width * icon_height) {
    data[i + 2] = (cast(u64)icon_data[i * 4] << 16) | (cast(u64)icon_data[i * 4 + 1] << 8) | (cast(u64)icon_data[i * 4 + 2] << 0) | (cast(u64)icon_data[i * 4 + 3] << 24)
  }

  net_wm_icon := x11.XInternAtom(x11_display, "_NET_WM_ICON", false)
  x11.XChangeProperty(x11_display, x11_window, net_wm_icon, XA_CARDINAL, 32, PropModeReplace, raw_data(data), target_size)
}

backend_get_screen_size :: proc() -> m.vec2 {
  screen := x11.XDefaultScreenOfDisplay(x11_display)

  return m.vec2{cast(f32)screen.width, cast(f32)screen.height}
}

@(private="file")
x11_resize_window :: proc() {
  win_attrs : x11.XWindowAttributes
  x11.XGetWindowAttributes(x11_display, x11_window, &win_attrs)
  gl.Viewport(0, 0, win_attrs.width, win_attrs.height)
}

@(private="file")
x11_create_window :: proc(window_title: cstring, window_size: m.vec2, icon_path: cstring, window_non_resizable: bool) {
  context.logger = logger
  x11_display = x11.XOpenDisplay(nil)

  if x11_display == nil {
    log.error("Failed to open X11 display")
    return
  }

  screen_num := x11.XDefaultScreen(x11_display)
  root := x11.XRootWindow(x11_display, screen_num)
  visual := x11.XDefaultVisual(x11_display, screen_num)

  x11_colormap = x11.XCreateColormap(x11_display, root, visual, x11.ColormapAlloc.AllocNone)

  attributes: x11.XSetWindowAttributes
  attributes.event_mask = {.Exposure, .KeyPress, .KeyRelease,
  .StructureNotify, .ButtonPress, .ButtonRelease, .PointerMotion}
  attributes.colormap = x11_colormap

  screen := x11.XDefaultScreenOfDisplay(x11_display)

  window_start_x := screen.width / 2 - cast(i32)window_size.x / 2
  window_start_y := screen.height / 2 - cast(i32)window_size.y / 2

  x11_window = x11.XCreateWindow(x11_display, root, window_start_x, window_start_y, cast(u32)window_size.x, cast(u32)window_size.y, 0,
    x11.XDefaultDepth(x11_display), .InputOutput, visual,
    {.CWColormap, .CWEventMask}, &attributes)

  if (icon_path != "") {
    x11_assign_window_icon(icon_path, window_title)
  }

  // Hints to the WM that the window is a normal window
  // Of course this is only a hint and the WM can ignore it
  net_wm_window_type := x11.XInternAtom(x11_display, "_NET_WM_WINDOW_TYPE", false)
  net_wm_window_type_normal := x11.XInternAtom(x11_display, "_NET_WM_WINDOW_TYPE_NORMAL", false)
  x11.XChangeProperty(x11_display, x11_window, net_wm_window_type, XA_ATOM, 32, PropModeReplace, &net_wm_window_type_normal, 1)

  wm_delete_window := x11.XInternAtom(x11_display, "WM_DELETE_WINDOW", false)
  x11.XSetWMProtocols(x11_display, x11_window, &wm_delete_window, 1)
  window_delete_atom = wm_delete_window

  // set window name
  {
    UTF8_STRING := x11.XInternAtom(x11_display, "UTF8_STRING", false)
    x11.XStoreName(x11_display, x11_window, window_title)
    text_property: x11.XTextProperty
    text_property.value = raw_data(string(window_title))
    text_property.format = 8
    text_property.encoding = UTF8_STRING
    text_property.nitems = len(window_title)
    x11.XSetWMName(x11_display, x11_window, &text_property)
    net_wm_name := x11.XInternAtom(x11_display, "_NET_WM_NAME", false)
    wm_class := x11.XInternAtom(x11_display, "WM_CLASS", false)
    x11.XChangeProperty(x11_display, x11_window, net_wm_name, UTF8_STRING, 8, PropModeReplace, raw_data(string(window_title)), cast(i32)len(window_title))
    x11.XChangeProperty(x11_display, x11_window, wm_class, XA_STRING, 8, PropModeReplace, raw_data(string(window_title)), cast(i32)len(window_title))

    // name to be displayed when the window is reduced to an icon
    net_wm_icon_name := x11.XInternAtom(x11_display, "_NET_WM_ICON_NAME", false)
    x11.XChangeProperty(x11_display, x11_window, net_wm_icon_name, UTF8_STRING, 8, PropModeReplace, raw_data(string(window_title)), cast(i32)len(window_title))

    text_property.encoding = XA_STRING
    x11.XSetWMIconName(x11_display, x11_window, &text_property)

    class_hint := x11.XAllocClassHint()

    if (class_hint != nil) {
      class_hint.res_name = window_title
      class_hint.res_class = window_title
      x11.XSetClassHint(x11_display, x11_window, class_hint)
      x11.XFree(class_hint)
    }
  }

  size_hints := x11.XAllocSizeHints()

  if (size_hints != nil) {
    size_hints.flags = {.PPosition, .PSize}
    /* size_hints->win_gravity = StaticGravity; */
    size_hints.x = window_start_x
    size_hints.y = window_start_y
    size_hints.width = cast(i32)window_size.x
    size_hints.height = cast(i32)window_size.y
    if (window_non_resizable) {
      size_hints.flags |= {.PMinSize, .PMaxSize}
      size_hints.min_width = cast(i32)window_size.x
      size_hints.min_height = cast(i32)window_size.y
      size_hints.max_width = cast(i32)window_size.x
      size_hints.max_height = cast(i32)window_size.y
    }
    x11.XSetWMNormalHints(x11_display, x11_window, size_hints)
    x11.XFree(size_hints)
  }

  x11.XMapWindow(x11_display, x11_window)

  gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) { (cast(^rawptr)p)^ = glx.GetProcAddressARB(raw_data(string(name))) })

  glx_major : i32
  glx_minor : i32
  glx.QueryVersion(x11_display, &glx_major, &glx_minor)

  log.infof("Loaded GLX: %d.%d", glx_major, glx_minor)

  visual_attributes := []i32 {
    glx.RENDER_TYPE, glx.RGBA_BIT,
    glx.RED_SIZE, 8,
    glx.GREEN_SIZE, 8,
    glx.BLUE_SIZE, 8,
    glx.ALPHA_SIZE, 8,
    glx.DEPTH_SIZE, 24,
    glx.DOUBLEBUFFER, 1,
    glx.SAMPLES, 4, // MSAA
    x11.None,
  }

  num_fbc: i32
  fbc := glx.ChooseFBConfig(x11_display, screen_num, raw_data(visual_attributes), &num_fbc)

  context_attributes := []i32 {
    glx.CONTEXT_MAJOR_VERSION_ARB, 3,
    glx.CONTEXT_MINOR_VERSION_ARB, 3,
    glx.CONTEXT_PROFILE_MASK_ARB, glx.CONTEXT_CORE_PROFILE_BIT_ARB,
    x11.None,
  }

  glx_context = glx.CreateContextAttribsARB(x11_display, fbc[0], nil, true, raw_data(context_attributes))

  if glx_context == nil {
    log.error("Failed to create GLX context")
    return
  }

  glx.MakeCurrent(x11_display, x11_window, glx_context)

  gl_version := gl.GetString(gl.VERSION)

  log.infof("GL Version: %s", gl_version)

  glx.SwapIntervalEXT(x11_display, x11_window, 1)
  // we enable blending for text
  gl.Enable(gl.BLEND)
  gl.Enable(gl.DEPTH_TEST)
  gl.Enable(gl.MULTISAMPLE)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
  x11_resize_window()

  x11.XFree(fbc)
}

backend_init :: proc(window_title: cstring, window_size: m.vec2, icon_path: cstring, window_non_resizable: bool) {
  x11_create_window(window_title, window_size, icon_path, window_non_resizable)

  // TODO: lots more keyboard stuff to be done
  // this will remove KeyRelease events for held keys.
  repeat: b32
  x11.XkbSetDetectableAutoRepeat(x11_display, true, &repeat)
}

backend_shutdown :: proc() {
  glx.MakeCurrent(x11_display, 0, nil)
  glx.DestroyContext(x11_display, glx_context)

  x11.XDestroyWindow(x11_display, x11_window)
  x11.XFreeColormap(x11_display, x11_colormap)
  x11.XCloseDisplay(x11_display)
}

backend_swapbuffers :: proc() {
  glx.SwapBuffers(x11_display, x11_window)
}

// TODO: should we push the events to the event queue here as well??
// I'm thinking yes just to keep it consistent with Windows but idk
backend_get_os_events :: proc(e_out: ^Event) -> bool {
  context.logger = logger
  xev: x11.XEvent

  for (cast(bool)x11.XPending(x11_display)) {
    x11.XNextEvent(x11_display, &xev)

    if xev.type == .ConfigureNotify {
      xce := xev.xconfigure

      if (xce.width != cast(i32)zephr_ctx.window.size.x || xce.height != cast(i32)zephr_ctx.window.size.y) {
        zephr_ctx.window.size = m.vec2{cast(f32)xce.width, cast(f32)xce.height}
        zephr_ctx.projection = orthographic_projection_2d(0, zephr_ctx.window.size.x, zephr_ctx.window.size.y, 0)
        x11_resize_window()

        e_out.type = .WINDOW_RESIZED
        e_out.window.width = cast(u32)xce.width
        e_out.window.height = cast(u32)xce.height

        return true
      }
    } else if xev.type == .DestroyNotify {
      // window destroy event
      e_out.type = .WINDOW_CLOSED

      return true
    } else if xev.type == .ClientMessage {
      // window close event
      if (cast(x11.Atom)xev.xclient.data.l[0] == window_delete_atom) {
        e_out.type = .WINDOW_CLOSED

        return true
      }
    } else if xev.type == .KeyPress {
      xke := xev.xkey

      evdev_keycode := xke.keycode - 8
      scancode := evdev_scancode_to_zephr_scancode_map[evdev_keycode]

      e_out.type = .KEY_PRESSED
      e_out.key.scancode = scancode
      //e_out.key.code = keycode;
      e_out.key.mods = set_zephr_mods(scancode, true)

      return true
    } else if xev.type == .KeyRelease {
      xke := xev.xkey

      evdev_keycode := xke.keycode - 8
      scancode := evdev_scancode_to_zephr_scancode_map[evdev_keycode]

      e_out.type = .KEY_RELEASED
      e_out.key.scancode = scancode
      //e_out.key.code = keycode;
      e_out.key.mods = set_zephr_mods(scancode, false)

      return true
    } else if xev.type == .ButtonPress {
      e_out.type = .MOUSE_BUTTON_PRESSED
      e_out.mouse.pos = m.vec2{cast(f32)xev.xbutton.x, cast(f32)xev.xbutton.y}
      zephr_ctx.mouse.pressed = true

      switch (xev.xbutton.button) {
        case .Button1:
        e_out.mouse.button = .BUTTON_LEFT
        zephr_ctx.mouse.button = .BUTTON_LEFT
        case .Button2:
        e_out.mouse.button = .BUTTON_MIDDLE
        zephr_ctx.mouse.button = .BUTTON_MIDDLE
        case .Button3:
        e_out.mouse.button = .BUTTON_RIGHT
        zephr_ctx.mouse.button = .BUTTON_RIGHT
        case .Button4:
        e_out.type = .MOUSE_SCROLL
        e_out.mouse.scroll_direction = .UP
        case .Button5:
        e_out.type = .MOUSE_SCROLL
        e_out.mouse.scroll_direction = .DOWN
        case cast(x11.MouseButton)8: // Back
        e_out.mouse.button = .BUTTON_BACK
        zephr_ctx.mouse.button = .BUTTON_BACK
        case cast(x11.MouseButton)9: // Forward
        e_out.mouse.button = .BUTTON_FORWARD
        zephr_ctx.mouse.button = .BUTTON_FORWARD
        case:
        log.warnf("Unknown mouse button pressed: %d", xev.xbutton.button)
      }

      return true
    } else if xev.type == .ButtonRelease {
      e_out.type = .MOUSE_BUTTON_RELEASED
      e_out.mouse.pos = m.vec2{cast(f32)xev.xbutton.x, cast(f32)xev.xbutton.y}
      zephr_ctx.mouse.released = true
      zephr_ctx.mouse.pressed = false

      switch (xev.xbutton.button) {
        case .Button1:
        e_out.mouse.button = .BUTTON_LEFT
        case .Button2:
        e_out.mouse.button = .BUTTON_MIDDLE
        case .Button3:
        e_out.mouse.button = .BUTTON_RIGHT
        case .Button4:
        e_out.type = .MOUSE_SCROLL
        e_out.mouse.scroll_direction = .UP
        case .Button5:
        e_out.type = .MOUSE_SCROLL
        e_out.mouse.scroll_direction = .DOWN
        case cast(x11.MouseButton)8: // Back
        e_out.mouse.button = .BUTTON_BACK
        // TODO: should we be setting these in zephr ??
        // if yes then also set them for the other buttons
        zephr_ctx.mouse.button = .BUTTON_BACK
        case cast(x11.MouseButton)9: // Forward
        e_out.mouse.button = .BUTTON_FORWARD
        zephr_ctx.mouse.button = .BUTTON_FORWARD
      }

      return true
    } else if xev.type == .MappingNotify {
      // input device mapping changed
      if (xev.xmapping.request != .MappingKeyboard) {
        break
      }
      x11.XRefreshKeyboardMapping(&xev.xmapping)
      /* x11_keyboard_map_update(); */
      break
    } else if xev.type == .MotionNotify {
      if zephr_ctx.mouse.captured {
        return true
      }

      x := xev.xmotion.x
      y := xev.xmotion.y

      e_out.type = .MOUSE_MOVED
      e_out.mouse.pos = m.vec2{cast(f32)x, cast(f32)y}
      zephr_ctx.mouse.pos = e_out.mouse.pos

      return true
    } else if xev.type == .GenericEvent {
      if zephr_ctx.mouse.captured &&
      xev.xcookie.extension == xinput_opcode &&
      x11.XGetEventData(x11_display, &xev.xcookie) &&
      xev.xcookie.evtype == cast(i32)xinput2.EventType.RawMotion {
        re := cast(^xinput2.RawEvent)xev.xcookie.data
        if re.valuators.mask_len > 0 {
          values := re.raw_values
          if xinput2.MaskIsSet(re.valuators.mask, 0) {
            zephr_ctx.mouse.virtual_pos.x += cast(f32)values[0]
          }

          if xinput2.MaskIsSet(re.valuators.mask, 1) {
            zephr_ctx.mouse.virtual_pos.y += cast(f32)values[1]
          }

          e_out.type = .MOUSE_MOVED
          e_out.mouse.pos = zephr_ctx.mouse.virtual_pos
          zephr_ctx.mouse.pos = e_out.mouse.pos
        }

        x11.XFreeEventData(x11_display, &xev.xcookie)
      }

      return true
    }
  }

  return false
}

backend_set_cursor :: proc() {
  x11.XDefineCursor(x11_display, x11_window, zephr_ctx.cursors[zephr_ctx.cursor])
}

backend_init_cursors :: proc() {
  zephr_ctx.cursors[.ARROW] = x11.XCreateFontCursor(x11_display, .XC_left_ptr)
  zephr_ctx.cursors[.IBEAM] = x11.XCreateFontCursor(x11_display, .XC_xterm)
  zephr_ctx.cursors[.CROSSHAIR] = x11.XCreateFontCursor(x11_display, .XC_crosshair)
  zephr_ctx.cursors[.HAND] = x11.XCreateFontCursor(x11_display, .XC_hand1)
  zephr_ctx.cursors[.HRESIZE] = x11.XCreateFontCursor(x11_display, .XC_sb_h_double_arrow)
  zephr_ctx.cursors[.VRESIZE] = x11.XCreateFontCursor(x11_display, .XC_sb_v_double_arrow)

  // non-standard cursors
  zephr_ctx.cursors[.DISABLED] = xcursor.LibraryLoadCursor(x11_display, "crossed_circle")
}

@(private="file")
enable_raw_mouse_input :: proc() {
  context.logger = logger

  ev, err: i32
  if !x11.XQueryExtension(x11_display, "XInputExtension", &xinput_opcode, &ev, &err) {
    log.error("XInput extension not available")
    return
  }

  major: i32 = 2
  minor: i32 = 0
  if xinput2.QueryVersion(x11_display, &major, &minor) == .BadRequest {
    log.error("XInput2 not available")
    return
  }

  mask_len :: ((cast(i32)xinput2.EventType.RawMotion >> 3) + 1)
  mask: [mask_len]u8

  em := xinput2.EventMask{
    deviceid = xinput2.AllMasterDevices,
    mask_len = mask_len,
    mask = raw_data(mask[:])
  }

  xinput2.SetMask(em.mask, .RawMotion)
  // This ONLY works with the root window
  xinput2.SelectEvents(x11_display, x11.XDefaultRootWindow(x11_display), &em, 1)
}

@(private="file")
disable_raw_mouse_input :: proc() {
  mask: [1]u8

  em := xinput2.EventMask{
    deviceid = xinput2.AllMasterDevices,
    mask_len = 1,
    mask = raw_data(mask[:])
  }

  xinput2.SelectEvents(x11_display, x11.XDefaultRootWindow(x11_display), &em, 1)
}

backend_grab_cursor :: proc() {
  enable_raw_mouse_input()
  root, child: x11.Window
  int, root_x, root_y, child_x, child_y: i32
  mask: x11.KeyMask

  x11.XQueryPointer(x11_display, x11_window, &root, &child, &root_x, &root_y, &child_x, &child_y, &mask)
  zephr_ctx.mouse.pos_before_capture = {cast(f32)child_x, cast(f32)child_y}
  zephr_ctx.mouse.virtual_pos = {cast(f32)child_x, cast(f32)child_y}
  x11.XGrabPointer(x11_display, x11_window, true, {.PointerMotion, .ButtonPress, .ButtonRelease}, .GrabModeAsync, .GrabModeAsync, x11_window, x11.None, x11.CurrentTime)
  xfixes.HideCursor(x11_display, x11_window)
}

backend_release_cursor :: proc() {
  disable_raw_mouse_input()
  x11.XWarpPointer(x11_display, x11.None, x11_window, 0, 0, 0, 0, cast(i32)zephr_ctx.mouse.pos_before_capture.x, cast(i32)zephr_ctx.mouse.pos_before_capture.y)
  x11.XUngrabPointer(x11_display, x11.CurrentTime)
  xfixes.ShowCursor(x11_display, x11_window)
}
