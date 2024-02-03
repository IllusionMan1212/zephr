// +build linux
package evdev

import "core:sys/linux"

@private
Err :: i32

libevdev_read_flag :: enum {
	SYNC		= 1, /**< Process data in sync mode */
	NORMAL	= 2, /**< Process data in normal mode */
	FORCE_SYNC	= 4, /**< Pretend the next event is a SYN_DROPPED and
	require the caller to sync */
	BLOCKING	= 8  /**< The fd is not in O_NONBLOCK and a read may block */
}

@private
libevdev_read_status :: enum {
	/**
	 * libevdev_next_event() has finished without an error
	 * and an event is available for processing.
	 *
	 * @see libevdev_next_event
	 */
	SUCCESS = 0,
	/**
	 * Depending on the libevdev_next_event() read flag:
	 * * libevdev received a SYN_DROPPED from the device, and the caller should
	 * now resync the device, or,
	 * * an event has been read in sync mode.
	 *
	 * @see libevdev_next_event
	 */
	SYNC = 1
}

libevdev :: struct {}

#assert(size_of(input_event) == 24)

input_event :: struct {
	timeval: linux.Time_Val,
	type: u16,
	code: u16,
	value: i32,
}

/**
 * struct input_absinfo - used by EVIOCGABS/EVIOCSABS ioctls
 * @value: latest reported value for the axis.
 * @minimum: specifies minimum value for the axis.
 * @maximum: specifies maximum value for the axis.
 * @fuzz: specifies fuzz value that is used to filter noise from
 *	the event stream.
 * @flat: values that are within this value will be discarded by
 *	joydev interface and reported as 0 instead.
 * @resolution: specifies resolution for the values reported for
 *	the axis.
 *
 * Note that input core does not clamp reported values to the
 * [minimum, maximum] limits, such task is left to userspace.
 *
 * The default resolution for main axes (ABS_X, ABS_Y, ABS_Z)
 * is reported in units per millimeter (units/mm), resolution
 * for rotational axes (ABS_RX, ABS_RY, ABS_RZ) is reported
 * in units per radian.
 * When INPUT_PROP_ACCELEROMETER is set the resolution changes.
 * The main axes (ABS_X, ABS_Y, ABS_Z) are then reported in
 * units per g (units/g) and in units per degree per second
 * (units/deg/s) for rotational axes (ABS_RX, ABS_RY, ABS_RZ).
 */
input_absinfo :: struct {
	value: i32,
	minimum: i32,
	maximum: i32,
	fuzz: i32,
	flat: i32,
	resolution: i32,
}
