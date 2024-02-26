package zephr

import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:slice"
import "core:strings"

import gl "vendor:OpenGL"

@(private = "file")
mesh_shader: ^Shader
@(private = "file")
gizmo_shader: ^Shader
@(private = "file")
missing_texture: TextureId
@(private = "file")
editor_camera: Camera

//@(private = "file")
//sort_by_transparency :: proc(i, j: Node) -> bool {
//    sort :: proc(node: Node) -> bool {
//        for mesh in node.meshes {
//            if mesh.material.alpha_mode == .blend {
//                return false
//            }
//        }
//
//        for child in node.children {
//            return sort(child)
//        }
//
//        return true
//    }
//
//    return sort(i)
//}

init_renderer :: proc() {
    context.logger = logger

    editor_camera = DEFAULT_CAMERA

    l_mesh_shader, success1 := create_shader(relative_path("shaders/mesh.vert"), relative_path("shaders/mesh.frag"))
    l_gizmo_shader, success2 := create_shader(relative_path("shaders/gizmo.vert"), relative_path("shaders/gizmo.frag"))

    mesh_shader = l_mesh_shader
    gizmo_shader = l_gizmo_shader

    if (!success1) {
        log.error("Failed to load mesh shader")
    }
    if (!success2) {
        log.error("Failed to load gizmo shader")
    }

    missing_texture = load_texture(
        "res/textures/missing_texture.png",
        true,
        false,
        gl.REPEAT,
        gl.REPEAT,
        gl.NEAREST,
        gl.NEAREST,
    )

    max_tex_size: i32
    max_tex_arr_size: i32
    gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &max_tex_size)
    gl.GetIntegerv(gl.MAX_ARRAY_TEXTURE_LAYERS, &max_tex_arr_size)

    log.debugf("Max texture size: %d", max_tex_size)
    log.debugf("Max texture layers: %d", max_tex_arr_size)
}

// MUST be called every frame
draw :: proc(models: []Model, lights: []Light) {
    view_mat := m.mat4LookAt(editor_camera.position, editor_camera.position + editor_camera.front, editor_camera.up)
    projection := m.mat4Perspective(
        m.radians(editor_camera.fov),
        zephr_ctx.window.size.x / zephr_ctx.window.size.y,
        0.01,
        200,
    )

    use_shader(gizmo_shader)
    set_mat4f(gizmo_shader, "view", view_mat)
    set_mat4f(gizmo_shader, "projection", projection)

    use_shader(mesh_shader)
    set_vec3fv(mesh_shader, "viewPos", editor_camera.position)
    set_mat4f(mesh_shader, "view", view_mat)
    set_mat4f(mesh_shader, "projection", projection)
    set_bool(mesh_shader, "useTextures", false)

    // sort meshes by transparency for proper alpha blending
    // TODO: also sort by distance for transparent meshes
    // TODO: also sort ALL models first
    if len(models) > 0 {
        // TODO: don't sort nodes that don't have meshes (camera nodes, etc..)
        //slice.sort_by(models[0].nodes[:], sort_by_transparency)
        //slice.sort_by(game.models[0].nodes[:], sort_by_distance)
    }

    draw_lights(lights)

    models := models

    for model in &models {
        draw_model(&model)
    }
}

@(private = "file")
draw_model :: proc(model: ^Model) {
    use_shader(mesh_shader)
    model_mat := m.identity(m.mat4)
    model_mat = m.mat4Scale(model.scale) * model_mat
    model_mat = m.mat4Rotate(model.rotation, m.radians(model.rotation_angle_d)) * model_mat
    model_mat = m.mat4Translate(model.position) * model_mat

    for node in &model.nodes {
        draw_node(&node, model_mat, &model.animations, &model.materials)
    }
}

@(private = "file")
draw_node :: proc(node: ^Node, parent_transform: m.mat4, animations: ^[]Animation, materials: ^map[uintptr]Material) {
    context.logger = logger

    transform := parent_transform

    for anim in animations {
        if anim.timer.running {
            advance_animation(anim, node, &anim.timer, anim.max_time)
        }
    }

    if node.has_transform {
        transform *= node.transform
    } else {
        t := m.identity(m.mat4)
        t = m.mat4Scale(node.scale) * t
        t = m.mat4FromQuat(node.rotation) * t
        t = m.mat4Translate(node.translation) * t
        transform *= t
    }

    for mesh in node.meshes {
        draw_mesh(mesh, transform, materials)
    }

    for child in &node.children {
        draw_node(&child, transform, animations, materials)
    }
}

