package zephr

import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:math"
import "core:slice"
import "core:strings"
import "core:path/filepath"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:stb/image"

// We do 2^0, 2^2, 2^3, 2^4 to get 1, 4, 8, 16 for the corresponding MSAA samples
MSAA_SAMPLES :: enum i32 {
    NONE,
    MSAA_4 = 2,
    MSAA_8,
    MSAA_16,
}

ANTIALIASING :: enum {
    MSAA,
}

@(private = "file")
mesh_shader: ^Shader
@(private = "file")
missing_texture: TextureId
@(private = "file")
multisample_fb: u32
@(private = "file")
depth_texture: TextureId
@(private = "file")
color_texture: TextureId
@(private = "file")
msaa := MSAA_SAMPLES.MSAA_4

change_msaa :: proc(by: int) {
    msaa_int := int(msaa)

    defer {
        log.debug("Setting MSAA to", msaa)
        resize_multisample_fb(cast(i32)zephr_ctx.window.size.x, cast(i32)zephr_ctx.window.size.y)
    }

    msaa_int += by

    if msaa_int == 1 {
        msaa = MSAA_SAMPLES(msaa_int + by)
        return
    }

    if msaa_int < int(MSAA_SAMPLES.NONE) {
        msaa = .MSAA_16
        return
    }

    if msaa_int > int(MSAA_SAMPLES.MSAA_16) {
        msaa = .NONE
        return
    }

    msaa = MSAA_SAMPLES(msaa_int)
}

set_msaa :: proc(sampling: MSAA_SAMPLES) {
    msaa = sampling
}

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

@(private)
init_renderer :: proc(window_size: m.vec2) {
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

    init_obb()
    init_depth_pass()
    init_color_pass(window_size)
}

@(private)
resize_multisample_fb :: proc(width, height: i32) {
    gl.Viewport(0, 0, width, height)
    _msaa := math.pow2_f32(msaa)

    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, color_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.RGB8, width, height, gl.FALSE)

    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, depth_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.DEPTH24_STENCIL8, width, height, gl.FALSE)
}

@(private)
init_color_pass :: proc(size: m.vec2) {
    _msaa := 1 << u32(msaa)
    {
        max_samples: i32
        gl.GetIntegerv(gl.MAX_SAMPLES, &max_samples)
        log.debug("MAX MSAA SAMPLES:", max_samples)
    }

    gl.GenTextures(1, &color_texture)
    gl.GenTextures(1, &depth_texture)
    gl.GenFramebuffers(1, &multisample_fb)

    gl.BindFramebuffer(gl.FRAMEBUFFER, multisample_fb)

    // Textures for both the color and depth attachments because renderbuffers just refuse to work
    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, color_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.RGB8, i32(size.x), i32(size.y), gl.FALSE)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, color_texture, 0)

    // There's no need for stencil here but renderdoc crashes when loading a capture if it isn't there.
    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, depth_texture)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, i32(_msaa), gl.DEPTH24_STENCIL8, i32(size.x), i32(size.y), gl.FALSE)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.TEXTURE_2D_MULTISAMPLE, depth_texture, 0)

    status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
    if status != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Multisampled color framebuffer is not complete: 0x%X", status)
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

@(private = "file")
SHADOW_MAP_W :: 1024
@(private = "file")
SHADOW_MAP_H :: 1024
@(private = "file")
depth_map_fb: u32
shadow_map: TextureId
@(private = "file")
depth_shader: ^Shader
@(private = "file")
frustum_shader: ^Shader
frustum_vao: u32
frustum_vbo: u32
sphere_vao: u32
sphere_vbo: u32

sectorCount :: 72
stackCount :: 36

