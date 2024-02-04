package zephr

import "core:fmt"
import m "core:math/linalg/glsl"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:container/queue"
import "core:time"

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
  INPUT_DEVICE_CONNECTED,
  INPUT_DEVICE_DISCONNECTED,
  RAW_GAMEPAD_ACTION_PRESSED,
  RAW_GAMEPAD_ACTION_RELEASED,
  RAW_TOUCHPAD_ACTION_PRESSED,
  RAW_TOUCHPAD_ACTION_RELEASED,
  RAW_TOUCHPAD_MOVED,
  RAW_ACCELEROMETER_CHANGED,
  KEY_PRESSED,
  KEY_RELEASED,
  RAW_MOUSE_BUTTON_PRESSED,
  RAW_MOUSE_BUTTON_RELEASED,
  RAW_MOUSE_SCROLL,
  RAW_MOUSE_MOVED,
  VIRT_MOUSE_BUTTON_PRESSED,
  VIRT_MOUSE_BUTTON_RELEASED,
  VIRT_MOUSE_SCROLL,
  VIRT_MOUSE_MOVED,
  WINDOW_RESIZED,
  WINDOW_CLOSED,
}

MouseButton :: enum {
  BUTTON_NONE = 0x00,
  BUTTON_LEFT = 0x01,
  BUTTON_RIGHT = 0x02,
  BUTTON_MIDDLE = 0x04,
  BUTTON_BACK = 0x08,
  BUTTON_FORWARD = 0x10,
  //BUTTON_3,
  //BUTTON_4,
  //BUTTON_5,
  //BUTTON_6,
  //BUTTON_7,
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

InputDeviceFeatures :: bit_set[InputDeviceFeaturesBits]
InputDeviceFeaturesBits :: enum {
  MOUSE =         0x01,
  KEYBOARD =      0x02,
  GAMEPAD  =      0x04,
  TOUCHPAD =      0x08,
  ACCELEROMETER = 0x10,
  GYROSCOPE =     0x20,
}

GamepadAction :: enum {
  NONE,

  DPAD_LEFT,
  DPAD_DOWN,
  DPAD_RIGHT,
  DPAD_UP,

  FACE_LEFT,
  FACE_DOWN,
  FACE_RIGHT,
  FACE_UP,

  START,
  SELECT,

  STICK_LEFT,
  STICK_RIGHT,

  SHOULDER_LEFT,
  SHOULDER_RIGHT,

  STICK_LEFT_X_WEST,
  STICK_LEFT_X_EAST,
  STICK_LEFT_Y_NORTH,
  STICK_LEFT_Y_SOUTH,
  STICK_RIGHT_X_WEST,
  STICK_RIGHT_X_EAST,
  STICK_RIGHT_Y_NORTH,
  STICK_RIGHT_Y_SOUTH,
  TRIGGER_LEFT,
  TRIGGER_RIGHT,

  COUNT = TRIGGER_RIGHT,

  // TODO: I think windows stops at LEFT_X_WEST. Not sure
  BUTTON_END = STICK_LEFT_X_WEST,
}

TouchpadAction :: enum {
  NONE,
  CLICK,
  TOUCH,
}

Touchpad :: struct {
  pos: m.vec2,
	rel_pos: m.vec2,
	dims: m.vec2,
	action_is_pressed_bitset: bit_set[TouchpadAction; u8],
	action_has_been_pressed_bitset: bit_set[TouchpadAction; u8],
	action_has_been_released_bitset: bit_set[TouchpadAction; u8],
}

Gamepad :: struct {
  action_is_pressed_bitset: bit_set[GamepadAction],
	action_has_been_pressed_bitset: bit_set[GamepadAction],
	action_has_been_released_bitset: bit_set[GamepadAction],
	action_value_unorms: [GamepadAction]f32,
  supports_rumble: bool,
}

InputDevice :: struct {
  name: string,
  vendor_id: u16,
  product_id: u16,
  features: InputDeviceFeatures,
  mouse: Mouse,
  touchpad: Touchpad,
  //OsKeyboard            keyboard,
  gamepad: Gamepad,
  accelerometer: m.vec3,
  gyroscope: m.quat,

  backend_data: [OS_INPUT_DEVICE_BACKEND_SIZE]u8,
}

Event :: struct {
  type: EventType,

  using _: struct #raw_union {
    input_device: struct {
      id: u64,
      vendor_id: u16,
      product_id: u16,
      features: InputDeviceFeatures,
    },
    gamepad_action: struct {
      device_id: u64,
			action: GamepadAction,
			value_unorm: f32,
		},
    touchpad_action: struct {
      device_id: u64,
			is_pressed: bool,
			action: TouchpadAction,
			action_bitset: bit_set[TouchpadAction; u8],
    },
    touchpad_moved: struct {
      device_id: u64,
			pos: m.vec2, // touchpad space
			rel_pos: m.vec2,
    },
    accelerometer: struct {
      device_id: u64,
      accel: m.vec3,
    },
    key: struct {
      is_pressed: bool,
      is_repeat: bool,
      scancode: Scancode,
      //code: Keycode,
      mods: KeyMod,
    },
    mouse_button: struct {
      device_id: u64, // 0 for virtual mouse
      button: MouseButton,
      button_bitset: bit_set[MouseButton; u32],
      using pos: m.vec2,
    },
    mouse_moved: struct {
      device_id: u64, // 0 for virtual mouse
      using pos: m.vec2,
      rel_pos: m.vec2,
    },
    mouse_scroll: struct {
      device_id: u64, // 0 for virtual mouse
      scroll_rel: m.vec2,
    },
    window: struct {
      width: u32,
      height: u32,
    },
  }
}

