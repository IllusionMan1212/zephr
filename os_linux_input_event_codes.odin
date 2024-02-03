// +build linux
// +private
package zephr

/*
* Event types
*/

EV_SYN       :: 0x00
EV_KEY       :: 0x01
EV_REL       :: 0x02
EV_ABS       :: 0x03
EV_MSC       :: 0x04
EV_SW        :: 0x05
EV_LED       :: 0x11
EV_SND       :: 0x12
EV_REP       :: 0x14
EV_FF        :: 0x15
EV_PWR       :: 0x16
EV_FF_STATUS :: 0x17
EV_MAX       :: 0x1f
EV_CNT       :: (EV_MAX+1)

/*
 * Synchronization events.
 */

SYN_REPORT  :: 0
SYN_DROPPED :: 3

/*
* Absolute axes
*/

ABS_X  :: 0x00
ABS_Y  :: 0x01
ABS_Z  :: 0x02
ABS_RX :: 0x03
ABS_RY :: 0x04
ABS_RZ :: 0x05
ABS_HAT0X :: 0x10
ABS_HAT0Y :: 0x11
ABS_HAT1X :: 0x12
ABS_HAT1Y :: 0x13
ABS_HAT2X :: 0x14
ABS_HAT2Y :: 0x15
ABS_HAT3X :: 0x16
ABS_HAT3Y :: 0x17

/* Buttons */

BTN_SOUTH  :: 0x130
BTN_EAST   :: 0x131
BTN_WEST   :: 0x134
BTN_NORTH  :: 0x133
BTN_TL     :: 0x136
BTN_TR     :: 0x137
BTN_SELECT :: 0x13a
BTN_START  :: 0x13b
BTN_THUMBL :: 0x13d
BTN_THUMBR :: 0x13e

BTN_DPAD_UP    :: 0x220
BTN_DPAD_DOWN  :: 0x221
BTN_DPAD_LEFT  :: 0x222
BTN_DPAD_RIGHT :: 0x223

BTN_LEFT    :: 0x110
BTN_RIGHT   :: 0x111
BTN_MIDDLE  :: 0x112
BTN_SIDE    :: 0x113
BTN_EXTRA   :: 0x114
BTN_TOUCH :: 0x14a

/* Relative axes */

REL_X      :: 0x00
REL_Y      :: 0x01
REL_HWHEEL :: 0x06
REL_WHEEL  :: 0x08
