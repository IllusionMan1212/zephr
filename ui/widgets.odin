package zephr_ui

import "core:log"
import "../logger"

ImageDrawData :: struct {
    texture: TextureId,
    tint: Color,
    blur: int,
}

// column is popped when its calling scope ends
@(deferred_none=pop_parent)
column :: proc(id := Id(0), caller := #caller_location) {
    set_next_layout_axis(.Y)
    rect := create_box_with_id({}, id, caller)
    push_parent(rect)
}

// row is popped when its calling scope ends
@(deferred_none=pop_parent)
row :: proc(id := Id(0), caller := #caller_location) {
    set_next_layout_axis(.X)
    rect := create_box_with_id({}, id, caller)
    push_parent(rect)
}

button :: proc(text: string) -> bool {
    // TODO:
    return false
}

text :: proc(str: string) {
    // TODO: implement the text widget
    // TODO: maybe we can hash the passd string and use that to have a unique id??
    // this breaks if we have more than one button with the same text.
    // can be fixed by using the same system as imgui and raddebugger with the displayedtext###uniquehash stuff but
    // i'm too lazy for now.
    box := create_box_with_id({.DrawText}, Id(0))
    box_equip_display_string(box, str)
    //UI_Signal interact = ui_signal_from_box(box)
    //return interact
}

@(private)
image_draw :: proc(box: ^Box, user_data: rawptr) {
    context.logger = logger.logger
    draw_data := cast(^ImageDrawData)user_data
    log.assert(draw_data.texture != 0, "Invalid texture ID")

    instance_image(box.rect, draw_data.texture, draw_data.tint, draw_data.blur)
}

image :: proc(texture: TextureId, tint: Color = {1, 1, 1, 1}, blur: int = 0, caller := #caller_location) {
    context.logger = logger.logger
    box := create_box_with_id({}, Id(0), caller)
    image_data := new(ImageDrawData, build_allocator())
    image_data.texture = texture
    image_data.tint = tint
    image_data.blur = blur
    box_equip_custom_draw(box, image_draw, cast(rawptr)image_data)
    //UI_Signal sig = ui_signal_from_box(box)
    //return sig
}

spacer :: proc(size: Size) {
    parent := top_parent()
    // NOTE: We set the other axis to 0 here to prevent the box from taking the default space
    // specified on the width and height stacks.
    // This prevents us from visualizing the spacers but fixes the cases where padding will change the parent's 
    // size (e.g. parent has children_sum but padding's width or height becomes the biggest because of the default on the stack)
    // This is "better" solution imo because we can just increase the sizes if we need to visualize.
    //set_next_pref_size(parent.layout_axis, size)
    if parent.layout_axis == .X {
        set_next_width(size)
        set_next_height(px(0, 0))
    } else {
        set_next_height(size)
        set_next_width(px(0, 0))
    }
    // NOTE: for debug only
    //set_next_background_color({0.6, 0, 1, 1})
    //set_next_flags({.DrawBackground})
    box := create_box_with_id({}, Id(0))
    //UI_Signal interact = ui_signal_from_box(box)
    //return interact
}
