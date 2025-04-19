package zephr

import m "core:math/linalg/glsl"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import "core:log"
import "core:hash"
import "core:strings"

ui_state: State

Id :: u32

Axis :: enum {
    X,
    Y,
}

SizeKind :: enum {
    Null,
    Pixels,
    TextContent,
    PercentOfParent,
    ChildrenSum,
}

TextAlign :: enum {
    Left,
    Center,
    Right,
}

Flag :: enum {
    DrawBackground,
    DrawBorder,
    DrawText,
    FloatingX,
    FloatingY,
    FixedWidth,
    FixedHeight,
    AllowOverflowX,
}
Flags :: bit_set[Flag]

Floating :: Flags{.FloatingX, .FloatingY}
FixedSize :: Flags{.FixedWidth, .FixedHeight}

Size :: struct {
    kind: SizeKind,
    value: f32,
    strictness: f32,
}

#assert(size_of(Rect) == 16)
Rect :: struct #raw_union {
    using _: struct {
        x0: f32,
        y0: f32,
        x1: f32,
        y1: f32,
    },
    using _: struct {
        p0: [2]f32,
        p1: [2]f32,
    },
    using _: struct {
        min: [2]f32,
        max: [2]f32,
    },
}

#assert(size_of(DrawableInstance) == 92)
DrawableInstance :: struct {
    rect: Rect,
    // Used as bg color when drawing background, text color when drawing text, border color when drawing borders.
    colors: [4]Color,
    border_thickness: f32,
    border_smoothness: f32,
    border_radius: f32,
}

Box :: struct {
    // per-build links/data
    first: ^Box,
    last: ^Box,
    next: ^Box,
    prev: ^Box,
    parent: ^Box,
    child_count: u64,

    // per-build equipment
    id: Id,
    flags: Flags,
    string: string,
    text_align: TextAlign,
    fixed_position: [2]f32,
    fixed_size: [2]f32,
    pref_size: [Axis]Size,
    layout_axis: Axis,
    custom_draw: BoxCustomDrawFunctionType,
    custom_draw_user_data: rawptr,
    background_color: Color,
    text_color: Color,
    border_color: Color,
    border_thickness: f32,
    border_smoothness: f32,
    border_radius: f32,
    //font: F_Tag,
    //font_size: f32,
    //tab_size: f32,

    // per-build artifacts
    //display_string_runs: D_FancyRunList,
    position_delta: [2]f32,
    rect: Rect,
}

DrawCommand :: struct {
    drawables: [dynamic]DrawableInstance,
    has_texture: bool,
    tex: TextureId,
    blur: int,
}

State :: struct {
    // TODO:
    arenas: [2]virtual.Arena,
    allocators: [2]mem.Allocator,

    build_index: u64,

    root: ^Box,

    draw_cmds: [dynamic]DrawCommand,
    curr_draw_cmd: DrawCommand,

    parent_stack: Stack(ParentNode),
    layout_axis_stack: Stack(LayoutAxisNode),
    fixed_x_stack: Stack(FixedXNode),
    fixed_y_stack: Stack(FixedYNode),
    fixed_width_stack: Stack(FixedWidthNode),
    fixed_height_stack: Stack(FixedHeightNode),
    pref_width_stack: Stack(PrefWidthNode),
    pref_height_stack: Stack(PrefHeightNode),
    background_color_stack: Stack(BackgroundColorNode),
    text_color_stack: Stack(TextColorNode),
    border_color_stack: Stack(BorderColorNode),
    border_thickness_stack: Stack(BorderThicknessNode),
    border_smoothness_stack: Stack(BorderSmoothnessNode),
    border_radius_stack: Stack(BorderRadiusNode),
    flags_stack: Stack(FlagsNode),

    parent_nil_stack_top: ParentNode,
    layout_axis_nil_stack_top: LayoutAxisNode,
    fixed_x_nil_stack_top: FixedXNode,
    fixed_y_nil_stack_top: FixedYNode,
    fixed_width_nil_stack_top: FixedWidthNode,
    fixed_height_nil_stack_top: FixedHeightNode,
    pref_width_nil_stack_top: PrefWidthNode,
    pref_height_nil_stack_top: PrefHeightNode,
    background_color_nil_stack_top: BackgroundColorNode,
    text_color_nil_stack_top: TextColorNode,
    border_color_nil_stack_top: BorderColorNode,
    border_thickness_nil_stack_top: BorderThicknessNode,
    border_smoothness_nil_stack_top: BorderSmoothnessNode,
    border_radius_nil_stack_top: BorderRadiusNode,
    flags_nil_stack_top: FlagsNode,
}