init_depth_pass :: proc() {
    gl.GenFramebuffers(1, &depth_map_fb)

    border_color := []f32{1, 1, 1, 1}
    swizzle_mask := []i32{gl.RED, gl.RED, gl.RED, gl.ALPHA}
    gl.GenTextures(1, &shadow_map)
    gl.BindTexture(gl.TEXTURE_2D, shadow_map)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT32F, SHADOW_MAP_W, SHADOW_MAP_H, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
    gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, raw_data(border_color))
    // Use the red channel for green and blue to view it as greyscale when debug drawing
    gl.TexParameteriv(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_RGBA, raw_data(swizzle_mask))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_COMPARE_MODE, gl.COMPARE_REF_TO_TEXTURE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_COMPARE_FUNC, gl.GEQUAL)

    gl.BindFramebuffer(gl.FRAMEBUFFER, depth_map_fb)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, shadow_map, 0)
    gl.DrawBuffer(gl.NONE)
    gl.ReadBuffer(gl.NONE)

    status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
    if status != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Depth framebuffer is not complete: 0x%X", status)
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    depth_shader_l, ok := create_shader(create_resource_path("shaders/shadow_map.vert"), create_resource_path("shaders/shadow_map.frag"))
    depth_shader = depth_shader_l
    if !ok {
        log.error("Failed to load depth map shader")
    }

    frustum_shader_l, frustum_ok := create_shader(create_resource_path("shaders/gizmo.vert"), create_resource_path("shaders/gizmo.frag"))
    frustum_shader = frustum_shader_l
    if !frustum_ok {
        log.error("Failed to load frustum shader")
    }

    // Frustum
    gl.GenVertexArrays(1, &frustum_vao)
    gl.GenBuffers(1, &frustum_vbo)

    gl.BindVertexArray(frustum_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, frustum_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(m.vec3) * 36, nil, gl.DYNAMIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    gl.GenVertexArrays(1, &sphere_vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}

// MUST be called every frame
draw :: proc(entities: []Entity, lights: []Light, camera: ^Camera) {
    light_space_mat := depth_pass(entities, lights, camera)
    color_pass(entities, lights, camera, light_space_mat)
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
draw_model :: proc(model: ^Model, depth_only: bool = false) {
    if !depth_only {
        use_shader(mesh_shader)
    }

    if model.active_animation != nil && model.active_animation.timer.running {
        advance_animation(model.active_animation)
    }

    for node in &model.nodes {
        draw_node(node, &model.materials, depth_only)
    }
}

@(private = "file")
draw_node :: proc(node: ^Node, materials: ^map[uintptr]Material, depth_only: bool) {
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
        if depth_only {
            set_mat4f(depth_shader, "model", node.world_transform)
            gl.BindVertexArray(mesh.vao)
            gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)
            gl.BindVertexArray(0)
        } else {
            draw_mesh(mesh, node.world_transform, materials, joint_matrices)
            //draw_obb(mesh.obb, node.world_transform)
        }
    }

    for child in node.children {
        draw_node(child, materials, depth_only)
    }
}

@(private = "file", disabled = RELEASE_BUILD)
draw_obb :: proc(obb: OBB, transform: m.mat4) {
    set_mat4f(mesh_shader, "model", transform)
    set_bool(mesh_shader, "useSkinning", false)

    vertices := []m.vec3{
        obb.min,
        {obb.max.x, obb.min.y, obb.min.z},
        {obb.max.x, obb.max.y, obb.min.z},
        {obb.min.x, obb.max.y, obb.min.z},
        {obb.min.x, obb.min.y, obb.max.z},
        {obb.max.x, obb.min.y, obb.max.z},
        obb.max,
        {obb.min.x, obb.max.y, obb.max.z},
    }

    gl.LineWidth(4)
    gl.BindVertexArray(obb_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, obb_vbo)
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
    // TODO: calling set_int a shitton of times is apparently slow according to callgrind
    set_int(mesh_shader, "morphTargets", 0)
    set_int(mesh_shader, "morphTargetWeights", 1)
    set_int(mesh_shader, "jointMatrices", 2)
    set_int(mesh_shader, "material.texture_diffuse", 3)
    set_int(mesh_shader, "material.texture_normal", 4)
    set_int(mesh_shader, "material.texture_metallic_roughness", 5)
    set_int(mesh_shader, "material.texture_emissive", 6)
    set_int(mesh_shader, "shadowMap", 7)
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

    gl.ActiveTexture(gl.TEXTURE7)
    gl.BindTexture(gl.TEXTURE_2D, shadow_map)

    gl.BindVertexArray(mesh.vao)
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)

    set_bool(mesh_shader, "useTextures", false)

    gl.BindVertexArray(0)
}

