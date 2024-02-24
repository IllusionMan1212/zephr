package zephr

import "core:log"
import "core:math"
import m "core:math/linalg/glsl"
import "core:time"

import "vendor:cgltf"

@(private)
AnimationTrack :: struct {
    node_id:       uintptr,
    property:      cgltf.animation_path_type,
    time:          []f32,
    data:          []f32,
    interpolation: cgltf.interpolation_type,
}

Animation :: struct {
    name:     string,
    tracks:   []AnimationTrack,
    max_time: f32,
    timer:    time.Stopwatch,
}


@(private = "file")
interpolate_rotation :: proc(track: AnimationTrack, tc, max_time: f32) -> m.quat {
    n := len(track.time)

    if n == 1 {
        return cast(m.quat)quaternion(x = track.data[0], y = track.data[1], z = track.data[2], w = track.data[3])
    }

    tk_prev: f32 = track.time[0]
    tk_next: f32 = track.time[n - 1]

    tk_prev_idx := 0

    for i in 0 ..< n {
        if track.time[i] < tc {
            tk_prev = track.time[i]
            tk_prev_idx = i
        }
        if track.time[i] > tc {
            tk_next = track.time[i]
            break
        }
    }

    td := tk_next - tk_prev
    t := (tc - tk_prev) / td

    prev_val := cast(m.quat)quaternion(
        x = track.data[tk_prev_idx * 4],
        y = track.data[tk_prev_idx * 4 + 1],
        z = track.data[tk_prev_idx * 4 + 2],
        w = track.data[tk_prev_idx * 4 + 3],
    )
    next_val := cast(m.quat)quaternion(
        x = track.data[tk_prev_idx * 4 + 4],
        y = track.data[tk_prev_idx * 4 + 5],
        z = track.data[tk_prev_idx * 4 + 6],
        w = track.data[tk_prev_idx * 4 + 7],
    )

    rot := cast(m.quat)quaternion(x = 0, y = 0, z = 0, w = 1)

    switch track.interpolation {
        case .linear:
            rot = m.slerp(prev_val, next_val, t)
        case .step:
            rot = prev_val
        case .cubic_spline:
            stride := 12
            prev_val = quaternion(
                x = track.data[tk_prev_idx * stride + 4],
                y = track.data[tk_prev_idx * stride + 5],
                z = track.data[tk_prev_idx * stride + 6],
                w = track.data[tk_prev_idx * stride + 7],
            )
            bk := quaternion(
                x = track.data[tk_prev_idx * stride + 8],
                y = track.data[tk_prev_idx * stride + 9],
                z = track.data[tk_prev_idx * stride + 10],
                w = track.data[tk_prev_idx * stride + 11],
            )

            ak1 := quaternion(
                x = track.data[tk_prev_idx * stride + 12],
                y = track.data[tk_prev_idx * stride + 13],
                z = track.data[tk_prev_idx * stride + 14],
                w = track.data[tk_prev_idx * stride + 15],
            )
            next_val = quaternion(
                x = track.data[tk_prev_idx * stride + 16],
                y = track.data[tk_prev_idx * stride + 17],
                z = track.data[tk_prev_idx * stride + 18],
                w = track.data[tk_prev_idx * stride + 19],
            )

            t1 := (2 * m.pow(t, 3) - 3 * m.pow(t, 2) + 1)
            p1 := quaternion(x = prev_val.x * t1, y = prev_val.y * t1, z = prev_val.z * t1, w = prev_val.w * t1)

            t2 := td * (m.pow(t, 3) - 2 * m.pow(t, 2) + t)
            p2 := quaternion(x = bk.x * t2, y = bk.y * t2, z = bk.z * t2, w = bk.w * t2)

            t3 := (-2 * m.pow(t, 3) + 3 * m.pow(t, 2))
            p3 := quaternion(x = next_val.x * t3, y = next_val.y * t3, z = next_val.z * t3, w = next_val.w * t3)

            t4 := td * (m.pow(t, 3) - m.pow(t, 2))
            p4 := quaternion(x = ak1.x * t4, y = ak1.y * t4, z = ak1.z * t4, w = ak1.w * t4)

            rot = m.normalize(cast(m.quat)(p1 + p2 + p3 + p4))
    }

    return rot
}