Mouse :: struct {
  using pos: m.vec2,
  rel_pos: m.vec2,
  pos_before_capture: m.vec2,
  virtual_pos: m.vec2,
  button_is_pressed_bitset: bit_set[MouseButton; u32],
  button_has_been_pressed_bitset: bit_set[MouseButton; u32],
  button_has_been_released_bitset: bit_set[MouseButton; u32],
  scroll_rel: m.vec2,
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
  virt_mouse: Mouse,
  keyboard: Keyboard,
  cursor: Cursor,
  event_queue: queue.Queue(Event),
  input_devices_map: map[u64]InputDevice,
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
@private
INPUT_DEVICE_MAP_CAP :: 256
when ODIN_OS == .Linux {
  @private
  OS_INPUT_DEVICE_BACKEND_SIZE :: 504
} else when ODIN_OS == .Windows {
  // TODO:
}

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
    zephr_ctx.input_devices_map = make(map[u64]InputDevice)

    backend_init(window_title, window_size, icon_path, window_non_resizable)

    ui_init(engine_font_path)

    zephr_ctx.ui.elements = make([dynamic]UiElement, INIT_UI_STACK_SIZE)
    zephr_ctx.virt_mouse.pos = m.vec2{-1, -1}
    zephr_ctx.window.size = window_size
    zephr_ctx.window.non_resizable = window_non_resizable
    zephr_ctx.projection = orthographic_projection_2d(0, window_size.x, window_size.y, 0)

    backend_init_cursors()

    zephr_ctx.screen_size = backend_get_screen_size()
    start_internal_timer()
}

deinit :: proc() {
  backend_shutdown()
  delete(zephr_ctx.input_devices_map)
  queue.destroy(&zephr_ctx.event_queue)
  delete(zephr_ctx.ui.elements)
  //audio_close()
}