BoxCustomDrawFunctionType :: #type proc(box: ^Box, user_data: rawptr)

ui_px           :: proc(value, strictness: f32) -> Size {return {.Pixels, value, strictness}}
ui_text_dim     :: proc(padding, strictness: f32) -> Size {return {.TextContent, padding, strictness}}
ui_percent      :: proc(value, strictness: f32) -> Size {return {.PercentOfParent, value, strictness}}
ui_children_sum :: proc(strictness: f32) -> Size {return {.ChildrenSum, 0, strictness}}

ui_create_box_with_id :: proc(flags: Flags, id: Id, caller := #caller_location) -> ^Box {
    //ui_state.build_box_count += 1

    id := make_box_id(id, caller)

    //- rjf: grab active parent
    parent := top_parent()

    //- rjf: try to get box
    //UI_BoxFlags last_flags = 0
    //box := box_from_id(id)
    //box_first_frame := box == nil
    //B32 box_first_frame = ui_box_is_nil(box)
    //last_flags = box.flags

    //- rjf: zero key on duplicate
    //if(!box_first_frame && box.last_touched_build_index == ui_state.build_index)
    //{
    //  box = &ui_g_nil_box
    //  key = ui_key_zero()
    //  box_first_frame = 1
    //}

    //- rjf: gather info from box
    // transient boxes are widgets that aren't passed an ID and therefore don't have their state persisted
    //B32 box_is_transient = ui_key_match(key, ui_key_zero())

    //- rjf: allocate box if it doesn't yet exist
    box := new(Box, build_allocator())
    //if(box_first_frame)
    //{
    //  box = !box_is_transient ? ui_state.first_free_box : 0
    //  ui_state.is_animating = ui_state.is_animating || !box_is_transient
    //  if(!ui_box_is_nil(box))
    //  {
    //    SLLStackPop(ui_state.first_free_box)
    //  }
    //  else
    //  {
    //    box = push_array_no_zero(box_is_transient ? ui_build_arena() : ui_state.arena, UI_Box, 1)
    //  }
    //  MemoryZeroStruct(box)
    //}

    //- rjf: zero out per-frame state
    {
        box.first = nil
        box.last = nil
        box.next = nil
        box.prev = nil
        box.parent = nil
        box.child_count = 0
        box.flags = {}
        box.pref_size = {}
        //box.hover_cursor = OS_Cursor_Pointer
        //MemoryZeroStruct(&box.draw_bucket)
    }

    //- rjf: hook into persistent state table
    //if(box_first_frame && !box_is_transient)
    //{
    //  U64 slot = key.u64[0] % ui_state.box_table_size
    //  DLLInsert_NPZ(&ui_g_nil_box, ui_state.box_table[slot].hash_first, ui_state.box_table[slot].hash_last, ui_state.box_table[slot].hash_last, box, hash_next, hash_prev)
    //}

    //- rjf: hook into per-frame tree structure
    if parent != nil {
        double_linked_list_push_back(&parent.first, &parent.last, &box)
        parent.child_count += 1
        box.parent = parent
    }

    //- rjf: fill box
    {
        box.id = id
        box.flags = flags | ui_state.flags_stack.top.v
        //box.fastpath_codepoint = ui_state.fastpath_codepoint_stack.top.v

        //if(ui_is_focus_active() && (box.flags & UI_BoxFlag_DefaultFocusNav) && ui_key_match(ui_state.default_nav_root_key, ui_key_zero()))
        //{
        //  ui_state.default_nav_root_key = box.key
        //}

        //if(box_first_frame)
        //{
        //  box.first_touched_build_index = ui_state.build_index
        //  box.disabled_t = (F32)!!(box.flags & UI_BoxFlag_Disabled)
        //}
        //box.last_touched_build_index = ui_state.build_index
        
        //if(box.flags & UI_BoxFlag_Disabled && (!(last_flags & UI_BoxFlag_Disabled) || box_first_frame))
        //{
        //  box.first_disabled_build_index = ui_state.build_index
        //}

        if ui_state.fixed_x_stack.top != &ui_state.fixed_x_nil_stack_top {
          box.flags |= {.FloatingX}
          box.fixed_position.x = ui_state.fixed_x_stack.top.v
        }
        if ui_state.fixed_y_stack.top != &ui_state.fixed_y_nil_stack_top {
          box.flags |= {.FloatingY}
          box.fixed_position.y = ui_state.fixed_y_stack.top.v
        }

        if ui_state.fixed_width_stack.top != &ui_state.fixed_width_nil_stack_top {
            box.flags |= {.FixedWidth}
            box.fixed_size.x = ui_state.fixed_width_stack.top.v
        } else {
            box.pref_size[.X] = ui_state.pref_width_stack.top.v
        }

        if ui_state.fixed_height_stack.top != &ui_state.fixed_height_nil_stack_top {
            box.flags |= {.FixedHeight}
            box.fixed_size.y = ui_state.fixed_height_stack.top.v
        } else {
            box.pref_size[.Y] = ui_state.pref_height_stack.top.v
        }

        //B32 is_auto_focus_active = ui_is_key_auto_focus_active(key)
        //B32 is_auto_focus_hot    = ui_is_key_auto_focus_hot(key)
        //if(is_auto_focus_active)
        //{
        //  ui_set_next_focus_active(UI_FocusKind_On)
        //}
        //if(is_auto_focus_hot)
        //{
        //  ui_set_next_focus_hot(UI_FocusKind_On)
        //}
        //box.flags |= UI_BoxFlag_FocusHot    * (ui_state.focus_hot_stack.top.v == UI_FocusKind_On)
        //box.flags |= UI_BoxFlag_FocusActive * (ui_state.focus_active_stack.top.v == UI_FocusKind_On)
        //if(box.flags & UI_BoxFlag_FocusHot && !ui_is_focus_hot())
        //{
        //  box.flags |= UI_BoxFlag_FocusHotDisabled
        //}
        //if(box.flags & UI_BoxFlag_FocusActive && !ui_is_focus_active())
        //{
        //  box.flags |= UI_BoxFlag_FocusActiveDisabled
        //}

        //box.text_align = ui_state.text_alignment_stack.top.v
        box.layout_axis = ui_state.layout_axis_stack.top.v
        box.background_color = ui_state.background_color_stack.top.v
        box.text_color = ui_state.text_color_stack.top.v
        box.border_color = ui_state.border_color_stack.top.v
        box.border_thickness = ui_state.border_thickness_stack.top.v
        box.border_smoothness = ui_state.border_smoothness_stack.top.v
        //box.overlay_color = ui_state.overlay_color_stack.top.v
        //box.font = ui_state.font_stack.top.v
        //box.font_size = ui_state.font_size_stack.top.v
        //box.tab_size = ui_state.tab_size_stack.top.v
        box.border_radius = ui_state.border_radius_stack.top.v
        //box.corner_radii[Corner_00] = ui_state.corner_radius_00_stack.top.v
        //box.corner_radii[Corner_01] = ui_state.corner_radius_01_stack.top.v
        //box.corner_radii[Corner_10] = ui_state.corner_radius_10_stack.top.v
        //box.corner_radii[Corner_11] = ui_state.corner_radius_11_stack.top.v
        //box.blur_size = ui_state.blur_size_stack.top.v
        //box.transparency = ui_state.transparency_stack.top.v
        //box.squish = ui_state.squish_stack.top.v
        //box.text_padding = ui_state.text_padding_stack.top.v
        //box.hover_cursor = ui_state.hover_cursor_stack.top.v
        box.custom_draw = nil
    }

    //- rjf: auto-pop all stacks
    {
        auto_pop_stacks()
    }

    //- rjf: return
    return box
}

