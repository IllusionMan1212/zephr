#+build linux:android
#+private
package zephr

import "base:runtime"

import "core:time"
import m "core:math/linalg/glsl"
import "core:log"
import "core:container/queue"
import "core:strings"
import "core:path/filepath"
import "core:slice"

import gl "vendor:OpenGL"
import "vendor:egl"

import "shared:android"

@(private = "file")
Os :: struct {
    egl_display: egl.Display,
    egl_context: egl.Context,
    egl_surface: egl.Surface,
    app: ^android.android_app,
    window_is_ready: bool,
    active: bool,
}

OsCursor :: struct{}

@(private = "file")
a_os: Os

@(private = "file", rodata)
gamepad_btn_bindings := #partial [GamepadAction]android.Keycode {
    .DPAD_LEFT = .DPAD_LEFT,
    .DPAD_DOWN = .DPAD_DOWN,
    .DPAD_RIGHT = .DPAD_RIGHT,
    .DPAD_UP = .DPAD_UP,
    .FACE_LEFT = .BUTTON_X,
    .FACE_DOWN = .BUTTON_A,
    .FACE_RIGHT = .BUTTON_B,
    .FACE_UP = .BUTTON_Y,
    .START = .BUTTON_START,
    .SELECT = .BUTTON_SELECT,
    .STICK_LEFT = .BUTTON_THUMBL,
    .STICK_RIGHT = .BUTTON_THUMBR,
    .SHOULDER_LEFT = .BUTTON_L1,
    .SHOULDER_RIGHT = .BUTTON_R1,
    // TODO: Having this here means the axis value will always be set to 1.
    // we can comment this out but controllers with triggers that aren't axes won't work.
    // Compromise is to not have inbetween axis data even if the controller provides it.
    .TRIGGER_LEFT = .BUTTON_L2,
    .TRIGGER_RIGHT = .BUTTON_R2,
    .SYSTEM = .BUTTON_MODE,
}

@(private = "file", rodata)
gamepad_axes_bindings := #partial [GamepadAction]android.MotionEventAxis {
    .DPAD_LEFT = .HAT_X,
    .DPAD_DOWN = .HAT_Y,
    .DPAD_RIGHT = .HAT_X,
    .DPAD_UP = .HAT_Y,
    .STICK_LEFT_X_WEST = .X,
    .STICK_LEFT_X_EAST = .X,
    .STICK_LEFT_Y_NORTH = .Y,
    .STICK_LEFT_Y_SOUTH = .Y,
    .STICK_RIGHT_X_WEST = .Z,
    .STICK_RIGHT_X_EAST = .Z,
    .STICK_RIGHT_Y_NORTH = .RZ,
    .STICK_RIGHT_Y_SOUTH = .RZ,
    .TRIGGER_LEFT = .GAS,
    .TRIGGER_RIGHT = .BRAKE,
}

@(private = "file", rodata)
android_scancode_to_zephr_scancode := [?]Scancode {
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
    71 = .KP_7, // TODO: 2 events (KP_7 and HOME). BUT, only the KP_7 is sent if numlock is on.
    72 = .KP_8, // TODO: 2 events (KP_8 and UP). BUT, only the KP_8 is sent if numlock is on.
    73 = .KP_9, // TODO: 2 events (KP_9 and PAGE_UP). BUT, only the KP_9 is sent if numlock is on.
    74 = .KP_MINUS,
    75 = .KP_4, // TODO: 2 events (KP_4 and LEFT). BUT, only KP_4 is sent if numlock is on.
    76 = .KP_5, // TODO: 2 events (KP_5 and DPAD_CENTER??). BUT, only KP_5 is sent if numlock is on.
    77 = .KP_6, // TODO: 2 events (KP_6 and RIGHT). BUT, only KP_6 is sent if numlock is on.
    78 = .KP_PLUS,
    79 = .KP_1, // TODO: 2 events (KP_1 and END). BUT, only KP_1 is sent if numlock is on.
    80 = .KP_2, // TODO: 2 events (KP_2 and DOWN). BUT, only KP_2 is sent if numlock is on.
    81 = .KP_3, // TODO: 2 events (KP_3 and PG_DOWN). BUT, only KP_3 is sent if numlock is on.
    82 = .KP_0, // TODO: 2 events (KP_0 and INSERT). BUT, only KP_0 is sent if numlock is on.
    83 = .KP_PERIOD, // TODO: 2 events (KP_PERIOD and DELETE). BUT, only KP_PERIOD is sent if numlock is on.

    87 = .F11,
    88 = .F12,

    96 = .KP_ENTER, // TODO: This produces 2 down/up events, one for KP_ENTER down and one for ENTER down.
                    // Will cause double press problems so we'll have to handle that. The two events have the same scancode
                    // but a different keycode for this. This doesn't care about numlock.
    97 = .RIGHT_CTRL,
    98 = .KP_DIVIDE,

    100 = .RIGHT_ALT,

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

    113 = .MUTE,
    114 = .VOLUME_DOWN,
    115 = .VOLUME_UP,

    119 = .PAUSE,

    127 = .MENU,
}

