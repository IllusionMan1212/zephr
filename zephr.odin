package zephr

import "core:fmt"
import m "core:math/linalg/glsl"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:container/queue"

import gl "vendor:OpenGL"

Cursor :: enum {
  ARROW,
  IBEAM,
  CROSSHAIR,
  HAND,
  HRESIZE,
  VRESIZE,
  DISABLED,
}

EventType :: enum {
  UNKNOWN,
  KEY_PRESSED,
  KEY_RELEASED,
  MOUSE_BUTTON_PRESSED,
  MOUSE_BUTTON_RELEASED,
  MOUSE_SCROLL,
  MOUSE_MOVED,
  WINDOW_RESIZED,
  WINDOW_CLOSED,
}

MouseButton :: enum {
  BUTTON_LEFT,
  BUTTON_RIGHT,
  BUTTON_MIDDLE,
  BUTTON_BACK,
  BUTTON_FORWARD,
  BUTTON_3,
  BUTTON_4,
  BUTTON_5,
  BUTTON_6,
  BUTTON_7,
}

MouseScrollDirection :: enum {
  UP,
  DOWN,
}

KeyMod :: bit_set[KeyModBits; u16]
KeyModBits :: enum {
  NONE        = 0,

  LEFT_SHIFT  = 1,
  RIGHT_SHIFT = 2,
  SHIFT       = 3,

  LEFT_CTRL   = 4,
  RIGHT_CTRL  = 5,
  CTRL        = 6,

  LEFT_ALT    = 7,
  RIGHT_ALT   = 8,
  ALT         = 9,

  LEFT_META   = 10,
  RIGHT_META  = 11,
  META        = 12,

  CAPS_LOCK   = 13,
  NUM_LOCK    = 14,
}