ui_box_equip_display_string :: proc(box: ^Box, str: string) {
    //ProfBeginFunction();
    box.string = strings.clone(str, build_allocator())
    // TODO: I think HasDisplayString is for clipboard stuff
    //box.flags |= .HasDisplayString

    // TODO: Idk what this fastpath stuff is. For now we'll just hardcode one of the branches
    if .DrawText in box.flags /*&& (box->fastpath_codepoint == 0 || !(box->flags & UI_BoxFlag_DrawTextFastpathCodepoint))*/ {
        // TODO: this box_display_string proc calls another proc that removes the ### to use them for ids.
        // We don't use that yet.
        //String8 display_string = ui_box_display_string(box)
        // TODO: This fancy shmancy node and list and string stuff is a bit annoying because if I'm going to be using it
        // then I'll have to write and implement a lot of stuff related to fonts and text caching and shit
        // since it's so tightly coupled together. The upside is I'll probably have REALLY good text rendering once
        // I do implement it. On one hand I just want something that will work (although it will prob be shit) on the
        // other it would be really nice to finally solve the font rendering problems (including unicode and shit). IDK.
        //display_string := box.string
        //fancy_string_n: D_FancyStringNode = {nil, {box.font, display_string, box.text_color, box.font_size, 0, 0}}
        //fancy_strings: D_FancyStringList = {&fancy_string_n, &fancy_string_n, 1, 0}
        //box.display_string_runs = d_fancy_run_list_from_fancy_string_list(build_allocator(), box.tab_size, &fancy_strings)
    } /*else if .DrawText in box.flags && box->flags & UI_BoxFlag_DrawTextFastpathCodepoint && box->fastpath_codepoint != 0 {
        Temp scratch = scratch_begin(0, 0);
        String8 display_string = ui_box_display_string(box);
        String32 fpcp32 = str32(&box->fastpath_codepoint, 1);
        String8 fpcp = str8_from_32(scratch.arena, fpcp32);
        U64 fpcp_pos = str8_find_needle(display_string, 0, fpcp, StringMatchFlag_CaseInsensitive);
        if (fpcp_pos < display_string.size) {
            D_FancyStringNode pst_fancy_string_n = {0,                   {box->font, str8_skip(display_string, fpcp_pos+fpcp.size), box->text_color, box->font_size, 0, 0}};
            D_FancyStringNode cdp_fancy_string_n = {&pst_fancy_string_n, {box->font, str8_substr(display_string, r1u64(fpcp_pos, fpcp_pos+fpcp.size)), box->text_color, box->font_size, 4.f, 0}};
            D_FancyStringNode pre_fancy_string_n = {&cdp_fancy_string_n, {box->font, str8_prefix(display_string, fpcp_pos), box->text_color, box->font_size, 0, 0}};
            D_FancyStringList fancy_strings = {&pre_fancy_string_n, &pst_fancy_string_n, 3};
            box->display_string_runs = d_fancy_run_list_from_fancy_string_list(ui_build_arena(), box->tab_size, &fancy_strings);
        } else {
            D_FancyStringNode fancy_string_n = {0, {box->font, display_string, box->text_color, box->font_size, 0, 0}};
            D_FancyStringList fancy_strings = {&fancy_string_n, &fancy_string_n, 1};
            box->display_string_runs = d_fancy_run_list_from_fancy_string_list(ui_build_arena(), box->tab_size, &fancy_strings);
        }
        scratch_end(scratch);
    }*/
    //ProfEnd();
}

