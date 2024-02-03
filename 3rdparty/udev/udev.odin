package udev

import "core:sys/linux"

foreign import udev_lib "system:udev"

foreign udev_lib {
	@(link_name = "udev_new")
	new :: proc() -> ^udev ---
	@(link_name = "udev_monitor_new_from_netlink")
	monitor_new_from_netlink :: proc(udev: ^udev, name: cstring) -> ^udev_monitor ---
	@(link_name = "udev_monitor_filter_add_match_subsystem_devtype")
	monitor_filter_add_match_subsystem_devtype :: proc(udev_monitor: ^udev_monitor, subsystem: cstring, device_type: cstring) -> i32 ---
	@(link_name = "udev_monitor_enable_receiving")
	monitor_enable_receiving :: proc(udev_monitor: ^udev_monitor) -> i32 ---
	@(link_name = "udev_monitor_get_fd")
	monitor_get_fd :: proc(udev_monitor: ^udev_monitor) -> linux.Fd ---
	@(link_name = "udev_enumerate_new")
	enumerate_new :: proc(udev: ^udev) -> ^udev_enumerate ---
	@(link_name = "udev_enumerate_add_match_subsystem")
	enumerate_add_match_subsystem :: proc(enumerate: ^udev_enumerate, subsystem: cstring) -> i32 ---
	@(link_name = "udev_enumerate_add_match_property")
	enumerate_add_match_property :: proc(enumerate: ^udev_enumerate, property: cstring, value: cstring) -> i32 ---
	@(link_name = "udev_enumerate_scan_devices")
	enumerate_scan_devices :: proc(enumerate: ^udev_enumerate) -> i32 ---
	@(link_name = "udev_enumerate_get_list_entry")
	enumerate_get_list_entry :: proc(enumerate: ^udev_enumerate) -> ^udev_list_entry ---
	@(link_name = "udev_list_entry_get_name")
	list_entry_get_name :: proc(list_entry: ^udev_list_entry) -> cstring ---
	@(link_name = "udev_list_entry_get_value")
	list_entry_get_value :: proc(list_entry: ^udev_list_entry) -> cstring ---
	@(link_name = "udev_device_new_from_syspath")
	device_new_from_syspath :: proc(udev: ^udev, syspath: cstring) -> ^udev_device ---
	@(link_name = "udev_device_unref")
	device_unref :: proc(dev: ^udev_device) -> ^udev_device ---
	@(link_name = "udev_enumerate_unref")
	enumerate_unref :: proc(enumerate: ^udev_enumerate) -> ^udev_enumerate ---
	@(link_name = "udev_list_entry_get_next")
	list_entry_get_next :: proc(list_entry: ^udev_list_entry) -> ^udev_list_entry ---
	@(link_name = "udev_enumerate_add_match_parent")
	enumerate_add_match_parent :: proc(enumerate: ^udev_enumerate, parent: ^udev_device) -> i32 ---
	@(link_name = "udev_device_get_sysname")
	device_get_sysname :: proc(dev: ^udev_device) -> cstring ---
	@(link_name = "udev_device_get_property_value")
	device_get_property_value :: proc(dev: ^udev_device, key: cstring) -> cstring ---
	@(link_name = "udev_monitor_receive_device")
	monitor_receive_device :: proc(udev_monitor: ^udev_monitor) -> ^udev_device ---
	@(link_name = "udev_device_get_action")
	device_get_action :: proc(udev_device: ^udev_device) -> cstring ---
	@(link_name = "udev_device_get_devnum")
	device_get_devnum :: proc(dev: ^udev_device) -> dev_t ---
	@(link_name = "udev_device_get_devnode")
	device_get_devnode :: proc(dev: ^udev_device) -> cstring ---
	@(link_name = "udev_device_get_sysattr_value")
	device_get_sysattr_value :: proc(dev: ^udev_device, attr: cstring) -> cstring ---
	@(link_name = "udev_device_get_parent_with_subsystem_devtype")
	device_get_parent_with_subsystem_devtype :: proc(dev: ^udev_device, subsystem: cstring, devtype: cstring) -> ^udev_device ---
	@(link_name = "udev_device_get_subsystem")
	device_get_subsystem :: proc(dev: ^udev_device) -> cstring ---
	@(link_name = "udev_device_get_properties_list_entry")
	device_get_properties_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
	@(link_name = "udev_device_get_sysattr_list_entry")
	device_get_sysattr_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
	@(link_name = "udev_device_get_tags_list_entry")
	device_get_tags_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
	@(link_name = "udev_device_get_current_tags_list_entry")
	device_get_current_tags_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
}
