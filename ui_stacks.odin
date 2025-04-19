#+private
package zephr

ParentNode :: struct {
    next: ^ParentNode,
    v: ^Box,
}

LayoutAxisNode :: struct {
    next: ^LayoutAxisNode,
    v: Axis,
}

FixedXNode :: struct {
    next: ^FixedXNode,
    v: f32,
}

FixedYNode :: struct {
    next: ^FixedYNode,
    v: f32,
}

FixedWidthNode :: struct {
    next: ^FixedWidthNode,
    v: f32,
}

FixedHeightNode :: struct {
    next: ^FixedHeightNode,
    v: f32,
}

PrefWidthNode :: struct {
    next: ^PrefWidthNode,
    v: Size,
}

PrefHeightNode :: struct {
    next: ^PrefHeightNode,
    v: Size,
}

BackgroundColorNode :: struct {
    next: ^BackgroundColorNode,
    v: Color,
}

TextColorNode :: struct {
    next: ^TextColorNode,
    v: Color,
}

BorderColorNode :: struct {
    next: ^BorderColorNode,
    v: Color,
}

BorderThicknessNode :: struct {
    next: ^BorderThicknessNode,
    v: f32,
}

BorderSmoothnessNode :: struct {
    next: ^BorderSmoothnessNode,
    v: f32,
}

BorderRadiusNode :: struct {
    next: ^BorderRadiusNode,
    v: f32,
}

FlagsNode :: struct {
    next: ^FlagsNode,
    v: Flags,
}

Stack :: struct($T: typeid) {
    top: ^T,
    free: ^T,
    auto_pop: bool,
}

stack_set :: proc(stack: ^Stack($S), $T: typeid, new_value: T) {
    node := stack.free
    if node == nil {
        node = new(S, build_allocator())
    } else {
        linked_list_stack_pop(&stack.free)
    }
    old_value := stack.top.v
    node.v = new_value
    linked_list_stack_push(&stack.top, node)
    stack.auto_pop = true

    //return old_value
}

// Double pointer because we can't change the address if we shadow the pointer
linked_list_stack_push :: proc "contextless" (f: ^^$S, n: ^S) {
    n.next = f^
    f^ = n
}

// Double pointer because we can't change the address if we shadow the pointer
linked_list_stack_pop :: proc "contextless" (f: ^^$S) {
    f^ = f^.next
}

double_linked_list_insert :: proc "contextless" (f, l, p, n: ^^$T) {
    if f^ == nil {
        f^ = n^
        l^ = n^
        n^.next = nil
        n^.prev = nil
    } else if p^ == nil {
        n^.next = f^
        f^.prev = n^
        f^ = n^
        n^.prev = nil
    } else if p^ == l^ {
        l^.next = n^
        n^.prev = l^
        l^ = n^
        n^.next = nil
    } else {
        if p^ != nil && p^.next == nil {
            // do nothing
        } else {
            p^.next.prev = n^
        }
        n^.next = p^.next
        p^.next = n^
        n^.prev = p^
        //(((!CheckNil(nil,p) && CheckNil(nil,p.next)) ? (0) : (p.next.prev = (n))), (n.next = p.next), (p.next = (n)), (n.prev = (p)))
    }
}

double_linked_list_push_back :: proc "contextless" (f, l, n: ^^$T) {
    double_linked_list_insert(f, l, l, n)
}

double_linked_list_push_front :: proc "contextless" (f, l, n: ^^$T) {
    double_linked_list_insert(l, f, f, n)
}

stack_push :: proc(stack: ^Stack($S), $T: typeid, new_value: T) {
    node := stack.free
    if node == nil {
        node = new(S, build_allocator())
    } else {
        linked_list_stack_pop(&stack.free)
    }
    old_value := stack.top.v
    node.v = new_value

    linked_list_stack_push(&stack.top, node)

    if node.next == stack.top {
        // TODO:
        // bottom val
    }
    stack.auto_pop = false

    //return old_value
}

stack_pop :: proc "contextless" (stack: ^Stack($S), nil_stack_top: ^S) {
    popped := stack.top
    if popped != nil_stack_top {
        linked_list_stack_pop(&stack.top)
        linked_list_stack_push(&stack.free, popped)
        stack.auto_pop = false
    }

    //return popped.v
}


auto_pop_stacks :: proc() {
    if ui_state.parent_stack.auto_pop {
        pop_parent()
        ui_state.parent_stack.auto_pop = false
    }
    if ui_state.layout_axis_stack.auto_pop {
        ui_pop_layout_axis()
        ui_state.layout_axis_stack.auto_pop = false
    }
    if ui_state.fixed_x_stack.auto_pop {
        ui_pop_fixed_x()
        ui_state.fixed_x_stack.auto_pop = false
    }
    if ui_state.fixed_y_stack.auto_pop {
        ui_pop_fixed_y()
        ui_state.fixed_y_stack.auto_pop = false
    }
    if ui_state.fixed_width_stack.auto_pop {
        ui_pop_fixed_width()
        ui_state.fixed_width_stack.auto_pop = false
    }
    if ui_state.fixed_height_stack.auto_pop {
        ui_pop_fixed_height()
        ui_state.fixed_height_stack.auto_pop = false
    }
    if ui_state.pref_width_stack.auto_pop {
        ui_pop_pref_width()
        ui_state.pref_width_stack.auto_pop = false
    }
    if ui_state.pref_height_stack.auto_pop {
        ui_pop_pref_height()
        ui_state.pref_height_stack.auto_pop = false
    }
    if ui_state.flags_stack.auto_pop {
        ui_pop_flags()
        ui_state.flags_stack.auto_pop = false
    }
    if ui_state.background_color_stack.auto_pop {
        ui_pop_background_color()
        ui_state.background_color_stack.auto_pop = false
    }
    if ui_state.text_color_stack.auto_pop {
        ui_pop_text_color()
        ui_state.text_color_stack.auto_pop = false
    }
    if ui_state.border_color_stack.auto_pop {
        ui_pop_border_color()
        ui_state.border_color_stack.auto_pop = false
    }
    if ui_state.border_thickness_stack.auto_pop {
        ui_pop_border_thickness()
        ui_state.border_thickness_stack.auto_pop = false
    }
    if ui_state.border_smoothness_stack.auto_pop {
        ui_pop_border_smoothness()
        ui_state.border_smoothness_stack.auto_pop = false
    }
    if ui_state.border_radius_stack.auto_pop {
        ui_pop_border_radius()
        ui_state.border_radius_stack.auto_pop = false
    }
    // TODO:
}
