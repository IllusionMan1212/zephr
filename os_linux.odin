// +build linux
// +private
package zephr

import "core:log"

import x11 "vendor:x11/xlib"
import gl "vendor:OpenGL"
import "vendor:stb/image"

import "3rdparty/glx"
import "3rdparty/xcursor"

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

backend_get_screen_size :: proc() -> Vec2 {
  screen := x11.XDefaultScreenOfDisplay(x11_display)

  return Vec2{cast(f32)screen.width, cast(f32)screen.height}
}

@(private="file")
x11_resize_window :: proc() {
  win_attrs : x11.XWindowAttributes
  x11.XGetWindowAttributes(x11_display, x11_window, &win_attrs)
  gl.Viewport(0, 0, win_attrs.width, win_attrs.height)
}

@(private="file")
x11_create_window :: proc(window_title: cstring, window_size: Vec2, icon_path: cstring, window_non_resizable: bool) {
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
  gl.Enable(gl.MULTISAMPLE)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
  x11_resize_window()

  x11.XFree(fbc)
}

backend_init :: proc(window_title: cstring, window_size: Vec2, icon_path: cstring, window_non_resizable: bool) {
  x11_create_window(window_title, window_size, icon_path, window_non_resizable)
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
        zephr_ctx.window.size = Vec2{cast(f32)xce.width, cast(f32)xce.height}
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
      e_out.mouse.pos = Vec2{cast(f32)xev.xbutton.x, cast(f32)xev.xbutton.y}
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
      e_out.mouse.pos = Vec2{cast(f32)xev.xbutton.x, cast(f32)xev.xbutton.y}
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
      e_out.type = .MOUSE_MOVED
      e_out.mouse.pos = Vec2{cast(f32)xev.xmotion.x, cast(f32)xev.xmotion.y}
      zephr_ctx.mouse.pos = e_out.mouse.pos

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