ui_box_equip_custom_draw :: proc(box: ^Box, custom_draw: BoxCustomDrawFunctionType, user_data: rawptr) {
    box.custom_draw = custom_draw
    box.custom_draw_user_data = user_data
}

// TODO: debug proc. remove when done with it
ui_print :: proc() {
    // DFS
    iter_children :: proc(node: ^Box) {
        for child := node.first; child != nil; child = child.next {
            log.debug(child.rect.p0, child.rect.p1)
            iter_children(child)
        }
    }

    log.debug("Printing ui from root")
    log.debug(ui_state.root.rect.p0, ui_state.root.rect.p1)

    iter_children(ui_state.root)

    log.debug("Done")
}

ui_set_next_width :: #force_inline proc(width: Size) {
    stack_set(&ui_state.pref_width_stack, Size, width)
}

ui_set_next_height :: #force_inline proc(height: Size) {
    stack_set(&ui_state.pref_height_stack, Size, height)
}

ui_set_next_fixed_x :: #force_inline proc(x: f32) {
    stack_set(&ui_state.fixed_x_stack, f32, x)
}

ui_set_next_fixed_y :: #force_inline proc(y: f32) {
    stack_set(&ui_state.fixed_y_stack, f32, y)
}

ui_set_next_fixed_width :: #force_inline proc(width: f32) {
    stack_set(&ui_state.fixed_width_stack, f32, width)
}

ui_set_next_fixed_height :: #force_inline proc(height: f32) {
    stack_set(&ui_state.fixed_height_stack, f32, height)
}

ui_set_next_pref_size :: #force_inline proc(axis: Axis, v: Size) {
    (axis == .X ? ui_set_next_width : ui_set_next_height)(v)
}

ui_set_next_background_color :: #force_inline proc(color: Color) {
    stack_set(&ui_state.background_color_stack, Color, color)
}

ui_set_next_flags :: #force_inline proc(flags: Flags) {
    stack_set(&ui_state.flags_stack, Flags, flags)
}

ui_push_fixed_x :: #force_inline proc(x: f32) {
    stack_push(&ui_state.fixed_x_stack, f32, x)
}