// TODO: for DPI-aware UI rendering
query_dpi :: proc(app: ^android.android_app, env: ^android.JNIEnv) {
    log.assert(env != nil)

    activity_class := env^->FindClass("android/app/NativeActivity")
    log.assert(activity_class != nil)

    get_window_manager := env^->GetMethodID(activity_class, "getWindowManager", "()Landroid/view/WindowManager;")
    log.assert(get_window_manager != nil)

    window_manager := env^->CallObjectMethod(app.activity.clazz, get_window_manager)
    log.assert(window_manager != nil)

    window_manager_class := env^->FindClass("android/view/WindowManager")
    log.assert(window_manager_class != nil)

    get_default_display := env^->GetMethodID(window_manager_class, "getDefaultDisplay", "()Landroid/view/Display;")
    log.assert(get_default_display != nil)

    display := env^->CallObjectMethod(window_manager, get_default_display)
    log.assert(display != nil)

    display_class := env^->FindClass("android/view/Display")
    log.assert(display_class != nil)

    display_metrics_class := env^->FindClass("android/util/DisplayMetrics")
    log.assert(display_metrics_class != nil)

    display_metrics_constructor := env^->GetMethodID(display_metrics_class, "<init>", "()V")
    log.assert(display_metrics_constructor != nil)

    display_metrics := env^->NewObject(display_metrics_class, display_metrics_constructor)
    log.assert(display_metrics != nil)

    get_metrics := env^->GetMethodID(display_class, "getMetrics", "(Landroid/util/DisplayMetrics;)V")
    log.assert(get_metrics != nil)

    env^->CallVoidMethod(display, get_metrics, display_metrics)

    xdpi_id := env^->GetFieldID(display_metrics_class, "xdpi", "F")
    log.assert(xdpi_id != nil)

    xdpi := env^->GetFloatField(display_metrics, xdpi_id)

    log.debug("xdpi:", xdpi)

    ydpi_id := env^->GetFieldID(display_metrics_class, "ydpi", "F")
    log.assert(ydpi_id != nil)

    ydpi := env^->GetFloatField(display_metrics, ydpi_id)

    log.debug("ydpi:", ydpi)

    height_id := env^->GetFieldID(display_metrics_class, "heightPixels", "I")
    log.assert(height_id != nil)

    height := env^->GetIntField(display_metrics, height_id)

    log.debug("height:", height)

    // TODO: delete objects
}

