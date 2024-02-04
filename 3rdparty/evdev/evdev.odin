package evdev

import "core:os"

foreign import evdev "system:evdev"

foreign evdev {
    @(link_name = "libevdev_new_from_fd")
    new_from_fd :: proc(fd: os.Handle, dev: ^^libevdev) -> Err ---
    @(link_name = "libevdev_get_id_bustype")
    get_id_bustype :: proc(dev: ^libevdev) -> u16 ---
    @(link_name = "libevdev_get_id_vendor")
    get_id_vendor :: proc(dev: ^libevdev) -> u16 ---
    @(link_name = "libevdev_get_id_product")
    get_id_product :: proc(dev: ^libevdev) -> u16 ---
    @(link_name = "libevdev_has_event_pending")
    has_event_pending :: proc(dev: ^libevdev) -> i32 ---
    @(link_name = "libevdev_next_event")
    next_event :: proc(dev: ^libevdev, flags: libevdev_read_flag, ev: ^input_event) -> i32 ---
    @(link_name = "libevdev_get_abs_flat")
    get_abs_flat :: proc(dev: ^libevdev, code: u32) -> i32 ---
    @(link_name = "libevdev_get_name")
    get_name :: proc(dev: ^libevdev) -> cstring ---
    @(link_name = "libevdev_get_abs_info")
    get_abs_info :: proc(dev: ^libevdev, code: u32) -> ^input_absinfo ---
    @(link_name = "libevdev_get_uniq")
    get_uniq :: proc(dev: ^libevdev) -> cstring ---
    @(link_name = "libevdev_get_phys")
    get_phys :: proc(dev: ^libevdev) -> cstring ---
    @(link_name = "libevdev_free")
    free :: proc(dev: ^libevdev) ---
    @(link_name = "libevdev_has_event_type")
    has_event_type :: proc(dev: ^libevdev, type: u32) -> bool ---
    @(link_name = "libevdev_has_event_code")
    has_event_code :: proc(dev: ^libevdev, type: u32, code: u32) -> bool ---
    @(link_name = "libevdev_get_fd")
    get_fd :: proc(dev: ^libevdev) -> os.Handle ---
}