ui_push_fixed_y :: #force_inline proc(y: f32) {
    stack_push(&ui_state.fixed_y_stack, f32, y)
}

ui_push_pref_width :: #force_inline proc(width: Size) {
    stack_push(&ui_state.pref_width_stack, Size, width)
}

ui_push_pref_height :: #force_inline proc(height: Size) {
    stack_push(&ui_state.pref_height_stack, Size, height)
}

ui_push_background_color :: #force_inline proc(color: Color) {
    stack_push(&ui_state.background_color_stack, Color, color)
}

ui_push_text_color :: #force_inline proc(color: Color) {
    stack_push(&ui_state.text_color_stack, Color, color)
}

ui_push_border_color :: #force_inline proc(color: Color) {
    stack_push(&ui_state.border_color_stack, Color, color)
}

ui_push_border_thickness :: #force_inline proc(thickness: f32) {
    stack_push(&ui_state.border_thickness_stack, f32, thickness)
}

ui_push_border_smoothness :: #force_inline proc(smoothness: f32) {
    stack_push(&ui_state.border_smoothness_stack, f32, smoothness)
}

ui_push_border_radius :: #force_inline proc(radius: f32) {
    stack_push(&ui_state.border_radius_stack, f32, radius)
}

ui_push_flags :: #force_inline proc(flags: Flags) {
    stack_push(&ui_state.flags_stack, Flags, flags)
}

ui_pop_layout_axis :: #force_inline proc() {
    stack_pop(&ui_state.layout_axis_stack, &ui_state.layout_axis_nil_stack_top)
}

ui_pop_fixed_x :: #force_inline proc() {
    stack_pop(&ui_state.fixed_x_stack, &ui_state.fixed_x_nil_stack_top)
}

ui_pop_fixed_y :: #force_inline proc() {
    stack_pop(&ui_state.fixed_y_stack, &ui_state.fixed_y_nil_stack_top)
}

ui_pop_fixed_width :: #force_inline proc() {
    stack_pop(&ui_state.fixed_width_stack, &ui_state.fixed_width_nil_stack_top)
}

ui_pop_fixed_height :: #force_inline proc() {
    stack_pop(&ui_state.fixed_height_stack, &ui_state.fixed_height_nil_stack_top)
}

ui_pop_pref_width :: #force_inline proc() {
    stack_pop(&ui_state.pref_width_stack, &ui_state.pref_width_nil_stack_top)
}

ui_pop_pref_height :: #force_inline proc() {
    stack_pop(&ui_state.pref_height_stack, &ui_state.pref_height_nil_stack_top)
}

ui_pop_background_color :: #force_inline proc() {
    stack_pop(&ui_state.background_color_stack, &ui_state.background_color_nil_stack_top)
}

ui_pop_text_color :: #force_inline proc() {
    stack_pop(&ui_state.text_color_stack, &ui_state.text_color_nil_stack_top)
}

ui_pop_border_color :: #force_inline proc() {
    stack_pop(&ui_state.border_color_stack, &ui_state.border_color_nil_stack_top)
}

ui_pop_border_thickness :: #force_inline proc() {
    stack_pop(&ui_state.border_thickness_stack, &ui_state.border_thickness_nil_stack_top)
}

ui_pop_border_smoothness :: #force_inline proc() {
    stack_pop(&ui_state.border_smoothness_stack, &ui_state.border_smoothness_nil_stack_top)
}

ui_pop_border_radius :: #force_inline proc() {
    stack_pop(&ui_state.border_radius_stack, &ui_state.border_radius_nil_stack_top)
}

ui_pop_flags :: #force_inline proc() {
    stack_pop(&ui_state.flags_stack, &ui_state.flags_nil_stack_top)
}

@(deferred_in=ui_spacer)
ui_padding :: proc(size: Size) {
    ui_spacer(size)
}

ui_init :: proc() {
    err := virtual.arena_init_growing(&ui_state.arenas[0], mem.Megabyte * 16)
    if err != nil {
        log.error("Failed to allocate memory for UI")
        return
    }
    err = virtual.arena_init_growing(&ui_state.arenas[1], mem.Megabyte * 16)
    if err != nil {
        log.error("Failed to allocate memory for UI")
        return
    }
    ui_state.allocators[0] = virtual.arena_allocator(&ui_state.arenas[0])
    ui_state.allocators[1] = virtual.arena_allocator(&ui_state.arenas[1])
    ui_state.draw_cmds = make([dynamic]DrawCommand, 0, 32, context.temp_allocator)
    ui_state.curr_draw_cmd.drawables = make([dynamic]DrawableInstance, 0, 128, context.temp_allocator)

    init_nil_stacks()
    init_drawing()
}