backend_init :: proc(window_title: cstring, window_size: m.vec2, icon_path: cstring, window_non_resizable: bool) {
    app := cast(^android.android_app)context.user_ptr

    app.onAppCmd = handle_cmd
    app.onInputEvent = handle_input

    a_os.app = app

    env: ^android.JNIEnv
    res := app.activity.vm^->GetEnv(cast(^rawptr)&env, android.JNI_VERSION_1_6)
    if res == android.JNI_EDETACHED {
        log.debug("Attaching current thread to java vm")
        res = app.activity.vm^->AttachCurrentThread(&env, nil)
        if res != android.JNI_OK {
            log.error("Failed to attach current thread to perform JNI calls")
        }
    }

    query_dpi(app, env)

    // Early event polling in order to initialize the window
    events: i32
    source: ^android.android_poll_source
    for !a_os.window_is_ready {
        ident := android.ALooper_pollOnce(-1, nil, &events, cast(^rawptr)&source)

        if ident == i32(android.ALooperPollResult.ERROR) {
            log.fatal("ALooper_pollOnce returned an error. Exiting program")
            return
        }

        if source != nil {
            source.process(app, source)
        }

        if app.destroyRequested != 0 {
            //engine_term_display(&engine)
            return
        }
    }
}

backend_get_os_events :: proc() {
    events: i32
    source: ^android.android_poll_source

    ident := android.ALooper_pollOnce(a_os.active ? 0 : -1, nil, &events, cast(^rawptr)&source)
    for ident > 0 {
        if source != nil {
            source.process(a_os.app, source)
        }

        if a_os.app.destroyRequested != 0 {
            zephr_ctx.should_quit = true
            terminate_display()
            return
        }

        ident = android.ALooper_pollOnce(a_os.active ? 0 : -1, nil, &events, cast(^rawptr)&source)
    }

    if ident == i32(android.ALooperPollResult.ERROR) {
        log.fatal("ALooper_pollOnce returned an error. Exiting program")
    }

    //if (a_os.active) {
    //    engine_draw_frame(&engine)
    //}
}

backend_get_screen_size :: proc() -> m.vec2 {
    return {
        cast(f32)android.ANativeWindow_getWidth(a_os.app.window),
        cast(f32)android.ANativeWindow_getHeight(a_os.app.window),
    }
}

backend_change_vsync :: proc(on: bool) {
    // TODO:
    unimplemented("change vsync on android")
}

backend_swapbuffers :: proc() {
    egl.SwapBuffers(a_os.egl_display, a_os.egl_surface)
}

backend_shutdown :: proc() {
    terminate_display()
    a_os = {}
}

backend_get_asset :: proc(asset_path: string) -> Asset {
    // NOTE: On Linux and Windows we have to pass the full path to assets.
    // on Android the assets directory is assumed so we gotta split.
    final_path := asset_path[strings.index(asset_path, "/") + 1:]
    // NOTE: Open all assets as a read-only buffer for now. We can expand later to support streaming or random access
    // if we need them.
    asset := android.AAssetManager_open(a_os.app.activity.assetManager, cstring(raw_data(final_path)), .BUFFER)
    assert(asset != nil)
    buf := android.AAsset_getBuffer(asset)
    assert(buf != nil)
    len := int(android.AAsset_getLength(asset))

    return Asset{
        slice.bytes_from_ptr(buf, len),
        asset,
    }
}

backend_free_asset :: proc(asset: Asset) {
    android.AAsset_close(cast(^android.AAsset)asset.backend_ptr)
}

create_appdata_path :: proc(path: string, allocator := context.allocator) -> string {
    // NOTE: We get the app from the context pointer here because logger_init is the first proc that's called when the
    // engine is initialized, and it depends on this proc and a_os.app will be a nil pointer at this point.
    app := cast(^android.android_app)context.user_ptr

    return filepath.join({string(app.activity.internalDataPath), path}, allocator)
}

backend_gamepad_rumble :: proc(
    device: ^InputDevice,
    weak_motor: u16,
    strong_motor: u16,
    duration: time.Duration,
    delay: time.Duration,
) {
    // TODO:
    unimplemented("backend gamepad rumble on android")
}

