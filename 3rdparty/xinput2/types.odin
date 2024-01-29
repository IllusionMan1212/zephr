// +build linux
package xinput2

import x11 "vendor:x11/xlib"

AllDevices       :: 0
AllMasterDevices :: 1

EventType :: enum i32 {
  DeviceChanged = 1,
  KeyPress,
  KeyRelease,
  ButtonPress,
  ButtonRelease,
  Motion,
  Enter,
  Leave,
  FocusIn,
  FocusOut,
  HierarchyChanged,
  Property,
  RawKeyPress,
  RawKeyRelease,
  RawButtonPress,
  RawButtonRelease,
  RawMotion,
  TouchBegin,
  TouchUpdate,
  TouchEnd,
  TouchOwnership,
  RawTouchBegin,
  RawTouchUpdate,
  RawTouchEnd,
  BarrierHit,
  BarrierLeave,
  GesturePinchBegin,
  GesturePinchUpdate,
  GesturePinchEnd,
  GestureSwipeBegin,
  GestureSwipeUpdate,
  GestureSwipeEnd,

  LastEvent = GestureSwipeEnd,
}

#assert(size_of(EventMask) == 16)

EventMask :: struct {
  deviceid: i32,
  mask_len: i32,
  mask:     [^]u8,
}

#assert(size_of(XIValuatorState) == 24)

@private
XIValuatorState :: struct {
  mask_len: i32,
  mask: [^]u8,
  values: [^]f64,
}

#assert(size_of(RawEvent) == 96)

RawEvent :: struct {
  type: x11.EventType,         /* GenericEvent */
  serial: u64,       /* # of last request processed by server */
  send_event: b32,   /* true if this came from a SendEvent request */
  display: ^x11.Display,     /* Display the event was read from */
  extension: i32,    /* XI extension offset */
  evtype: EventType,       /* XI_RawKeyPress, XI_RawKeyRelease, etc. */
  time: x11.Time,
  deviceid: i32,
  sourceid: i32,     /* Bug: Always 0. https://bugs.freedesktop.org//show_bug.cgi?id=34240 */
  detail: i32,
  flags: i32,
  valuators: XIValuatorState,
  raw_values: [^]f64,
}