ui_shutdown :: proc() {
    delete(ui_state.curr_draw_cmd.drawables)
    delete(ui_state.draw_cmds)
}

ui_begin_build :: proc(window_size: m.vec2) {
    init_stacks()
    // TODO:
    //- rjf: build top-level root
    {
        ui_set_next_fixed_width(window_size.x)
        ui_set_next_fixed_height(window_size.y)
        set_next_layout_axis(.X)
        root := ui_create_box_with_id({}, 55120055)
        push_parent(root)
        ui_state.root = root
    }
}

ui_end_build :: proc() {
    //- rjf: layout box tree
    {
        for axis in Axis {
            layout_root(ui_state.root, axis)
        }
    }

    ui_state.build_index += 1
    free_all(build_allocator())
}

@(private)
build_allocator :: #force_inline proc() -> mem.Allocator {
    return ui_state.allocators[ui_state.build_index%2]
}

@(private)
calc_sizes_standalone__in_place_rec :: proc(root: ^Box, axis: Axis) {
    #partial switch root.pref_size[axis].kind {
        case .Pixels:
            root.fixed_size[axis] = root.pref_size[axis].value
        case .TextContent:
            padding := root.pref_size[axis].value
            text_size: f32 = 0
            // TODO:
            //text_size := root.display_string_runs.dim.x
            root.fixed_size[axis] = padding + text_size
    }

    for child := root.first; child != nil; child = child.next {
        calc_sizes_standalone__in_place_rec(child, axis)
    }
}

@(private)
calc_sizes_upwards_dependent__in_place_rec :: proc(root: ^Box, axis: Axis) {
    #partial switch root.pref_size[axis].kind {
        case .PercentOfParent:
            fixed_parent: ^Box = nil
            for p := root.parent; p != nil; p = p.parent {
                if .FixedWidth in p.flags ||
                  p.pref_size[axis].kind == .Pixels ||
                  p.pref_size[axis].kind == .TextContent ||
                  p.pref_size[axis].kind == .PercentOfParent {
                    fixed_parent = p
                    break
                }
            }

            size := fixed_parent.fixed_size[axis] * root.pref_size[axis].value

            root.fixed_size[axis] = size
    }

    for child := root.first; child != nil; child = child.next {
        calc_sizes_upwards_dependent__in_place_rec(child, axis)
    }
}

@(private)
calc_sizes_downwards_dependent__in_place_rec :: proc(root: ^Box, axis: Axis) {
    for child := root.first; child != nil; child = child.next {
        calc_sizes_downwards_dependent__in_place_rec(child, axis)
    }

    #partial switch root.pref_size[axis].kind {
        case .ChildrenSum:
            sum: f32 = 0
            for child := root.first; child != nil; child = child.next {
                if (axis == .X && .FloatingX not_in child.flags) || (axis == .Y && .FloatingY not_in child.flags) {
                    if axis == root.layout_axis {
                        sum += child.fixed_size[axis]
                    } else {
                        sum = max(sum, child.fixed_size[axis])
                    }
                }
            }

            root.fixed_size[axis] = sum
    }
}