@(private = "file")
handle_cmd :: proc "c" (app: ^android.android_app, cmd: android.AppCmd) {
    context = runtime.default_context()
    context.logger = logger

    e: Event

    #partial switch (cmd) {
        case .INIT_WINDOW:
            if app.window != nil {
                init_display()

                // TODO: Gotta reinitialize ALL GL resources (buffers, textures, shaders, etc...) when receiving INIT_WINDOW
                // This of course also means that we MUST delete and clean all resources when TERM_WINDOW is received.

                w := cast(f32)android.ANativeWindow_getWidth(app.window)
                h := cast(f32)android.ANativeWindow_getHeight(app.window)

                log.debug("GL_VENDOR:", gl.GetString(gl.VENDOR))
                log.debug("GL_RENDERER:", gl.GetString(gl.RENDERER))
                log.debug("GL_VERSION:", gl.GetString(gl.VERSION))

                log.debug("Initial width:", w)
                log.debug("Initial height:", h)

                zephr_ctx.window.size = {w, h}
                zephr_ctx.projection = orthographic_projection_2d(0, w, h, 0)

                egl.SwapInterval(a_os.egl_display, 1)

                gl.Enable(gl.BLEND)
                gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

                init_renderer({w, h})
                ui_init(DEFAULT_ENGINE_FONT)

                a_os.window_is_ready = true
            }
        case .PAUSE:
            //LOG(.INFO, LOGTAG, "PAUSE")
        case .RESUME:
            //LOG(.INFO, LOGTAG, "RESUME")
        case .STOP:
            //LOG(.INFO, LOGTAG, "STOP")
        case .START:
            //LOG(.INFO, LOGTAG, "START")
        case .INPUT_CHANGED:
            //LOG(.INFO, LOGTAG, "INPUT CHANGED")
        case .SAVE_STATE:
            //LOG(.INFO, LOGTAG, "SAVE STATE")
        case .CONFIG_CHANGED:
            //LOG(.INFO, LOGTAG, "CONFIG CHANGED")
        case .TERM_WINDOW:
            //LOG(.INFO, LOGTAG, "TERM WINDOW")
            terminate_display()
        case .WINDOW_RESIZED:
            w := android.ANativeWindow_getWidth(app.window)
            h := android.ANativeWindow_getHeight(app.window)

            zephr_ctx.window.size = m.vec2{cast(f32)w, cast(f32)h}
            zephr_ctx.screen_size = {cast(f32)w, cast(f32)h}
            zephr_ctx.projection = orthographic_projection_2d(
                0,
                zephr_ctx.window.size.x,
                zephr_ctx.window.size.y,
                0,
            )
            resize_multisample_fb(w, h)

            e.type = .WINDOW_RESIZED
            e.window.width = cast(u32)w
            e.window.height = cast(u32)h
            queue.push(&zephr_ctx.event_queue, e)
        case .GAINED_FOCUS:
            a_os.active = true
        case .LOST_FOCUS:
            a_os.active = false
            //engine_draw_frame(engine)
    }
}