@(private = "file")
interpolate_vec3 :: proc(track: AnimationTrack, tc, max_time: f32) -> m.vec3 {
    n := len(track.time)

    if n == 1 {
        return m.vec3{track.data[0], track.data[1], track.data[2]}
    }

    tk_prev: f32 = track.time[0]
    tk_next: f32 = track.time[n - 1]

    tk_prev_idx := 0

    for i in 0 ..< n {
        if track.time[i] < tc {
            tk_prev = track.time[i]
            tk_prev_idx = i
        }
        if track.time[i] > tc {
            tk_next = track.time[i]
            break
        }
    }

    td := tk_next - tk_prev
    t := (tc - tk_prev) / td

    prev_val := m.vec3{track.data[tk_prev_idx * 3], track.data[tk_prev_idx * 3 + 1], track.data[tk_prev_idx * 3 + 2]}
    next_val := m.vec3 {
        track.data[tk_prev_idx * 3 + 3],
        track.data[tk_prev_idx * 3 + 4],
        track.data[tk_prev_idx * 3 + 5],
    }
    val := m.vec3{0, 0, 0}

    switch track.interpolation {
        case .linear:
            val = m.lerp(prev_val, next_val, t)
        case .step:
            val = prev_val
        case .cubic_spline:
            stride := 9
            prev_val = m.vec3 {
                track.data[tk_prev_idx * stride + 3],
                track.data[tk_prev_idx * stride + 4],
                track.data[tk_prev_idx * stride + 5],
            }
            bk := m.vec3 {
                track.data[tk_prev_idx * stride + 6],
                track.data[tk_prev_idx * stride + 7],
                track.data[tk_prev_idx * stride + 8],
            }

            ak1 := m.vec3 {
                track.data[tk_prev_idx * stride + 9],
                track.data[tk_prev_idx * stride + 10],
                track.data[tk_prev_idx * stride + 11],
            }
            next_val = m.vec3 {
                track.data[tk_prev_idx * stride + 12],
                track.data[tk_prev_idx * stride + 13],
                track.data[tk_prev_idx * stride + 14],
            }

            p1 := (2 * m.pow(t, 3) - 3 * m.pow(t, 2) + 1) * prev_val
            p2 := td * (m.pow(t, 3) - 2 * m.pow(t, 2) + t) * bk
            p3 := (-2 * m.pow(t, 3) + 3 * m.pow(t, 2)) * next_val
            p4 := td * (m.pow(t, 3) - m.pow(t, 2)) * ak1
            val = p1 + p2 + p3 + p4
    }

    return val
}

