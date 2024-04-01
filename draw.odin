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
missing_texture: TextureId
@(private = "file")
editor_camera: Camera

// FIXME: I think we're doing something wrong when applying the transformation hierarchy
// and that causes the rotations to be "flipped" for entities. But I'm not 100% sure yet tbh

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

    l_mesh_shader, success := create_shader(create_resource_path("shaders/mesh.vert"), create_resource_path("shaders/mesh.frag"))

    mesh_shader = l_mesh_shader

    if (!success) {
        log.error("Failed to load mesh shader")
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

    init_aabb()
}

// MUST be called every frame
draw :: proc(entities: []Entity, lights: []Light, camera: ^Camera) {
    use_shader(mesh_shader)
    set_vec3fv(mesh_shader, "viewPos", camera.position)
    set_mat4f(mesh_shader, "projectionView", camera.proj_mat * camera.view_mat)
    set_bool(mesh_shader, "useTextures", false)

    // sort meshes by transparency for proper alpha blending
    // TODO: also sort by distance for transparent meshes
    // TODO: also sort ALL models first
    if len(entities) > 0 {
        //slice.sort_by(models[0].nodes[:], sort_by_transparency)
        //slice.sort_by(game.models[0].nodes[:], sort_by_distance)
    }

    draw_lights(lights)

    entities := entities

    for entity in &entities {
        model_mat := m.identity(m.mat4)
        model_mat = m.mat4Scale(entity.scale) * model_mat
        model_mat = m.mat4FromQuat(entity.rotation) * model_mat
        model_mat = m.mat4Translate(entity.position) * model_mat

        apply_transform_hierarchy(&entity.model, model_mat)
        draw_model(&entity.model)
        //draw_aabb(entity.model.aabb, entity.model.nodes[0].world_transform)
        //draw_collision_shape()
    }
}

@(private = "file")
apply_transform_hierarchy :: proc(model: ^Model, model_transform: m.mat4) {
    apply_transform :: proc(node: ^Node) {
        node.world_transform = node_local_transform(node)
        if node.parent != nil {
            node.world_transform = node.parent.world_transform * node.world_transform
        }

        for child in node.children {
            apply_transform(child)
        }
    }

    for node in model.nodes {
        node.world_transform = model_transform * node_local_transform(node)
        if node.parent != nil {
            node.world_transform = node.parent.world_transform * node.world_transform
        }

        for child in node.children {
            apply_transform(child)
        }
    }
}

@(private = "file")
draw_model :: proc(model: ^Model) {
    use_shader(mesh_shader)

    if model.active_animation != nil && model.active_animation.timer.running {
        advance_animation(model.active_animation)
    }

    for node in &model.nodes {
        draw_node(node, &model.materials)
    }
}

@(private = "file")
draw_node :: proc(node: ^Node, materials: ^map[uintptr]Material) {
    context.logger = logger

    joint_matrices: []m.mat4
    defer delete(joint_matrices)

    if len(node.joints) != 0 {
        joint_matrices = make([]m.mat4, len(node.joints))
        for joint, i in node.joints {
            j_transform := node_local_transform(joint)
            if joint.parent != nil {
                j_transform = joint.parent.world_transform * j_transform
            }
            // TODO: skeleton node ??

            joint_matrices[i] = j_transform * node.inverse_bind_matrices[i]
        }
    }

    for mesh in node.meshes {
        draw_mesh(mesh, node.world_transform, materials, joint_matrices)
        //draw_aabb(mesh.aabb, node.world_transform)
    }

    for child in node.children {
        draw_node(child, materials)
    }
}