@(private = "file")
handle_input :: proc "c" (app: ^android.android_app, event: ^android.AInputEvent) -> i32 {
    context = runtime.default_context()
    context.logger = logger

    e: Event

    source := android.AInputEvent_getSource(event)
    device := transmute(android.InputSourceDevice)source.device
    dev_id := cast(u64)android.AInputEvent_getDeviceId(event)

    switch android.AInputEvent_getType(event) {
        case .KEY:
            // TODO:
            e_action := android.AKeyEvent_getAction(event)
            flags := android.AKeyEvent_getFlags(event)
            keycode := android.AKeyEvent_getKeyCode(event)
            scancode := android.AKeyEvent_getScanCode(event)
            meta := android.AKeyEvent_getMetaState(event)

            if e_action == .MULTIPLE {
                log.warn("Unhandled Key event with \"MULTIPLE\" as event action")
                return 0
            }

            if keycode == .BACK || keycode == .MENU {
                // Tell the Android system that we handled the back and menu buttons even though we didn't, to prevent
                // some buttons on gamepads from exiting the activity.
                return 1
            }
            if keycode == .POWER {
                return 0
            }

            if .GAMEPAD in device || .JOYSTICK in device {
                if _, ok := zephr_ctx.input_devices_map[dev_id]; !ok {
                    os_event_queue_input_device_connected(dev_id, "Unknown Controller", {.GAMEPAD}, 0x0, 0x0)
                }

                for action in GamepadAction {
                    b := gamepad_btn_bindings[action]

                    if b == keycode {
                        os_event_queue_raw_gamepad_action(dev_id, action, e_action == .DOWN ? 1 : 0, 0)
                    }
                }

                return 1
            } else if .KEYBOARD in device {
                // Even though there's gaps this works because those gaps are filled with the value 0 (Scancode.NULL)
                // so we only have to check if the scancode exceeds the length of the array.
                if scancode >= len(android_scancode_to_zephr_scancode) {
                    log.warnf("Unknown key was pressed. Scancode: %d, Keycode: %d, Meta: %d, Flags: %d", scancode, keycode, meta, flags)
                    return 0
                }

                os_event_queue_virt_key_changed(e_action == .UP ? false : true, android_scancode_to_zephr_scancode[scancode])
                return 1
            }
        case .MOTION:

            // TODO: other sources?
            if .TOUCHSCREEN in device {
                _action := android.AMotionEvent_getAction(event)
                action := _action.action
                finger_idx := _action.pointer_index

                x := android.AMotionEvent_getX(event, uint(finger_idx))
                y := android.AMotionEvent_getY(event, uint(finger_idx))
                finger_count := u8(android.AMotionEvent_getPointerCount(event))

                // TODO: handle other events
                #partial switch action {
                    case .POINTER_DOWN: fallthrough
                    case .DOWN:
                        os_event_queue_virt_touchscreen_tap(finger_idx, finger_count, {x, y}, true)
                    case .POINTER_UP: fallthrough
                    case .UP:
                        os_event_queue_virt_touchscreen_tap(finger_idx, finger_count, {x, y}, false)
                    case .MOVE:
                        for i in 0..<finger_count {
                            finger_id := android.AMotionEvent_getPointerId(event, uint(i))
                            x = android.AMotionEvent_getX(event, uint(i))
                            y = android.AMotionEvent_getY(event, uint(i))

                            e.type = .VIRT_TOUCHSCREEN_MOVED
                            e.touchscreen_moved.device_id = 0
                            e.touchscreen_moved.pos = {x, y}
                            e.touchscreen_moved.rel_pos = {x, y} - zephr_ctx.virt_touchscreen.pos
                            e.touchscreen_moved.finger_index = i
                            e.touchscreen_moved.finger_count = finger_count
                            zephr_ctx.virt_touchscreen.rel_pos = {x, y} - zephr_ctx.virt_touchscreen.pos
                            zephr_ctx.virt_touchscreen.pos = {x, y}
                            zephr_ctx.virt_touchscreen.is_pressed = true
                            queue.push(&zephr_ctx.event_queue, e)
                        }
                    //case .CANCEL:
                }
                return 1
            }
            if .MOUSE in device {
                // TODO:
            }
            if .GAMEPAD in device || .JOYSTICK in device {
                // We seem to always just get 0x2 (MOVE) with pointer idx 0
                e_action := android.AMotionEvent_getAction(event)
                pointer_idx := cast(uint)e_action.pointer_index
                button_state := android.AMotionEvent_getButtonState(event)

                handled_event: i32 = 0

                if _, ok := zephr_ctx.input_devices_map[dev_id]; !ok {
                    os_event_queue_input_device_connected(dev_id, "Unknown Controller", {.GAMEPAD}, 0x0, 0x0)
                }

                for action in GamepadAction {
                    b := gamepad_axes_bindings[action]

                    if b == .HAT_X {
                        hat_x := android.AMotionEvent_getAxisValue(event, .HAT_X, pointer_idx)
                        if hat_x == 0 {
                            os_event_queue_raw_gamepad_action(dev_id, .DPAD_LEFT, 0, 0)
                            os_event_queue_raw_gamepad_action(dev_id, .DPAD_RIGHT, 0, 0)

                            handled_event = 1
                            continue
                        }
                        os_event_queue_raw_gamepad_action(dev_id, hat_x < 0 ? .DPAD_LEFT : .DPAD_RIGHT, 1, 0)

                        handled_event = 1
                        continue
                    }

                    if b == .HAT_Y {
                        hat_y := android.AMotionEvent_getAxisValue(event, .HAT_Y, pointer_idx)
                        if hat_y == 0 {
                            os_event_queue_raw_gamepad_action(dev_id, .DPAD_UP, 0, 0)
                            os_event_queue_raw_gamepad_action(dev_id, .DPAD_DOWN, 0, 0)

                            handled_event = 1
							continue
                        }
                        os_event_queue_raw_gamepad_action(dev_id, hat_y < 0 ? .DPAD_UP : .DPAD_DOWN, 1, 0)

                        handled_event = 1
                        continue
                    }

                    if b == .GAS {
                        gas := android.AMotionEvent_getAxisValue(event, .GAS, pointer_idx)
                        os_event_queue_raw_gamepad_action(dev_id, .TRIGGER_RIGHT, gas, 0)

                        handled_event = 1
                        continue
                    }

                    if b == .BRAKE {
                        brake := android.AMotionEvent_getAxisValue(event, .BRAKE, pointer_idx)
                        os_event_queue_raw_gamepad_action(dev_id, .TRIGGER_LEFT, brake, 0)

                        handled_event = 1
                        continue
                    }

                    if b == .X {
                        x := android.AMotionEvent_getAxisValue(event, .X, pointer_idx)
                        // TODO: maybe we should set a default deadzone.
                        os_event_queue_raw_gamepad_action(dev_id, x < 0 ? .STICK_LEFT_X_WEST : .STICK_LEFT_X_EAST, abs(x), 0)

                        handled_event = 1
                        continue
                    }

                    if b == .Y {
                        y := android.AMotionEvent_getAxisValue(event, .Y, pointer_idx)
                        // TODO: deadzone ditto
                        os_event_queue_raw_gamepad_action(dev_id, y < 0 ? .STICK_LEFT_Y_NORTH : .STICK_LEFT_Y_SOUTH, abs(y), 0)

                        handled_event = 1
                        continue
                    }

                    // Z axis seems to always be the right stick (at least for the couple of controllers I tested)
                    if b == .Z {
                        z := android.AMotionEvent_getAxisValue(event, .Z, pointer_idx)
                        // TODO: maybe we should set a default deadzone.
                        os_event_queue_raw_gamepad_action(dev_id, z < 0 ? .STICK_RIGHT_X_WEST : .STICK_RIGHT_X_EAST, abs(z), 0)

                        handled_event = 1
                        continue
                    }

                    if b == .RZ {
                        rz := android.AMotionEvent_getAxisValue(event, .RZ, pointer_idx)
                        // TODO: deadzone ditto
                        os_event_queue_raw_gamepad_action(dev_id, rz < 0 ? .STICK_RIGHT_Y_NORTH : .STICK_RIGHT_Y_SOUTH, abs(rz), 0)

                        handled_event = 1
                        continue
                    }
                }

                //action_button := android.AMotionEvent_getActionButton(event)
                //rx := android.AMotionEvent_getAxisValue(event, .RX, pointer_idx)
                //ry := android.AMotionEvent_getAxisValue(event, .RY, pointer_idx)
                //LOG(.INFO, LOGTAG, "Button State is: %d", button_state)
                //LOG(.INFO, LOGTAG, "RX: %f", rx)
                //LOG(.INFO, LOGTAG, "RY: %f", ry)

                return handled_event
            }
        case .FOCUS:
            //LOG(.INFO, LOGTAG, "Got focus event")
        case .CAPTURE:
            //LOG(.INFO, LOGTAG, "Got capture event")
        case .DRAG:
            //LOG(.INFO, LOGTAG, "Got drag event")
        case .TOUCH_MODE:
            //LOG(.INFO, LOGTAG, "Got touch event")
    }

    // TODO:
    return 0
}