should_quit :: proc() -> bool {
  frame_init()

  gl.ClearColor(0.4, 0.4, 0.4, 1)
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

  zephr_ctx.cursor = .ARROW

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
    if (inside_rect(e.rect, zephr_ctx.virt_mouse.pos)) {
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

frame_init :: proc() {
  for id, device in &zephr_ctx.input_devices_map {
    if .MOUSE in device.features {
			device.mouse.rel_pos = m.vec2{0, 0}
			device.mouse.scroll_rel = m.vec2{0, 0}
			device.mouse.button_has_been_pressed_bitset = {.BUTTON_NONE}
			device.mouse.button_has_been_released_bitset = {.BUTTON_NONE}
    }

    if .TOUCHPAD in device.features {
			device.touchpad.rel_pos = m.vec2{0, 0}
			device.touchpad.action_has_been_pressed_bitset = {.NONE}
			device.touchpad.action_has_been_released_bitset = {.NONE}
    }

    if .KEYBOARD in device.features {
			//device.keyboard.key_mod_has_been_pressed_bitset = OS_KEY_MOD_NONE
			//device.keyboard.key_mod_has_been_released_bitset = OS_KEY_MOD_NONE
			//CORE_ZERO_ARRAY(device.keyboard.keycode_has_been_pressed_bitset)
			//CORE_ZERO_ARRAY(device.keyboard.keycode_has_been_released_bitset)
			//CORE_ZERO_ARRAY(device.keyboard.virtkeycode_has_been_pressed_bitset)
			//CORE_ZERO_ARRAY(device.keyboard.virtkeycode_has_been_released_bitset)
    }

    if .GAMEPAD in device.features {
      device.gamepad.action_has_been_pressed_bitset = {}
      device.gamepad.action_has_been_released_bitset = {}
    }
  }

	zephr_ctx.virt_mouse.rel_pos = m.vec2{}
	zephr_ctx.virt_mouse.scroll_rel = m.vec2{}
	zephr_ctx.virt_mouse.button_has_been_pressed_bitset = {.BUTTON_NONE}
	zephr_ctx.virt_mouse.button_has_been_released_bitset = {.BUTTON_NONE}

	//g_os.virt_keyboard.key_mod_has_been_pressed_bitset = OS_KEY_MOD_NONE;
	//g_os.virt_keyboard.key_mod_has_been_released_bitset = OS_KEY_MOD_NONE;
	//CORE_ZERO_ARRAY(g_os.virt_keyboard.keycode_has_been_pressed_bitset);
	//CORE_ZERO_ARRAY(g_os.virt_keyboard.keycode_has_been_released_bitset);
	//CORE_ZERO_ARRAY(g_os.virt_keyboard.virtkeycode_has_been_pressed_bitset);
	//CORE_ZERO_ARRAY(g_os.virt_keyboard.virtkeycode_has_been_released_bitset);

	//os_backend_frame_init();
}

iter_events :: proc() -> ^Event {
  context.logger = logger

  if queue.len(zephr_ctx.event_queue) < queue.cap(zephr_ctx.event_queue) {
    backend_get_os_events()

    if queue.len(zephr_ctx.event_queue) == 0 {
      return nil
    }
  }

  ev := queue.front_ptr(&zephr_ctx.event_queue)
  queue.pop_front(&zephr_ctx.event_queue)
  return ev
}

get_input_device_by_id :: proc(device_id: u64) -> ^InputDevice {
  for id, device in &zephr_ctx.input_devices_map {
    if id == device_id {
      return &device
    }
  }

  return nil
}

// TODO: remove this
get_first_device_with :: proc(features: InputDeviceFeatures) -> ^InputDevice {
  for id, device in &zephr_ctx.input_devices_map {
    if device.features & features == features {
      return &device
    }
  }

  return nil
}

get_all_input_devices :: proc() -> ^map[u64]InputDevice {
  return &zephr_ctx.input_devices_map
}

get_window_size :: proc() -> m.vec2 {
  return zephr_ctx.window.size
}

toggle_fullscreen :: proc() {
  backend_toggle_fullscreen(zephr_ctx.window.is_fullscreen)

  zephr_ctx.window.is_fullscreen = !zephr_ctx.window.is_fullscreen
}

toggle_cursor_capture :: proc() {
  if zephr_ctx.virt_mouse.captured {
    backend_release_cursor()
  } else {
    backend_grab_cursor()
  }

  zephr_ctx.virt_mouse.captured = !zephr_ctx.virt_mouse.captured
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

@private
os_event_queue_input_device_connected :: proc(key: u64, name: string, features: InputDeviceFeatures, vendor_id: u16, product_id: u16) -> ^InputDevice {
  context.logger = logger

  found_device, found := &zephr_ctx.input_devices_map[key]
  if (found) {
    if found_device.vendor_id == 0 {
      found_device.vendor_id = vendor_id
    }
    if found_device.product_id == 0 {
      found_device.product_id = product_id
    }
    if found_device.name == "" {
      found_device.name = name
    }

    return found_device
  }

  log.debugf("input device connected: name: %s, vendor_id: 0x%x, product_id: 0x%x, features: 0x%x", name, vendor_id, product_id, features)

  device := InputDevice{
    name = name,
    features = features,
    vendor_id = vendor_id,
    product_id = product_id,
  }

  zephr_ctx.input_devices_map[key] = device

  e: Event
  e.type = .INPUT_DEVICE_CONNECTED
  e.input_device.id = key
  e.input_device.features = features
  e.input_device.vendor_id = vendor_id
  e.input_device.product_id = product_id

  queue.push(&zephr_ctx.event_queue, e)

  return &zephr_ctx.input_devices_map[key]
}

@private
os_event_queue_input_device_disconnected :: proc(key: u64) {
  context.logger = logger

  device := zephr_ctx.input_devices_map[key]
  
  e: Event

  e.type = .INPUT_DEVICE_DISCONNECTED
  e.input_device.id = key
  e.input_device.features = device.features
  e.input_device.vendor_id = device.vendor_id
  e.input_device.product_id = device.product_id

  queue.push(&zephr_ctx.event_queue, e)

  log.debugf("input device disconnected: name: %s, vendor_id: 0x%x, product_id: 0x%x, features: 0x%x", device.name, device.vendor_id, device.product_id, device.features)

  delete_key(&zephr_ctx.input_devices_map, key)
}

@private
input_device_get_checked :: proc(id: u64, features: InputDeviceFeatures) -> ^InputDevice {
  device := &zephr_ctx.input_devices_map[id]
	assert(device.features & features == features, fmt.tprintf("expected features '0x%x' but got '0x%x'", features, device.features))
	return device
}

gamepad_action_is_pressed :: proc(gamepad: ^Gamepad, action: GamepadAction) -> bool {
  return action in gamepad.action_is_pressed_bitset
}

gamepad_rumble :: proc(device: ^InputDevice, weak_motor: u16, strong_motor: u16, duration: time.Duration, delay: time.Duration = 0) {
  if !device.gamepad.supports_rumble do return

  backend_gamepad_rumble(device, weak_motor, strong_motor, duration, delay)
}

@private
os_event_queue_raw_gamepad_action :: proc(key: u64, action: GamepadAction, value_unorm: f32, deadzone_unorm: f32) {
  value_unorm := value_unorm

	if (action == .NONE) {
		return
	}

  device := input_device_get_checked(key, {.GAMEPAD});
	if (value_unorm < deadzone_unorm) { // TODO user configurable deadzone, different for each stick and trigger
		value_unorm = 0
	}

	if (device.gamepad.action_value_unorms[action] == value_unorm) {
		return
	}

	if (value_unorm > 0) {
    device.gamepad.action_is_pressed_bitset |= {action}
    device.gamepad.action_has_been_pressed_bitset |= {action}
	} else {
    device.gamepad.action_is_pressed_bitset &= ~{action}
		device.gamepad.action_has_been_released_bitset |= {action}
	}

  e: Event
  e.type = value_unorm > 0 ? .RAW_GAMEPAD_ACTION_PRESSED : .RAW_GAMEPAD_ACTION_RELEASED
	e.gamepad_action.device_id = key
	e.gamepad_action.action = action
	e.gamepad_action.value_unorm = value_unorm

  queue.push(&zephr_ctx.event_queue, e)

	device.gamepad.action_value_unorms[action] = value_unorm
}

is_cursor_captured :: proc() -> bool {
  return zephr_ctx.virt_mouse.captured
}

@private
os_event_queue_raw_touchpad_action :: proc(key: u64, action: TouchpadAction, is_pressed: bool) {
  device := input_device_get_checked(key, {.TOUCHPAD})
  if (is_pressed) {
    device.touchpad.action_is_pressed_bitset |= {action}
    device.touchpad.action_has_been_pressed_bitset |= {action}
  } else {
    device.touchpad.action_is_pressed_bitset &= ~{action}
    device.touchpad.action_has_been_released_bitset |= {action}
  }

  e: Event
  e.type = is_pressed ? .RAW_TOUCHPAD_ACTION_PRESSED : .RAW_TOUCHPAD_ACTION_RELEASED
  e.touchpad_action.device_id = key
  e.touchpad_action.action = action
  e.touchpad_action.action_bitset = device.touchpad.action_is_pressed_bitset

  queue.push(&zephr_ctx.event_queue, e)
}

@private
os_event_queue_raw_touchpad_moved :: proc(key: u64, pos: m.vec2) {
  device := input_device_get_checked(key, {.TOUCHPAD});
  new_pos := m.vec2{clamp(pos.x, 0, device.touchpad.dims.x), clamp(pos.y, 0, device.touchpad.dims.y)}

  e: Event
  e.type = .RAW_TOUCHPAD_MOVED
  e.touchpad_moved.device_id = key
  e.touchpad_moved.pos = new_pos
  e.touchpad_moved.rel_pos = new_pos - device.touchpad.pos

  queue.push(&zephr_ctx.event_queue, e)

	device.touchpad.pos = new_pos
	device.touchpad.rel_pos = device.touchpad.rel_pos + e.touchpad_moved.rel_pos
}

@private
os_event_queue_raw_accelerometer_changed :: proc(key: u64, accel: m.vec3) {
  device := input_device_get_checked(key, {.ACCELEROMETER})
  device.accelerometer = accel

  e: Event
  e.type = .RAW_ACCELEROMETER_CHANGED
  e.accelerometer.device_id = key
  e.accelerometer.accel = accel

  queue.push(&zephr_ctx.event_queue, e)
}

@private
os_event_queue_raw_mouse_button :: proc(key: u64, button: MouseButton, is_pressed: bool) {
  device := input_device_get_checked(key, {.MOUSE})
  if is_pressed {
    device.mouse.button_is_pressed_bitset |= {button}
    device.mouse.button_has_been_pressed_bitset |= {button}
  } else {
    device.mouse.button_is_pressed_bitset &= ~{button}
    device.mouse.button_has_been_released_bitset |= {button}
  }

  e: Event
  e.type = is_pressed ? .RAW_MOUSE_BUTTON_PRESSED : .RAW_MOUSE_BUTTON_RELEASED
  e.mouse_button.device_id = key
  e.mouse_button.button = button
  e.mouse_button.button_bitset = device.mouse.button_is_pressed_bitset

  queue.push(&zephr_ctx.event_queue, e)
}

@private
os_event_queue_raw_mouse_moved :: proc(key: u64, rel_pos: m.vec2) {
  device := input_device_get_checked(key, {.MOUSE})

  e: Event
  e.type = .RAW_MOUSE_MOVED
	e.mouse_moved.device_id = key
	e.mouse_moved.pos = m.vec2{0, 0}
	e.mouse_moved.rel_pos = rel_pos

  queue.push(&zephr_ctx.event_queue, e)

	device.mouse.rel_pos = device.mouse.rel_pos + rel_pos
}

@private
os_event_queue_raw_mouse_scroll :: proc(key: u64, scroll_rel: m.vec2) {
  e: Event
  e.type = .RAW_MOUSE_SCROLL
	e.mouse_scroll.device_id = key
	e.mouse_scroll.scroll_rel = scroll_rel

  device := input_device_get_checked(key, {.MOUSE});
	device.mouse.scroll_rel = device.mouse.scroll_rel + scroll_rel
}

@private
os_event_queue_virt_mouse_button :: proc(button: MouseButton, is_pressed: bool) {
  e: Event
  e.type = is_pressed ? .VIRT_MOUSE_BUTTON_PRESSED : .VIRT_MOUSE_BUTTON_RELEASED
  e.mouse_button.device_id = 0
  e.mouse_button.button = button
  e.mouse_button.pos = zephr_ctx.virt_mouse.pos

	if is_pressed {
    zephr_ctx.virt_mouse.button_is_pressed_bitset |= {button}
    zephr_ctx.virt_mouse.button_has_been_pressed_bitset |= {button}
	} else {
		zephr_ctx.virt_mouse.button_is_pressed_bitset &= ~{button}
		zephr_ctx.virt_mouse.button_has_been_released_bitset |= {button}
	}

	e.mouse_button.button_bitset = zephr_ctx.virt_mouse.button_is_pressed_bitset

  queue.push(&zephr_ctx.event_queue, e)
}

@private
os_event_queue_virt_mouse_scroll :: proc(scroll_rel: m.vec2) {
	zephr_ctx.virt_mouse.scroll_rel = scroll_rel

  e: Event
  e.type = .VIRT_MOUSE_SCROLL
  e.mouse_scroll.device_id = 0
  e.mouse_scroll.scroll_rel = scroll_rel

  queue.push(&zephr_ctx.event_queue, e)
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