Scancode :: enum {
  NULL = 0,

  A = 4,
  B = 5,
  C = 6,
  D = 7,
  E = 8,
  F = 9,
  G = 10,
  H = 11,
  I = 12,
  J = 13,
  K = 14,
  L = 15,
  M = 16,
  N = 17,
  O = 18,
  P = 19,
  Q = 20,
  R = 21,
  S = 22,
  T = 23,
  U = 24,
  V = 25,
  W = 26,
  X = 27,
  Y = 28,
  Z = 29,

  KEY_1 = 30,
  KEY_2 = 31,
  KEY_3 = 32,
  KEY_4 = 33,
  KEY_5 = 34,
  KEY_6 = 35,
  KEY_7 = 36,
  KEY_8 = 37,
  KEY_9 = 38,
  KEY_0 = 39,

  ENTER = 40,
  ESCAPE = 41,
  BACKSPACE = 42,
  TAB = 43,
  SPACE = 44,

  MINUS = 45,
  EQUALS = 46,
  LEFT_BRACKET = 47,
  RIGHT_BRACKET = 48,
  BACKSLASH = 49,
  NON_US_HASH = 50,
  SEMICOLON = 51,
  APOSTROPHE = 52,
  GRAVE = 53,
  COMMA = 54,
  PERIOD = 55,
  SLASH = 56,

  CAPS_LOCK = 57,

  F1 = 58,
  F2 = 59,
  F3 = 60,
  F4 = 61,
  F5 = 62,
  F6 = 63,
  F7 = 64,
  F8 = 65,
  F9 = 66,
  F10 = 67,
  F11 = 68,
  F12 = 69,

  PRINT_SCREEN = 70,
  SCROLL_LOCK = 71,
  PAUSE = 72,
  INSERT = 73,
  HOME = 74,
  PAGE_UP = 75,
  DELETE = 76,
  END = 77,
  PAGE_DOWN = 78,
  RIGHT = 79,
  LEFT = 80,
  DOWN = 81,
  UP = 82,

  NUM_LOCK_OR_CLEAR = 83,
  KP_DIVIDE = 84,
  KP_MULTIPLY = 85,
  KP_MINUS = 86,
  KP_PLUS = 87,
  KP_ENTER = 88,
  KP_1 = 89,
  KP_2 = 90,
  KP_3 = 91,
  KP_4 = 92,
  KP_5 = 93,
  KP_6 = 94,
  KP_7 = 95,
  KP_8 = 96,
  KP_9 = 97,
  KP_0 = 98,
  KP_PERIOD = 99,

  NON_US_BACKSLASH = 100,
  APPLICATION = 101,
  POWER = 102,
  KP_EQUALS = 103,
  F13 = 104,
  F14 = 105,
  F15 = 106,
  F16 = 107,
  F17 = 108,
  F18 = 109,
  F19 = 110,
  F20 = 111,
  F21 = 112,
  F22 = 113,
  F23 = 114,
  F24 = 115,
  EXECUTE = 116,
  HELP = 117,
  MENU = 118,
  SELECT = 119,
  STOP = 120,
  AGAIN = 121,
  UNDO = 122,
  CUT = 123,
  COPY = 124,
  PASTE = 125,
  FIND = 126,
  MUTE = 127,
  VOLUME_UP = 128,
  VOLUME_DOWN = 129,
  KP_COMMA = 133,
  KP_EQUALSAS400 = 134,

  INTERNATIONAL1 = 135,
  INTERNATIONAL2 = 136,
  INTERNATIONAL3 = 137,
  INTERNATIONAL4 = 138,
  INTERNATIONAL5 = 139,
  INTERNATIONAL6 = 140,
  INTERNATIONAL7 = 141,
  INTERNATIONAL8 = 142,
  INTERNATIONAL9 = 143,
  LANG1 = 144,
  LANG2 = 145,
  LANG3 = 146,
  LANG4 = 147,
  LANG5 = 148,
  LANG6 = 149,
  LANG7 = 150,
  LANG8 = 151,
  LANG9 = 152,

  ALT_ERASE = 153,
  SYSREQ = 154,
  CANCEL = 155,
  CLEAR = 156,
  PRIOR = 157,
  ENTER_2 = 158,
  SEPARATOR = 159,
  OUT = 160,
  OPER = 161,
  CLEARAGAIN = 162,
  CRSEL = 163,
  EXSEL = 164,

  KP_00 = 176,
  KP_000 = 177,
  THOUSANDSSEPARATOR = 178,
  DECIMALSEPARATOR = 179,
  CURRENCYUNIT = 180,
  CURRENCYSUBUNIT = 181,
  KP_LEFT_PAREN = 182,
  KP_RIGHT_PAREN = 183,
  KP_LEFT_BRACE = 184,
  KP_RIGHT_BRACE = 185,
  KP_TAB = 186,
  KP_BACKSPACE = 187,
  KP_A = 188,
  KP_B = 189,
  KP_C = 190,
  KP_D = 191,
  KP_E = 192,
  KP_F = 193,
  KP_XOR = 194,
  KP_POWER = 195,
  KP_PERCENT = 196,
  KP_LESS = 197,
  KP_GREATER = 198,
  KP_AMPERSAND = 199,
  KP_DBLAMPERSAND = 200,
  KP_VERTICALBAR = 201,
  KP_DBLVERTICALBAR = 202,
  KP_COLON = 203,
  KP_HASH = 204,
  KP_SPACE = 205,
  KP_AT = 206,
  KP_EXCLAM = 207,
  KP_MEMSTORE = 208,
  KP_MEMRECALL = 209,
  KP_MEMCLEAR = 210,
  KP_MEMADD = 211,
  KP_MEMSUBTRACT = 212,
  KP_MEMMULTIPLY = 213,
  KP_MEMDIVIDE = 214,
  KP_PLUS_MINUS = 215,
  KP_CLEAR = 216,
  KP_CLEARENTRY = 217,
  KP_BINARY = 218,
  KP_OCTAL = 219,
  KP_DECIMAL = 220,
  KP_HEXADECIMAL = 221,

  LEFT_CTRL = 224,
  LEFT_SHIFT = 225,
  LEFT_ALT = 226,
  LEFT_META = 227,
  RIGHT_CTRL = 228,
  RIGHT_SHIFT = 229,
  RIGHT_ALT = 230,
  RIGHT_META = 231,

  /** Not a key. Marks the number of scancodes. */
  ZEPHR_KEYCODE_COUNT = 512,
}

Event :: struct {
  type: EventType,

  using _: struct #raw_union {
    key: struct {
      is_pressed: bool,
      is_repeat: bool,
      scancode: Scancode,
      //code: Keycode,
      mods: KeyMod,
    },
    mouse: struct {
      button: MouseButton,
      using pos: m.vec2,
      scroll_direction: MouseScrollDirection,
    },
    window: struct {
      width: u32,
      height: u32,
    },
  }
}

Mouse :: struct {
  using pos: m.vec2,
  pos_before_capture: m.vec2,
  virtual_pos: m.vec2,
  pressed: bool,
  released: bool,
  button: MouseButton,
  captured: bool,
}

Window :: struct {
  size: m.vec2,
  pre_fullscreen_size: m.vec2,
  is_fullscreen: bool,
  non_resizable: bool,
}

Keyboard :: struct {
  mods: KeyMod,
}

Context :: struct {
  should_quit: bool,
  screen_size: m.vec2,
  window: Window,
  font: Font,
  mouse: Mouse,
  keyboard: Keyboard,
  cursor: Cursor,
  event_queue: queue.Queue(OsEvent),
  cursors: [Cursor]OsCursor,
  ui: Ui,

  /* ZephrKeyboard keyboard; */
  /* XkbDescPtr xkb; */
  /* XIM xim; */

  projection: m.mat4,
}