@(private)
layout_enforce_constraints__in_place_rec :: proc(root: ^Box, axis: Axis) {
    //Temp scratch = scratch_begin(0, 0)

    // NOTE(rjf): The "layout axis" is the direction in which children
    // of some node are intended to be laid out.

    //- rjf: fixup children sizes (if we're solving along the *non-layout* axis)
    if (axis != root.layout_axis && .AllowOverflowX not_in root.flags) {
        allowed_size := root.fixed_size[axis]

        for child := root.first; child != nil; child = child.next {
            if .FloatingX not_in child.flags {
                child_size := child.fixed_size[axis]
                violation := child_size - allowed_size
                max_fixup := child_size
                fixup := clamp(0, violation, max_fixup)
                if fixup > 0 {
                    child.fixed_size[axis] -= fixup
                }
            }
        }

    }

    //- rjf: fixup children sizes (in the direction of the layout axis)
    if axis == root.layout_axis && .AllowOverflowX not_in root.flags {
        // rjf: figure out total allowed size & total size
        total_allowed_size := root.fixed_size[axis]
        total_size: f32 = 0
        total_weighted_size: f32 = 0
        for child := root.first; child != nil; child = child.next {
            if .FloatingX not_in child.flags {
                total_size += child.fixed_size[axis]
                total_weighted_size += child.fixed_size[axis] * (1-child.pref_size[axis].strictness)
            }
        }

        // rjf: if we have a violation, we need to subtract some amount from all children
        violation := total_size - total_allowed_size
        if (violation > 0) {
            // rjf: figure out how much we can take in totality
            child_fixup_sum: f32 = 0
            child_fixups := make([]f32, root.child_count, context.temp_allocator)
            {
                child_idx: u64 = 0
                for child := root.first; child != nil; child = child.next {
                    if .FloatingX not_in child.flags {
                        fixup_size_this_child := child.fixed_size[axis] * (1-child.pref_size[axis].strictness)
                        fixup_size_this_child = max(0, fixup_size_this_child)
                        child_fixups[child_idx] = fixup_size_this_child
                        child_fixup_sum += fixup_size_this_child
                    }
                    child_idx += 1
                }
            }

            // rjf: fixup child sizes
            {
                child_idx: u64 = 0
                for child := root.first; child != nil; child = child.next {
                    if .FloatingX not_in child.flags {
                        fixup_pct := (violation / total_weighted_size)
                        fixup_pct = clamp(0, fixup_pct, 1)
                        child.fixed_size[axis] -= child_fixups[child_idx] * fixup_pct
                    }
                    child_idx += 1 
                }
            }
        }
    }

    //- rjf: fixup upwards-relative sizes
    if .AllowOverflowX in root.flags {
        for child := root.first; child != nil; child = child.next {
            if child.pref_size[axis].kind == .PercentOfParent {
                child.fixed_size[axis] = root.fixed_size[axis] * child.pref_size[axis].value
            }
        }
    }

    //- rjf: recurse
    for child := root.first; child != nil; child = child.next {
        layout_enforce_constraints__in_place_rec(child, axis)
    }

    //scratch_end(scratch)
}

@(private)
layout_position__in_place_rec :: proc(root: ^Box, axis: Axis) {
    layout_position: f32 = 0

    bounds: f32 = 0
    for child := root.first; child != nil; child = child.next {
        original_position := min(child.rect.p0[axis], child.rect.p1[axis])

        if (axis == .X && .FloatingX not_in child.flags) || (axis == .Y && .FloatingY not_in child.flags) {
            child.fixed_position[axis] = layout_position
            if root.layout_axis == axis {
                layout_position += child.fixed_size[axis]
                bounds += child.fixed_size[axis]
            } else {
                bounds = max(bounds, child.fixed_size[axis])
            }
        }

        // TODO: animation stuff
        //if true
        //{
        //}
        //else
        {
            child.rect.p0[axis] = root.rect.p0[axis] + child.fixed_position[axis]/* - !(child.flags&(UI_BoxFlag_SkipViewOffX<<axis)) * root.view_off[axis]*/
        }
        child.rect.p1[axis] = child.rect.p0[axis] + child.fixed_size[axis]
        child.rect.p0.x = math.floor(child.rect.p0.x)
        child.rect.p0.y = math.floor(child.rect.p0.y)
        child.rect.p1.x = math.floor(child.rect.p1.x)
        child.rect.p1.y = math.floor(child.rect.p1.y)

        new_position := min(child.rect.p0[axis], child.rect.p1[axis])

        child.position_delta[axis] = new_position - original_position
    }

    // TODO: idk
    //{
    //    root.view_bounds[axis] = bounds
    //}

    for child := root.first; child != nil; child = child.next {
        layout_position__in_place_rec(child, axis)
    }
}

@(private)
layout_root :: proc(root: ^Box, axis: Axis) {
    calc_sizes_standalone__in_place_rec(root, axis)
    calc_sizes_upwards_dependent__in_place_rec(root, axis)
    calc_sizes_downwards_dependent__in_place_rec(root, axis)
    layout_enforce_constraints__in_place_rec(root, axis)
    layout_position__in_place_rec(root, axis)
}

@(private = "file")
init_nil_stacks :: proc() {
    ui_state.parent_nil_stack_top.v = nil
    ui_state.layout_axis_nil_stack_top.v = .X
    ui_state.fixed_x_nil_stack_top.v = 0
    ui_state.fixed_y_nil_stack_top.v = 0
    ui_state.fixed_width_nil_stack_top.v = 0
    ui_state.fixed_height_nil_stack_top.v = 0
    ui_state.pref_width_nil_stack_top.v = ui_px(250, 1)
    ui_state.pref_height_nil_stack_top.v = ui_px(30, 1)
    ui_state.flags_nil_stack_top.v = {}
    ui_state.background_color_nil_stack_top.v = {1, 0, 1, 1}
    ui_state.text_color_nil_stack_top.v = {1, 0, 1, 1}
    ui_state.border_color_nil_stack_top.v = {1, 0, 1, 1}
    ui_state.border_thickness_nil_stack_top.v = 0
    ui_state.border_smoothness_nil_stack_top.v = 0
    ui_state.border_radius_nil_stack_top.v = 0
}