@(private = "file")
init_display :: proc() {
    attribs := []i32{
        egl.SURFACE_TYPE, egl.WINDOW_BIT,
        egl.RENDERABLE_TYPE, egl.OPENGL_ES3_BIT,
        egl.BLUE_SIZE, 8,
        egl.GREEN_SIZE, 8,
        egl.RED_SIZE, 8,
        egl.ALPHA_SIZE, 8,
        egl.DEPTH_SIZE, 24,
        egl.NONE,
    }

    display := egl.GetDisplay(egl.DEFAULT_DISPLAY)
    if display == egl.NO_DISPLAY {
        log.error("eglGetDisplay returned NO_DISPLAY")
        return
    }

    if !egl.Initialize(display, nil, nil) {
        log.error("eglInitialize failed")
        return
    }

    // NOTE: I think the major and minor versions don't matter here, we just want the gl package to load all available
    // gl procs.
    gl.load_up_to(
        4,
        6,
        proc(p: rawptr, name: cstring) {(cast(^rawptr)p)^ = egl.GetProcAddress(name)}
    )

    config: egl.Config
    numConfigs: i32
    if !egl.ChooseConfig(display, raw_data(attribs), &config, 1, &numConfigs) {
        log.error("eglChooseConfig failed")
        return
    }

    format: i32
    if !egl.GetConfigAttrib(display, config, egl.NATIVE_VISUAL_ID, &format) {
        log.error("eglGetConfigAttrib failed")
        return
    }

    android.ANativeWindow_setBuffersGeometry(a_os.app.window, 0, 0, format)

    surface := egl.CreateWindowSurface(display, config, cast(egl.NativeWindowType)a_os.app.window, nil)
    if surface == nil {
        log.error("eglCreateWindowSurface returned a nil surface")
        return
    }

    ctx_attrib := []i32{ egl.CONTEXT_CLIENT_VERSION, 3, egl.NONE }
    ctx := egl.CreateContext(display, config, nil, raw_data(ctx_attrib))
    if ctx == nil {
        log.error("eglCreateContext returned a nil context")
        return
    }

    if !egl.MakeCurrent(display, surface, surface, ctx) {
        log.error("eglMakeCurrent failed")
        return
    }

    w: i32
    h: i32
    egl.QuerySurface(display, surface, egl.WIDTH, &w)
    egl.QuerySurface(display, surface, egl.HEIGHT, &h)

    gl.Viewport(0, 0, w, h)

    a_os.egl_display = display
    a_os.egl_context = ctx
    a_os.egl_surface = surface

    return
}