interpolate_weights :: proc(track: AnimationTrack, tc, max_time: f32, weights_len: int) -> []f32 {
    n := len(track.time)

    if n == 1 {
        return track.data[:weights_len]
    }

    tk_prev: f32 = track.time[0]
    tk_next: f32 = track.time[n - 1]

    tk_prev_idx := 0

    for i in 0 ..< n {
        if track.time[i] < tc {
            tk_prev = track.time[i]
            tk_prev_idx = i
        }
        if track.time[i] > tc {
            tk_next = track.time[i]
            break
        }
    }

    td := tk_next - tk_prev
    t := (tc - tk_prev) / td

    prev_val := track.data[(tk_prev_idx * weights_len):(tk_prev_idx * weights_len) + weights_len]
    next_val := track.data[(tk_prev_idx * weights_len) + weights_len:(tk_prev_idx * weights_len) + (weights_len * 2)]
    // FIXME: this is never cleaned up
    val := make([]f32, weights_len)

    switch track.interpolation {
        case .linear:
            for i in 0 ..< weights_len {
                val[i] = m.lerp(prev_val[i], next_val[i], t)
            }
        case .step:
            val = prev_val
        case .cubic_spline:
                    //odinfmt: disable
        // TODO: Does any of this make any sense. This needs to be tested with a model
        prev_val := track.data[(tk_prev_idx * weights_len) + weights_len:(tk_prev_idx * weights_len) + (weights_len * 2)]
        bk := track.data[(tk_prev_idx * weights_len) + (weights_len * 2):(tk_prev_idx * weights_len) + (weights_len * 3)]

        ak1 := track.data[(tk_prev_idx * weights_len) + (weights_len * 3):(tk_prev_idx * weights_len) + (weights_len * 4)]
        next_val := track.data[(tk_prev_idx * weights_len) + (weights_len * 4):(tk_prev_idx * weights_len) + (weights_len * 5)]

        t1 := (2 * m.pow(t, 3) - 3 * m.pow(t, 2) + 1)
        t2 := td * (m.pow(t, 3) - 2 * m.pow(t, 2) + t)
        t3 := (-2 * m.pow(t, 3) + 3 * m.pow(t, 2))
        t4 := td * (m.pow(t, 3) - m.pow(t, 2))

        val = make([]f32, weights_len)

        for i in 0..<weights_len {
            p1 := (t1 * prev_val[i])
            p2 := (t2 * bk[i])
            p3 := (t3 * next_val[i])
            p4 := (t4 * ak1[i])

            val[i] = p1 + p2 + p3 + p4
        }
        //odinfmt: enable


    }

    return val
}

advance_animation :: proc(anim: Animation, node: ^Node, elapsed_t: ^time.Stopwatch, max_time: f32) -> m.mat4 {
    context.logger = logger

    result := m.identity(m.mat4)

    for track in anim.tracks {
        if track.node_id != node.id {
            continue
        }

        tc := cast(f32)time.duration_seconds(time.stopwatch_duration(elapsed_t^))
        // TODO: if loop_animation {
        tc = math.mod(tc, max_time)
        //}
        tc = clamp(tc, track.time[0], track.time[len(track.time) - 1])

        #partial switch track.property {
            case .translation:
                position := interpolate_vec3(track, tc, max_time)
                node.translation = position
            case .rotation:
                rotation := interpolate_rotation(track, tc, max_time)
                node.rotation = rotation
            case .scale:
                scale := interpolate_vec3(track, tc, max_time)
                node.scale = scale
            case .weights:
                weights := interpolate_weights(track, tc, max_time, len(node.meshes[0].weights))
                for mesh in &node.meshes {
                    mesh.weights = weights
                }
        }
    }

    return result
}

pause_animation :: proc(anim: ^Animation) {
    time.stopwatch_stop(&anim.timer)
}

resume_animation :: proc(anim: ^Animation) {
    time.stopwatch_start(&anim.timer)
}

reset_animation :: proc(anim: ^Animation, model: ^Model) {
    time.stopwatch_reset(&anim.timer)

    reset_node_animation :: proc(anim: ^Animation, node: ^Node) {
        for track in anim.tracks {
            if track.node_id == node.id {
                #partial switch track.property {
                    case .translation:
                        node.translation = m.vec3{track.data[0], track.data[1], track.data[2]}
                    case .rotation:
                        node.rotation = quaternion(
                            x = track.data[0],
                            y = track.data[1],
                            z = track.data[2],
                            w = track.data[3],
                        )
                    case .scale:
                        node.scale = m.vec3{track.data[0], track.data[1], track.data[2]}
                    case .weights:
                        for mesh in &node.meshes {
                            mesh.weights = track.data[:len(mesh.weights)]
                        }
                }
            }
        }

        for child in &node.children {
            reset_node_animation(anim, &child)
        }
    }

    for node in &model.nodes {
        reset_node_animation(anim, &node)
    }
}