@private
FNV_HASH32_INIT :: 0x811c9dc5
@private
FNV_HASH32_PRIME :: 0x01000193
@private
INIT_UI_STACK_SIZE :: 256
@private
EVENT_QUEUE_INIT_CAP :: 128

when ODIN_DEBUG {
  @private
  TerminalLoggerOpts :: log.Default_Console_Logger_Opts
} else {
  @private
  TerminalLoggerOpts :: log.Options{
    .Level,
    .Terminal_Color,
    .Short_File_Path,
    .Line,
  }
}

COLOR_BLACK   :: Color{0, 0, 0, 255}
COLOR_WHITE   :: Color{255, 255, 255, 255}
COLOR_RED     :: Color{255, 0, 0, 255}
COLOR_GREEN   :: Color{0, 255, 0, 255}
COLOR_BLUE    :: Color{0, 0, 255, 255}
COLOR_YELLOW  :: Color{255, 255, 0, 255}
COLOR_MAGENTA :: Color{255, 0, 255, 255}
COLOR_CYAN    :: Color{0, 255, 255, 255}
COLOR_ORANGE  :: Color{255, 128, 0, 255}
COLOR_PURPLE  :: Color{128, 0, 255, 255}

@private
engine_rel_path := filepath.dir(#file)
// TODO: This font is currently used for the UI elements, but we should allow the user to specify
//       their own font for the UI elements.
//       In the future, this font should only be used for the engine's editor.
@private
engine_font_path := cstring(raw_data(relative_path("./res/fonts/Rubik/Rubik-VariableFont_wght.ttf")))

@private
zephr_ctx    : Context
@private
logger       : log.Logger


////////////////////////////
//
// Zephr
//
///////////////////////////


init :: proc(icon_path: cstring, window_title: cstring, window_size: m.vec2, window_non_resizable: bool) {
    logger_init()

    // TODO: should I initalize the audio here or let the game handle that??
    //int res = audio_init();
    //CORE_ASSERT(res == 0, "Failed to initialize audio");

    queue.init(&zephr_ctx.event_queue, EVENT_QUEUE_INIT_CAP)

    backend_init(window_title, window_size, icon_path, window_non_resizable)

    ui_init(engine_font_path)

    zephr_ctx.ui.elements = make([dynamic]UiElement, INIT_UI_STACK_SIZE)
    zephr_ctx.mouse.pos = m.vec2{-1, -1}
    zephr_ctx.window.size = window_size
    zephr_ctx.window.non_resizable = window_non_resizable
    zephr_ctx.projection = orthographic_projection_2d(0, window_size.x, window_size.y, 0)

    backend_init_cursors()

    zephr_ctx.screen_size = backend_get_screen_size()
    start_internal_timer()
}

deinit :: proc() {
  backend_shutdown()
  queue.destroy(&zephr_ctx.event_queue)
  delete(zephr_ctx.ui.elements)
  //audio_close()
}

should_quit :: proc() -> bool {
  gl.ClearColor(0, 0, 0, 1)
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

  zephr_ctx.cursor = .ARROW
  zephr_ctx.mouse.released = false
  zephr_ctx.mouse.pressed = false

  //audio_update();

  return zephr_ctx.should_quit
}

quit :: proc() {
  zephr_ctx.should_quit = true
}

@private
consume_mouse_events :: proc() -> bool {
  defer clear(&zephr_ctx.ui.elements)

  #reverse for e in zephr_ctx.ui.elements {
    if (inside_rect(e.rect, zephr_ctx.mouse.pos)) {
      zephr_ctx.ui.hovered_element = e.id
      return false
    }
  }

  return true
}

swap_buffers :: proc() {
  if (zephr_ctx.ui.popup_open) {
    draw_color_picker_popup(&zephr_ctx.ui.popup_parent_constraints)
  }
  zephr_ctx.ui.popup_open = false

  if consume_mouse_events() {
    zephr_ctx.ui.hovered_element = 0
  }

  backend_swapbuffers()
  backend_set_cursor()
}

iter_events :: proc(e_out: ^Event) -> bool {
  return backend_get_os_events(e_out)
}

get_window_size :: proc() -> m.vec2 {
  return zephr_ctx.window.size
}

toggle_fullscreen :: proc() {
  backend_toggle_fullscreen(zephr_ctx.window.is_fullscreen)

  zephr_ctx.window.is_fullscreen = !zephr_ctx.window.is_fullscreen
}

toggle_cursor_capture :: proc() {
  if zephr_ctx.mouse.captured {
    backend_release_cursor()
  } else {
    backend_grab_cursor()
  }

  zephr_ctx.mouse.captured = !zephr_ctx.mouse.captured
}