draw_lights :: proc(lights: []Light) {
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

//odinfmt: disable
box_verts :: []f32 {
    // Back
    -1.0,  1.0, -1.0,
    -1.0, -1.0, -1.0,
    1.0, -1.0, -1.0,
    1.0, -1.0, -1.0,
    1.0,  1.0, -1.0,
    -1.0,  1.0, -1.0,

    // Left
    -1.0, -1.0,  1.0,
    -1.0, -1.0, -1.0,
    -1.0,  1.0, -1.0,
    -1.0,  1.0, -1.0,
    -1.0,  1.0,  1.0,
    -1.0, -1.0,  1.0,

    // Right
    1.0, -1.0, -1.0,
    1.0, -1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0, -1.0,
    1.0, -1.0, -1.0,

    // Front
    -1.0, -1.0,  1.0,
    -1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0, -1.0,  1.0,
    -1.0, -1.0,  1.0,

    // Top
    -1.0,  1.0, -1.0,
    1.0,  1.0, -1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    -1.0,  1.0,  1.0,
    -1.0,  1.0, -1.0,

    // Bottom
    -1.0, -1.0, -1.0,
    -1.0, -1.0,  1.0,
    1.0, -1.0, -1.0,
    1.0, -1.0, -1.0,
    -1.0, -1.0,  1.0,
    1.0, -1.0,  1.0,
}
//odinfmt: enable

depth_pass :: proc(entities: []Entity, lights: []Light, camera: ^Camera) -> m.mat4 {
    context.logger = logger

    gl.Viewport(0, 0, SHADOW_MAP_W, SHADOW_MAP_H)
    gl.BindFramebuffer(gl.FRAMEBUFFER, depth_map_fb)
    gl.Clear(gl.DEPTH_BUFFER_BIT)
    // Used to solve peter panning but only good for closed objects. breaks on flat surfaces.
    //gl.Enable(gl.CULL_FACE)
    //gl.CullFace(gl.FRONT)
    size := zephr_ctx.window.size

    e_camera := &editor_camera

    //k := math.sqrt(1+((size.y*size.y)/(size.x*size.x))) * math.tan(camera.fov/2)

    near_center_ws := e_camera.position + (e_camera.near * e_camera.front)
    far_center_ws := e_camera.position + (e_camera.far * e_camera.front)

    //log.debug("Cam pos:", camera.position)
    //log.debug("Cam front:", camera.front)
    //log.debug("near ws:", near_center_ws)
    //log.debug("far ws:", far_center_ws)

    light_dir: m.vec3
    for light in lights {
        if light.type != .DIRECTIONAL {
            // TODO:
            log.warn("Skipping non-directional lights for depth pass")
            continue
        }

        light_dir = light.direction
        break
    }

    center := m.vec3{0,0,0}
    frustum_corners := get_frustum_corners_world_space(e_camera)
    for corner in frustum_corners {
        center += corner.xyz
    }
    center /= len(frustum_corners)

    // Minimum bounding sphere around a 3d frustum
    // Reference: https://lxjk.github.io/2017/04/15/Calculate-Minimal-Bounding-Sphere-of-Frustum.html
    // with some modifications to account for frustum movement and rotation
    s_radius: f32
    s_center: m.vec3
    {
        half_near_diag := m.distance(near_center_ws, m.vec3{frustum_corners[2].x, frustum_corners[2].y, frustum_corners[2].z}) // left, top, front corner
        half_far_diag := m.distance(far_center_ws, m.vec3{frustum_corners[3].x, frustum_corners[3].y, frustum_corners[3].z}) // left, top, back corner

        near_far_dist := m.length(far_center_ws - near_center_ws)
        near_to_s_center_dist := ((half_near_diag*half_near_diag) - (half_far_diag*half_far_diag) - (near_far_dist*near_far_dist)) / (-2 * near_far_dist)

        //log.debug("n0n1:", half_near_diag)
        //log.debug("n0n1*n0n1:", half_near_diag*half_near_diag)
        //log.debug("f0f1:", half_far_diag)
        //log.debug("f0f1*f0f1:", half_far_diag * half_far_diag)
        //log.debug("n0f0", near_far_dist)
        //log.debug("n0f0*n0f0", near_far_dist*near_far_dist)
        //log.debug("n1:", frustum_corners[2].xyz)
        //log.debug("f1:", frustum_corners[3].xyz)
        //log.debug("cn0:", near_to_s_center_dist)

        far_to_s_center_dist := near_far_dist - near_to_s_center_dist
        //log.debug("cf0:", far_to_s_center_dist)
        s_radius = math.sqrt((half_near_diag*half_near_diag) + (near_to_s_center_dist*near_to_s_center_dist))
        s_center = near_center_ws + (e_camera.front * near_to_s_center_dist)

        //log.debug("radius:", radius)
        //log.debug("sphere center:", s_center)
    }

    //pos := center - light_dir
    //f: f32 = longest_diagonal / 4096
    //pos.x = math.round(pos.x/f)*f
    //pos.y = math.round(pos.y/f)*f

    //log.debug(light_dir)
    //log.debug(m.normalize(light_dir))
    view_mat := m.mat4LookAt(center - m.normalize(light_dir), center, {0, 1, 0})

    //ortho_min := m.vec3{math.F32_MAX, math.F32_MAX, math.F32_MAX}
    //ortho_max := m.vec3{-math.F32_MAX, -math.F32_MAX, -math.F32_MAX}
    //for corner in frustum_corners {
    //    trf := view_mat * corner
    //    ortho_min = m.min(ortho_min, m.vec3(trf.xyz))
    //    ortho_max = m.max(ortho_max, m.vec3(trf.xyz))
    //}


    //log.debug(ortho_min)
    //log.debug(ortho_max)

    //ortho_min /= world_unit_per_texel
    //ortho_min = m.floor(ortho_min)
    //ortho_min *= world_unit_per_texel

    //ortho_max /= world_unit_per_texel
    //ortho_max = m.floor(ortho_max)
    //ortho_max *= world_unit_per_texel

    //log.debug(ortho_min)
    //log.debug(ortho_max)

    //ortho_min.z = -20
    //ortho_max.z = 20


    //f := longest_diagonal / m.vec2{4096, 4096}
    //ortho_min /= m.vec3{f.x, f.y, 0}
    //ortho_min = m.floor(ortho_min)
    //ortho_min *= m.vec3{f.x, f.y, 0}
    //ortho_max /= m.vec3{f.x, f.y, 0}
    //ortho_max = m.floor(ortho_max)
    //ortho_max *= m.vec3{f.x, f.y, 0}

    //z_mult: f32 : 10.0
    //if min_z < 0 {
    //    min_z *= z_mult
    //} else {
    //    min_z /= z_mult
    //}
    //if max_z < 0 {
    //    max_z /= z_mult
    //} else {
    //    max_z *= z_mult
    //}

    // TODO: trying to move to CSM and the depth map is borked for some reason now.
    // the camera seems to be VERY far away from the ground and our player.
    // The reason is because the far plane was very high and with the new impl it tries to include everything in that frustum
    // into the depth/shadow map. reducing the far plane fixes it. having multiple shadow maps (CSM) also fixes it
    // because every shadow map will only be used for a much smaller frustum (with varying quality ofc where closer objects
    // are affected by the highest quality map and farther objects have jaggidy shadows)

    // TODO: we're trying to tightly fit the shadow map on the frustum by following the MS article
    // https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps?redirectedfrom=MSDN
    // The x and y are correct according to the article but the z can be calculated more accurately with a different method
    // Look into that.
    //projection_mat := m.mat4Ortho3d(-1, 1, -1, 1, ortho_min.z, ortho_max.z)

    sphere_aabb_min := s_center - s_radius
    sphere_aabb_max := s_center + s_radius
    //sphere_aabb_min.z = -50
    //sphere_aabb_max.z = 50
    sphere_aabb_min_ls := view_mat * m.vec4{sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_min.z, 1}
    sphere_aabb_max_ls := view_mat * m.vec4{sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z, 1}

    normalize_by_map_size := m.vec4{1.0 / f32(SHADOW_MAP_W), 1.0 / f32(SHADOW_MAP_H), 1.0 / f32(SHADOW_MAP_H), 0}
    world_unit_per_texel := sphere_aabb_max_ls - sphere_aabb_min_ls
    world_unit_per_texel *= normalize_by_map_size

    sphere_aabb_min_ls /= world_unit_per_texel
    sphere_aabb_min_ls = m.floor(sphere_aabb_min_ls)
    sphere_aabb_min_ls *= world_unit_per_texel

    sphere_aabb_max_ls /= world_unit_per_texel
    sphere_aabb_max_ls = m.floor(sphere_aabb_max_ls)
    sphere_aabb_max_ls *= world_unit_per_texel

    //log.debug(sphere_aabb_min_ls)
    //log.debug(sphere_aabb_max_ls)
    projection_mat := m.mat4Ortho3d(sphere_aabb_min_ls.x, sphere_aabb_max_ls.x, sphere_aabb_min_ls.y, sphere_aabb_max_ls.y, sphere_aabb_min_ls.z, sphere_aabb_max_ls.z)
    //log.debug(projection_mat)

    //scale_x := 2 / (ortho_max.x - ortho_min.x)
    //scale_y := 2 / (ortho_max.y - ortho_min.y)
    //offset_x := -0.5 * (ortho_min.x + ortho_max.x) * scale_x
    //offset_y := -0.5 * (ortho_min.y + ortho_max.y) * scale_y
    //crop_mat := m.identity(m.mat4)
    //crop_mat[0][0] = scale_x
    //crop_mat[1][1] = scale_y
    //crop_mat[3][0] = offset_x
    //crop_mat[3][1] = offset_y

    //texel_size: f32 = 2.0 / 4096
    //shadow_origin := projection_mat * view_mat * m.vec4{0,0,0,1.0}
    //shadow_origin /= shadow_origin.w

    //texel_center := m.vec2{math.floor(shadow_origin.x / texel_size) * texel_size, math.floor(shadow_origin.y / texel_size) * texel_size}
    //offset := m.vec4{texel_center.x, texel_center.y, 0, 0}
    //offset_matrix := m.mat4Translate({texel_center.x, texel_center.y, 0})
    //offset = m.inverse(projection_mat) * offset

    //projection_mat[3] += {offset.x, offset.y, offset.z, offset.w}

    //offset_x := shadow_origin.x / shadow_origin.w
    //offset_y := shadow_origin.y / shadow_origin.w
    //texel_offset_x := math.floor(offset_x / texel_size) * texel_size - offset_x
    //texel_offset_y := math.floor(offset_y / texel_size) * texel_size - offset_y
    //offset_matrix := m.mat4Translate({texel_offset_x, texel_offset_y, 0})
    //projection_mat = offset_matrix * projection_mat

    light_space_mat := projection_mat * view_mat

    use_shader(depth_shader)
    set_mat4f(depth_shader, "lightSpaceMatrix", light_space_mat)

    for &entity in entities {
        model_mat := m.identity(m.mat4)
        model_mat = m.mat4Scale(entity.scale) * model_mat
        model_mat = m.mat4FromQuat(entity.rotation) * model_mat
        model_mat = m.mat4Translate(entity.position) * model_mat

        apply_transform_hierarchy(&entity.model, model_mat)
        draw_model(&entity.model, true)
    }


    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // Visualize the camera frustum, light frustum, and bounding sphere
    {
        gl.BindFramebuffer(gl.FRAMEBUFFER, multisample_fb)
        gl.Viewport(0, 0, cast(i32)zephr_ctx.window.size.x, cast(i32)zephr_ctx.window.size.y)
        gl.ClearColor(zephr_ctx.clear_color.r, zephr_ctx.clear_color.g, zephr_ctx.clear_color.b, zephr_ctx.clear_color.a)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        use_shader(frustum_shader)
        gl.BindVertexArray(frustum_vao)

        data := [36]m.vec3 {
            // near
            frustum_corners[1].xyz,
            frustum_corners[3].xyz,
            frustum_corners[5].xyz,
            frustum_corners[3].xyz,
            frustum_corners[5].xyz,
            frustum_corners[7].xyz,
            // far
            frustum_corners[0].xyz,
            frustum_corners[2].xyz,
            frustum_corners[4].xyz,
            frustum_corners[2].xyz,
            frustum_corners[4].xyz,
            frustum_corners[6].xyz,
            // left
            frustum_corners[0].xyz,
            frustum_corners[1].xyz,
            frustum_corners[2].xyz,
            frustum_corners[1].xyz,
            frustum_corners[2].xyz,
            frustum_corners[3].xyz,
            // right
            frustum_corners[4].xyz,
            frustum_corners[5].xyz,
            frustum_corners[6].xyz,
            frustum_corners[5].xyz,
            frustum_corners[6].xyz,
            frustum_corners[7].xyz,
            // top
            frustum_corners[2].xyz,
            frustum_corners[3].xyz,
            frustum_corners[6].xyz,
            frustum_corners[3].xyz,
            frustum_corners[6].xyz,
            frustum_corners[7].xyz,
            // bottom
            frustum_corners[0].xyz,
            frustum_corners[1].xyz,
            frustum_corners[4].xyz,
            frustum_corners[1].xyz,
            frustum_corners[4].xyz,
            frustum_corners[5].xyz,
        }
        //data := [36]m.vec3 {
        //    // near
        //    (view_mat * frustum_corners[1]).xyz,
        //    (view_mat * frustum_corners[3]).xyz,
        //    (view_mat * frustum_corners[5]).xyz,
        //    (view_mat * frustum_corners[3]).xyz,
        //    (view_mat * frustum_corners[5]).xyz,
        //    (view_mat * frustum_corners[7]).xyz,
        //    // far
        //    (view_mat * frustum_corners[0]).xyz,
        //    (view_mat * frustum_corners[2]).xyz,
        //    (view_mat * frustum_corners[4]).xyz,
        //    (view_mat * frustum_corners[2]).xyz,
        //    (view_mat * frustum_corners[4]).xyz,
        //    (view_mat * frustum_corners[6]).xyz,
        //    // left
        //    (view_mat * frustum_corners[0]).xyz,
        //    (view_mat * frustum_corners[1]).xyz,
        //    (view_mat * frustum_corners[2]).xyz,
        //    (view_mat * frustum_corners[1]).xyz,
        //    (view_mat * frustum_corners[2]).xyz,
        //    (view_mat * frustum_corners[3]).xyz,
        //    // right
        //    (view_mat * frustum_corners[4]).xyz,
        //    (view_mat * frustum_corners[5]).xyz,
        //    (view_mat * frustum_corners[6]).xyz,
        //    (view_mat * frustum_corners[5]).xyz,
        //    (view_mat * frustum_corners[6]).xyz,
        //    (view_mat * frustum_corners[7]).xyz,
        //    // top
        //    (view_mat * frustum_corners[2]).xyz,
        //    (view_mat * frustum_corners[3]).xyz,
        //    (view_mat * frustum_corners[6]).xyz,
        //    (view_mat * frustum_corners[3]).xyz,
        //    (view_mat * frustum_corners[6]).xyz,
        //    (view_mat * frustum_corners[7]).xyz,
        //    // bottom
        //    (view_mat * frustum_corners[0]).xyz,
        //    (view_mat * frustum_corners[1]).xyz,
        //    (view_mat * frustum_corners[4]).xyz,
        //    (view_mat * frustum_corners[1]).xyz,
        //    (view_mat * frustum_corners[4]).xyz,
        //    (view_mat * frustum_corners[5]).xyz,
        //}
        gl.BindBuffer(gl.ARRAY_BUFFER, frustum_vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(m.vec3) * 36, raw_data(&data[0]))
        set_mat4f(frustum_shader, "MVP", camera.proj_mat * camera.view_mat)
        set_vec4fv(frustum_shader, "color", {1, 0, 0, 0.5})

        gl.DrawArrays(gl.TRIANGLES, 0, 36)

        // Transform the ortho coords to the camera space from light space
        //ortho_min = (m.inverse(view_mat) * m.vec4{ortho_min.x, ortho_min.y, ortho_min.z, 1}).xyz
        //ortho_max = (m.inverse(view_mat) * m.vec4{ortho_max.x, ortho_max.y, ortho_max.z, 1}).xyz

        //light_frustum_verts := [36]m.vec3{
        //    // near
        //    {ortho_min.x, ortho_min.y, ortho_max.z},
        //    {ortho_min.x, ortho_max.y, ortho_max.z},
        //    {ortho_max.x, ortho_min.y, ortho_max.z},
        //    {ortho_min.x, ortho_max.y, ortho_max.z},
        //    {ortho_max.x, ortho_min.y, ortho_max.z},
        //    {ortho_max.x, ortho_max.y, ortho_max.z},

        //    // far
        //    {ortho_min.x, ortho_min.y, ortho_min.z},
        //    {ortho_min.x, ortho_max.y, ortho_min.z},
        //    {ortho_max.x, ortho_min.y, ortho_min.z},
        //    {ortho_min.x, ortho_max.y, ortho_min.z},
        //    {ortho_max.x, ortho_min.y, ortho_min.z},
        //    {ortho_max.x, ortho_max.y, ortho_min.z},

        //    // left
        //    {ortho_min.x, ortho_min.y, ortho_max.z},
        //    {ortho_min.x, ortho_min.y, ortho_min.z},
        //    {ortho_min.x, ortho_max.y, ortho_min.z},
        //    {ortho_min.x, ortho_max.y, ortho_min.z},
        //    {ortho_min.x, ortho_max.y, ortho_max.z},
        //    {ortho_min.x, ortho_min.y, ortho_max.z},

        //    // right
        //    {ortho_max.x, ortho_min.y, ortho_max.z},
        //    {ortho_max.x, ortho_min.y, ortho_min.z},
        //    {ortho_max.x, ortho_max.y, ortho_min.z},
        //    {ortho_max.x, ortho_max.y, ortho_min.z},
        //    {ortho_max.x, ortho_max.y, ortho_max.z},
        //    {ortho_max.x, ortho_min.y, ortho_max.z},

        //    // top
        //    {ortho_min.x, ortho_max.y, ortho_min.z},
        //    {ortho_max.x, ortho_max.y, ortho_min.z},
        //    {ortho_max.x, ortho_max.y, ortho_max.z},
        //    {ortho_max.x, ortho_max.y, ortho_max.z},
        //    {ortho_min.x, ortho_max.y, ortho_max.z},
        //    {ortho_min.x, ortho_max.y, ortho_min.z},

        //    // bottom
        //    {ortho_min.x, ortho_min.y, ortho_min.z},
        //    {ortho_max.x, ortho_min.y, ortho_min.z},
        //    {ortho_max.x, ortho_min.y, ortho_max.z},
        //    {ortho_max.x, ortho_min.y, ortho_max.z},
        //    {ortho_min.x, ortho_min.y, ortho_max.z},
        //    {ortho_min.x, ortho_min.y, ortho_min.z},
        //}

        // Draw the AABB for the bounding sphere
        aabb_verts := [36]m.vec3{
            // Back
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_min.z},
            // Left
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_max.z},
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_max.z},
            // Right
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_min.z},
            // Front
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_max.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_max.z},
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_max.z},
            // Top
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_max.z},
            {sphere_aabb_min.x, sphere_aabb_max.y, sphere_aabb_min.z},
            // Bottom
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_min.z},
            {sphere_aabb_min.x, sphere_aabb_min.y, sphere_aabb_max.z},
            {sphere_aabb_max.x, sphere_aabb_min.y, sphere_aabb_max.z},
        }

        // Light frustum
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(m.vec3) * 36, raw_data(&aabb_verts[0]))
        rot_axis := m.cross(m.vec3{0,0,1}, m.normalize(light_dir))
        angle := m.acos(m.dot(m.vec3{0,0,1}, m.normalize(light_dir)))
        model := m.identity(m.mat4)
        //model = m.mat4Scale({abs(ortho_max.x) / 2, abs(ortho_max.y) / 2, 40}) * model
        //model = m.mat4Rotate(rot_axis, angle) * model
        //model = m.mat4Rotate({0, 0, 1}, m.radians(f32(90))) * model
        //model = m.mat4Translate({0, 0, -15}) * model
        //model = m.mat4Translate(center - m.normalize(light_dir)) * model
        set_mat4f(frustum_shader, "MVP", camera.proj_mat * camera.view_mat * model)
        set_vec4fv(frustum_shader, "color", {1, 1, 1, 0.4})
        gl.DrawArrays(gl.TRIANGLES, 0, 36)

        // Make the text always face the camera - Billboarding
        v := m.normalize(camera.position)
        r := m.vec3{camera.view_mat[0][0], camera.view_mat[1][0], camera.view_mat[2][0]}
        u := m.vec3{camera.view_mat[0][1], camera.view_mat[1][1], camera.view_mat[2][1]}
        rotmat := m.mat4{
            r.x, u.x, -v.x, model[3][0],
            r.y, u.y, -v.y, model[3][1],
            r.z, u.z, -v.z, model[3][2],
            0, 0, 0, 1,
        }
        draw_text_world("Sun", 1, rotmat, COLOR_YELLOW, camera)


        // Minimum bounding sphere for the camera frustum
        sectorStep := 2 * m.PI / f32(sectorCount)
        stackStep := m.PI / f32(stackCount)
        sphere_vertices := make([dynamic]f32, 0, (sectorCount + 1) * (stackCount + 1), context.temp_allocator)

        use_shader(frustum_shader)
        for i in 0..=stackCount {
            phi := m.PI * f32(i) / f32(stackCount)

            for j in 0..=sectorCount {
                theta := 2 * m.PI * f32(j) / f32(sectorCount)

                x := s_radius * m.sin(phi) * m.cos(theta) + s_center.x
                y := s_radius * m.cos(phi) + s_center.y
                z := s_radius * m.sin(phi) * m.sin(theta) + s_center.z

                append(&sphere_vertices, x)
                append(&sphere_vertices, y)
                append(&sphere_vertices, z)

                if i < stackCount {
                    next_phi := m.PI * f32(i + 1) / f32(stackCount)
                    x_next := s_radius * m.sin(next_phi) * m.cos(theta) + s_center.x
                    y_next := s_radius * m.cos(next_phi) + s_center.y
                    z_next := s_radius * m.sin(next_phi) * m.sin(theta) + s_center.z

                    append(&sphere_vertices, x_next)
                    append(&sphere_vertices, y_next)
                    append(&sphere_vertices, z_next)
                }
            }
        }

        gl.GenBuffers(1, &sphere_vbo)

        gl.BindVertexArray(sphere_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, sphere_vbo)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * len(sphere_vertices), raw_data(sphere_vertices), gl.STATIC_DRAW)

        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
        gl.EnableVertexAttribArray(0)
        set_vec4fv(frustum_shader, "color", {0, 1, 0, 0.5})
        set_mat4f(frustum_shader, "MVP", camera.proj_mat * camera.view_mat)
        for i in 0..<stackCount {
            gl.DrawArrays(gl.TRIANGLE_STRIP, i32(i) * (sectorCount + 1) * 2, (sectorCount + 1) * 2)
        }

        gl.Disable(gl.BLEND)

        gl.BindVertexArray(0)
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        gl.DeleteBuffers(1, &sphere_vbo)
    }

    //gl.CullFace(gl.BACK)
    //gl.Disable(gl.CULL_FACE)
    return light_space_mat
}