@(private = "file")                                                                                                     
terminate_display :: proc() {                                                                                           
    // TODO: free all memory held by buffers, textures, shaders and what have you.                                      
                                                                                                                        
    if a_os.egl_display != egl.NO_DISPLAY {                                                                             
                                                                                                                        
        egl.MakeCurrent(a_os.egl_display, egl.NO_SURFACE, egl.NO_SURFACE, egl.NO_CONTEXT)                               
        if a_os.egl_context != egl.NO_CONTEXT {                                                                         
            egl.DestroyContext(a_os.egl_display, a_os.egl_context)                                                      
        }                                                                                                               
        if a_os.egl_surface != egl.NO_SURFACE {                                                                         
            egl.DestroySurface(a_os.egl_display, a_os.egl_surface)                                                      
        }                                                                                                               
        egl.Terminate(a_os.egl_display)                                                                                 
    }                                                                                                                   
    a_os.active = false                                                                                                 
    a_os.egl_display = egl.NO_DISPLAY                                                                                   
    a_os.egl_context = egl.NO_CONTEXT                                                                                   
    a_os.egl_surface = egl.NO_SURFACE                                                                                   
}


backend_init_cursors :: proc() {/*no-op*/}
backend_set_cursor :: proc() {/*no-op*/}
backend_grab_cursor :: proc() {/*no-op*/}
backend_release_cursor :: proc() {/*no-op*/}
backend_toggle_fullscreen :: proc(fullscreen: bool) {/*no-op*/}