load_font :: proc(font_path: cstring) {
  // TODO: this function should be called from the game/future editor to load in new
  // fonts that will be used in the game.
  // TODO: I'm not sure how the path is supposed to be resolved since relative paths
  // are relative to the engine repo dir and not the game's repo dir.

  // Ideally we'd want to create a custom binary format for fonts when this is called that we can load in
  // and use to render text after the initial loading. This would allow the engine users
  // to select any font on their system and not have to include it in their game's repo.
  // This also allows us to add any extra data about the fonts that want, i.e SDF data, atlas texture coords, etc.

  // For now we'll just require that the ttf font file is included with the game.
}

@private
set_cursor :: proc(cursor: Cursor) {
  zephr_ctx.cursor = cursor
}


/////////////////////////////
//
//
// Utils
//
//
/////////////////////////////


@private
fnv_hash32 :: proc(data: []byte, size: u32, hash: u32) -> u32 {
  hash := hash

  for i in 0..<size {
    hash ~= cast(u32)data[i]
    hash *= FNV_HASH32_PRIME
  }

  return hash
}

@private
logger_init :: proc() {
  buf : [128]byte
  log_file_name := fmt.bprintf(buf[:], "%s.log", ODIN_BUILD_PROJECT_NAME)

  log_file, err := os.open(log_file_name, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
  if err != os.ERROR_NONE {
    fmt.eprintln("[ERROR] Failed to open log file. Logs will not be written")
    return
  }

  file_logger := log.create_file_logger(log_file)
  term_logger := log.create_console_logger(opt = TerminalLoggerOpts)

  logger = log.create_multi_logger(file_logger, term_logger)
}

@private
set_zephr_mods :: proc(scancode: Scancode, is_press: bool) -> KeyMod {
  mods := zephr_ctx.keyboard.mods

  if (is_press) {
    if (scancode == .LEFT_SHIFT) {
      mods |= {.LEFT_SHIFT, .SHIFT}
    }
    if (scancode == .RIGHT_SHIFT) {
      mods |= {.RIGHT_SHIFT, .SHIFT}
    }
    if (scancode == .LEFT_CTRL) {
      mods |= {.LEFT_CTRL, .CTRL}
    }
    if (scancode == .RIGHT_CTRL) {
      mods |= {.RIGHT_CTRL, .CTRL}
    }
    if (scancode == .LEFT_ALT) {
      mods |= {.LEFT_ALT, .ALT}
    }
    if (scancode == .RIGHT_ALT) {
      mods |= {.RIGHT_ALT, .ALT}
    }
    if (scancode == .LEFT_META) {
      mods |= {.LEFT_META, .META}
    }
    if (scancode == .RIGHT_META) {
      mods |= {.RIGHT_META, .META}
    }
    if (scancode == .CAPS_LOCK) {
      mods |= {.CAPS_LOCK}
    }
    if (scancode == .NUM_LOCK_OR_CLEAR) {
      mods |= {.NUM_LOCK}
    }
  } else {
    if (scancode == .LEFT_SHIFT) {
      mods &= ~{.LEFT_SHIFT}
    }
    if (scancode == .RIGHT_SHIFT) {
      mods &= ~{.RIGHT_SHIFT}
    }
    if (!(.RIGHT_SHIFT in mods) && !(.LEFT_SHIFT in mods)) {
      mods &= ~{.SHIFT}
    }

    if (scancode == .LEFT_CTRL) {
      mods &= ~{.LEFT_CTRL}
    }
    if (scancode == .RIGHT_CTRL) {
      mods &= ~{.RIGHT_CTRL}
    }
    if (!(.RIGHT_CTRL in mods) && !(.LEFT_CTRL in mods)) {
      mods &= ~{.CTRL}
    }

    if (scancode == .LEFT_ALT) {
      mods &= ~{.LEFT_ALT}
    }
    if (scancode == .RIGHT_ALT) {
      mods &= ~{.RIGHT_ALT}
    }
    if (!(.RIGHT_ALT in mods) && !(.LEFT_ALT in mods)) {
      mods &= ~{.ALT}
    }

    if (scancode == .LEFT_META) {
      mods &= ~{.LEFT_META}
    }
    if (scancode == .RIGHT_META) {
      mods &= ~{.RIGHT_META}
    }
    if (!(.RIGHT_META in mods) && !(.LEFT_META in mods)) {
      mods &= ~{.META}
    }

    if (scancode == .CAPS_LOCK) {
      mods &= ~{.CAPS_LOCK}
    }
    if (scancode == .NUM_LOCK_OR_CLEAR) {
      mods &= ~{.NUM_LOCK}
    }
  }

  zephr_ctx.keyboard.mods = mods

  return mods
}

@private
relative_path :: proc(path: string) -> string {
  return filepath.join([]string{engine_rel_path, path})
}