color_pass :: proc(entities: []Entity, lights: []Light, camera: ^Camera, light_space_mat: m.mat4) {
    context.logger = logger
    gl.BindFramebuffer(gl.FRAMEBUFFER, multisample_fb)
    gl.Viewport(0, 0, cast(i32)zephr_ctx.window.size.x, cast(i32)zephr_ctx.window.size.y)
    gl.ClearColor(zephr_ctx.clear_color.r, zephr_ctx.clear_color.g, zephr_ctx.clear_color.b, zephr_ctx.clear_color.a)
    //gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    use_shader(mesh_shader)
    set_vec3fv(mesh_shader, "viewPos", camera.position)
    set_mat4f(mesh_shader, "projectionView", camera.proj_mat * camera.view_mat)
    set_mat4f(mesh_shader, "lightSpaceMatrix", light_space_mat)
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

    for &entity in entities {
        model_mat := m.identity(m.mat4)
        model_mat = m.mat4Scale(entity.scale) * model_mat
        model_mat = m.mat4FromQuat(entity.rotation) * model_mat
        model_mat = m.mat4Translate(entity.position) * model_mat

        apply_transform_hierarchy(&entity.model, model_mat)
        draw_model(&entity.model)
        //draw_obb(entity.model.obb, entity.model.nodes[0].world_transform)
        //draw_collision_shape()
    }

    size_x := cast(i32)zephr_ctx.window.size.x
    size_y := cast(i32)zephr_ctx.window.size.y

    gl.BindFramebuffer(gl.READ_FRAMEBUFFER, multisample_fb)
    gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
    gl.DrawBuffer(gl.BACK)
    gl.BlitFramebuffer(0, 0, size_x, size_y, 0, 0, size_x, size_y, gl.COLOR_BUFFER_BIT, gl.NEAREST)

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

// MUST be called after drawing and before swapping buffers, otherwise you only get the clear color
save_default_framebuffer_to_image :: proc(dir: string = ".", filename: string = "") -> bool {
    filename := filename
    w := i32(zephr_ctx.window.size.x)
    h := i32(zephr_ctx.window.size.y)

    if filename == "" {
        now := time.now()
        year, month, day := time.date(now)
        hour, mins, secs := time.clock_from_time(now)
        filename = fmt.tprintf("%d-%02d-%02d %02d:%02d:%02d.png", year, cast(i32)month, day, hour, mins, secs)
    } else {
        filename = strings.concatenate({filename, ".png"}, context.temp_allocator)
    }

    pixels := make([]u8, w * h * 3)
    defer delete(pixels)
    gl.PixelStorei(gl.PACK_ALIGNMENT, 1)
    gl.ReadPixels(0, 0, w, h, gl.RGB, gl.UNSIGNED_BYTE, raw_data(pixels))
    gl.PixelStorei(gl.PACK_ALIGNMENT, 4)

    final_path := filepath.join({dir, filename})
    cstr := strings.clone_to_cstring(final_path, context.temp_allocator)
    image.flip_vertically_on_write(true)
    return image.write_png(cstr, w, h, 3, raw_data(pixels), w * 3) != 0
}