@(private = "file", disabled = RELEASE_BUILD)
draw_aabb :: proc(aabb: AABB, transform: m.mat4) {
    set_mat4f(mesh_shader, "model", transform)
    set_bool(mesh_shader, "useSkinning", false)

    vertices := []m.vec3{
        aabb.min,
        {aabb.max.x, aabb.min.y, aabb.min.z},
        {aabb.max.x, aabb.max.y, aabb.min.z},
        {aabb.min.x, aabb.max.y, aabb.min.z},
        {aabb.min.x, aabb.min.y, aabb.max.z},
        {aabb.max.x, aabb.min.y, aabb.max.z},
        aabb.max,
        {aabb.min.x, aabb.max.y, aabb.max.z},
    }

    gl.LineWidth(4)
    gl.BindVertexArray(aabb_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, aabb_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(m.vec3) * len(vertices), raw_data(vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
    gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, nil)

    gl.BindVertexArray(0)
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
    gl.LineWidth(1)
}

@(private = "file", disabled = RELEASE_BUILD)
draw_collision_shape :: proc() {
    // TODO:
}

@(private = "file")
draw_mesh :: proc(mesh: Mesh, transform: m.mat4, materials: ^map[uintptr]Material, joint_matrices: []m.mat4) {
    context.logger = logger

    set_int(mesh_shader, "morphTargets", 0)
    set_int(mesh_shader, "morphTargetWeights", 1)
    set_int(mesh_shader, "jointMatrices", 2)
    set_int(mesh_shader, "material.texture_diffuse", 3)
    set_int(mesh_shader, "material.texture_normal", 4)
    set_int(mesh_shader, "material.texture_metallic_roughness", 5)
    set_int(mesh_shader, "material.texture_emissive", 6)
    // TODO: group all uniforms into a UBO so that we don't have to set a lot of them every frame.
    // No idea if this will have any impact on performance.
    // All these uniforms are baaaaad for performance. Especially conditionals
    // What I see a lot of projects do is set the conditionals as ifdefs in the shader and basically modifying the
    // shader during runtime afaik.
    if mesh.morph_targets_tex != 0 {
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D_ARRAY, mesh.morph_targets_tex)
        set_bool(mesh_shader, "useMorphing", true)
        set_int(mesh_shader, "morphTargetNormalsOffset", cast(i32)mesh.morph_normals_offset)
        set_int(mesh_shader, "morphTargetTangentsOffset", cast(i32)mesh.morph_tangents_offset)
        set_int(mesh_shader, "morphTargetsCount", cast(i32)len(mesh.weights))
        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_BUFFER, mesh.morph_weights_tex)
        gl.BindBuffer(gl.ARRAY_BUFFER, mesh.morph_weights_buf)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(mesh.weights) * size_of(f32), raw_data(mesh.weights))
    } else {
        set_bool(mesh_shader, "useMorphing", false)
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
    if len(joint_matrices) != 0 {
        set_bool(mesh_shader, "useSkinning", true)
        gl.ActiveTexture(gl.TEXTURE2)
        gl.BindTexture(gl.TEXTURE_BUFFER, mesh.joint_matrices_tex)
        gl.BindBuffer(gl.ARRAY_BUFFER, mesh.joint_matrices_buf)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(m.mat4) * len(joint_matrices), raw_data(joint_matrices))
    } else {
        set_bool(mesh_shader, "useSkinning", false)
    }

    set_bool(mesh_shader, "hasDiffuseTexture", false)
    set_bool(mesh_shader, "hasNormalTexture", false)
    set_bool(mesh_shader, "hasEmissiveTexture", false)
    set_bool(mesh_shader, "hasMetallicRoughnessTexture", false)

    for texture in material.textures {
        texture_id := texture.id != 0 ? texture.id : missing_texture

        #partial switch texture.type {
            case .DIFFUSE:
                gl.ActiveTexture(gl.TEXTURE3)
                set_bool(mesh_shader, "hasDiffuseTexture", true)
            case .NORMAL:
                gl.ActiveTexture(gl.TEXTURE4)
                set_bool(mesh_shader, "hasNormalTexture", true)
            case .METALLIC_ROUGHNESS:
                gl.ActiveTexture(gl.TEXTURE5)
                set_bool(mesh_shader, "hasMetallicRoughnessTexture", true)
            case .EMISSIVE:
                gl.ActiveTexture(gl.TEXTURE6)
                set_bool(mesh_shader, "hasEmissiveTexture", true)
        }

        gl.BindTexture(gl.TEXTURE_2D, texture_id)
    }

    gl.BindVertexArray(mesh.vao)
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)

    set_bool(mesh_shader, "useTextures", false)

    gl.BindVertexArray(0)
}

draw_lights :: proc(lights: []Light) {
    context.logger = logger

    point_light_idx := 0

    for light in lights {
        if light.type == .DIRECTIONAL {
            use_shader(mesh_shader)
            set_vec3fv(mesh_shader, "dirLight.direction", light.direction)
            set_vec3fv(mesh_shader, "dirLight.diffuse", light.diffuse)
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

            diffuse_c_str := strings.clone_to_cstring(
                fmt.tprintf("pointLights[%d].diffuse", point_light_idx),
                context.temp_allocator,
            )
            set_vec3fv(mesh_shader, diffuse_c_str, light.diffuse)

            point_light_idx += 1
        }
    }
}

// TODO: is there a better place to put this?
get_editor_camera :: proc() -> ^Camera {
    return &editor_camera
}