@(private = "file")
draw_mesh :: proc(mesh: Mesh, transform: m.mat4, materials: ^map[uintptr]Material) {
    context.logger = logger

    if mesh.morph_targets_tex != 0 {
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D_ARRAY, mesh.morph_targets_tex)
        set_bool(mesh_shader, "useMorphing", true)
        set_int(mesh_shader, "morphTargetNormalsOffset", cast(i32)mesh.morph_normals_offset)
        set_int(mesh_shader, "morphTargetTangentsOffset", cast(i32)mesh.morph_tangents_offset)
        // We make the assumption that normals and tangents will never be morphed if positions aren't morphed
        // There's a chance of breaking if someone decides to only morph normals or tangents but idc.
        set_bool(mesh_shader, "hasMorphTargetNormals", mesh.morph_normals_offset != 0)
        set_bool(mesh_shader, "hasMorphTargetTangents", mesh.morph_tangents_offset != 0)
        set_int(mesh_shader, "morphTargetsCount", cast(i32)len(mesh.weights))
        set_float_array(mesh_shader, "morphTargetWeights", mesh.weights)
    } else {
        set_bool(mesh_shader, "useMorphing", false)
        set_bool(mesh_shader, "hasMorphTargetNormals", false)
        set_bool(mesh_shader, "hasMorphTargetTangents", false)
    }

    material := &materials[mesh.material_id]

    if material.double_sided {
        gl.Disable(gl.CULL_FACE)
    } else {
        gl.Enable(gl.CULL_FACE)
    }

    if material.alpha_mode == .blend {
        gl.Enable(gl.BLEND)
        gl.BlendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
        gl.BlendEquation(gl.FUNC_ADD)
    } else {
        gl.Disable(gl.BLEND)
    }

    set_mat4f(mesh_shader, "model", transform)

    set_bool(mesh_shader, "useTextures", len(material.textures) != 0)
    set_vec4fv(mesh_shader, "material.diffuse", material.diffuse)
    set_vec3fv(mesh_shader, "material.specular", material.specular)
    set_vec3fv(mesh_shader, "material.emissive", material.emissive)
    set_float(mesh_shader, "material.shininess", material.shininess)
    set_float(mesh_shader, "material.metallic", material.metallic)
    set_float(mesh_shader, "material.roughness", material.roughness)
    set_bool(mesh_shader, "doubleSided", material.double_sided)
    set_bool(mesh_shader, "unlit", material.unlit)
    set_float(mesh_shader, "alphaCutoff", material.alpha_cutoff)
    set_int(mesh_shader, "alphaMode", cast(i32)material.alpha_mode)

    set_bool(mesh_shader, "hasDiffuseTexture", false)
    set_bool(mesh_shader, "hasNormalTexture", false)
    set_bool(mesh_shader, "hasEmissiveTexture", false)
    set_bool(mesh_shader, "hasMetallicRoughnessTexture", false)

    set_int(mesh_shader, "material.texture_diffuse", 1)
    set_int(mesh_shader, "material.texture_normal", 2)
    set_int(mesh_shader, "material.texture_metallic_roughness", 3)
    set_int(mesh_shader, "material.texture_emissive", 4)

    for texture, i in material.textures {
        idx := i + 1
        texture_id := texture.id != 0 ? texture.id : missing_texture

        #partial switch texture.type {
            case .DIFFUSE:
                gl.ActiveTexture(gl.TEXTURE1)
                set_bool(mesh_shader, "hasDiffuseTexture", true)
            case .NORMAL:
                gl.ActiveTexture(gl.TEXTURE2)
                set_bool(mesh_shader, "hasNormalTexture", true)
            case .METALLIC_ROUGHNESS:
                gl.ActiveTexture(gl.TEXTURE3)
                set_bool(mesh_shader, "hasMetallicRoughnessTexture", true)
            case .EMISSIVE:
                gl.ActiveTexture(gl.TEXTURE4)
                set_bool(mesh_shader, "hasEmissiveTexture", true)
        }

        gl.BindTexture(gl.TEXTURE_2D, texture_id)
    }

    gl.BindVertexArray(mesh.vao)
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)

    set_bool(mesh_shader, "useTextures", false)

    gl.BindVertexArray(0)
}

@(private = "file")
draw_lights :: proc(lights: []Light) {
    context.logger = logger

    point_light_idx := 0

    for light in lights {
        if light.type == .DIRECTIONAL {
            use_shader(mesh_shader)
            set_vec3fv(mesh_shader, "dirLight.direction", light.direction)
            set_vec3fv(mesh_shader, "dirLight.ambient", light.ambient)
            set_vec3fv(mesh_shader, "dirLight.diffuse", light.diffuse)
            set_vec3fv(mesh_shader, "dirLight.specular", light.specular)

            if true {
                use_shader(gizmo_shader)
                set_vec3fv(gizmo_shader, "color", m.vec3{0.0, 0.0, 0.0})
                model := m.identity(m.mat4)
                model = m.mat4Translate(light.position) * model
                set_mat4f(gizmo_shader, "model", model)

                gl.BindVertexArray(light.vao)
                gl.DrawElements(gl.LINES, 2, gl.UNSIGNED_INT, nil)
            }
        } else if light.type == .POINT {
            use_shader(mesh_shader)
            pos_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].position", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, pos_c_str, light.position)

            constant_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].constant", point_light_idx),
                context.temp_allocator,
            )
            set_float(mesh_shader, constant_c_str, light.point.constant)
            linear_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].linear", point_light_idx),
                context.temp_allocator,
            )
            set_float(mesh_shader, linear_c_str, light.point.linear)
            quadratic_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].quadratic", point_light_idx),
                context.temp_allocator,
            )
            set_float(mesh_shader, quadratic_c_str, light.point.quadratic)

            ambient_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].ambient", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, ambient_c_str, light.ambient)
            diffuse_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].diffuse", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, diffuse_c_str, light.diffuse)
            specular_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].specular", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, specular_c_str, light.specular)

            if true {
                use_shader(gizmo_shader)
                set_vec3fv(gizmo_shader, "color", light.diffuse)
                model := m.identity(m.mat4)
                model = m.mat4Translate(light.position) * model
                model = m.mat4Scale(m.vec3{0.3, 0.3, 0.3}) * model
                set_mat4f(gizmo_shader, "model", model)

                gl.BindVertexArray(light.vao)
                gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
            }

            point_light_idx += 1
        }
    }
}

// TODO: is there a better place to put this?
get_editor_camera :: proc() -> ^Camera {
    return &editor_camera
}