@(private = "file")
init_stacks :: proc() {
    ui_state.parent_stack.top = &ui_state.parent_nil_stack_top
    ui_state.parent_stack.free = nil
    ui_state.parent_stack.auto_pop = false

    ui_state.layout_axis_stack.top = &ui_state.layout_axis_nil_stack_top
    ui_state.layout_axis_stack.free = nil
    ui_state.layout_axis_stack.auto_pop = false

    ui_state.fixed_x_stack.top = &ui_state.fixed_x_nil_stack_top
    ui_state.fixed_x_stack.free = nil
    ui_state.fixed_x_stack.auto_pop = false

    ui_state.fixed_y_stack.top = &ui_state.fixed_y_nil_stack_top
    ui_state.fixed_y_stack.free = nil
    ui_state.fixed_y_stack.auto_pop = false

    ui_state.fixed_width_stack.top = &ui_state.fixed_width_nil_stack_top
    ui_state.fixed_width_stack.free = nil
    ui_state.fixed_width_stack.auto_pop = false

    ui_state.fixed_height_stack.top = &ui_state.fixed_height_nil_stack_top
    ui_state.fixed_height_stack.free = nil
    ui_state.fixed_height_stack.auto_pop = false

    ui_state.pref_width_stack.top = &ui_state.pref_width_nil_stack_top
    ui_state.pref_width_stack.free = nil
    ui_state.pref_width_stack.auto_pop = false

    ui_state.pref_height_stack.top = &ui_state.pref_height_nil_stack_top
    ui_state.pref_height_stack.free = nil
    ui_state.pref_height_stack.auto_pop = false

    ui_state.flags_stack.top = &ui_state.flags_nil_stack_top
    ui_state.flags_stack.free = nil
    ui_state.flags_stack.auto_pop = false

    ui_state.background_color_stack.top = &ui_state.background_color_nil_stack_top
    ui_state.background_color_stack.free = nil
    ui_state.background_color_stack.auto_pop = false

    ui_state.text_color_stack.top = &ui_state.text_color_nil_stack_top
    ui_state.text_color_stack.free = nil
    ui_state.text_color_stack.auto_pop = false

    ui_state.border_color_stack.top = &ui_state.border_color_nil_stack_top
    ui_state.border_color_stack.free = nil
    ui_state.border_color_stack.auto_pop = false

    ui_state.border_thickness_stack.top = &ui_state.border_thickness_nil_stack_top
    ui_state.border_thickness_stack.free = nil
    ui_state.border_thickness_stack.auto_pop = false

    ui_state.border_smoothness_stack.top = &ui_state.border_smoothness_nil_stack_top
    ui_state.border_smoothness_stack.free = nil
    ui_state.border_smoothness_stack.auto_pop = false

    ui_state.border_radius_stack.top = &ui_state.border_radius_nil_stack_top
    ui_state.border_radius_stack.free = nil
    ui_state.border_radius_stack.auto_pop = false
}

@(private)
set_next_layout_axis :: proc(axis: Axis) {
    stack_set(&ui_state.layout_axis_stack, Axis, axis)
}

@(private)
push_parent :: proc(parent: ^Box) {
    stack_push(&ui_state.parent_stack, ^Box, parent)
}

@(private)
pop_parent :: proc() {
    stack_pop(&ui_state.parent_stack, &ui_state.parent_nil_stack_top)
}

@(private)
make_box_id :: proc(id: Id, caller := #caller_location) -> (hashed_id: Id) {
    line := caller.line
    line_bytes := mem.byte_slice(&line, size_of(line))
    id := id
    id_bytes := mem.byte_slice(&id, size_of(id))
    hashed_id = hash.fnv32a(id_bytes)
    hashed_id = hash.fnv32a(transmute([]byte)caller.file_path, hashed_id)
    hashed_id = hash.fnv32a(line_bytes, hashed_id)
    
    return
}

@(private)
top_parent :: proc() -> ^Box {
    return ui_state.parent_stack.top.v
}
