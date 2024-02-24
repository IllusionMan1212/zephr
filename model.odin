package zephr

import "core:fmt"
import "core:intrinsics"
import "core:log"
import m "core:math/linalg/glsl"
import "core:strings"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:cgltf"

#assert(size_of(Vertex) == 48)
Vertex :: struct {
    position:   m.vec3,
    normal:     m.vec3,
    tex_coords: m.vec2,
    tangents:   m.vec4,
}

@(private)
MorphTarget :: struct {
    positions: []f32,
    normals:   []f32,
    tangents:  []f32,
}

@(private)
Mesh :: struct {
    primitive:     cgltf.primitive_type,
    vertices:      [dynamic]Vertex,
    indices:       []u32,
    material_id:   uintptr,
    weights:       []f32,
    morph_targets: []MorphTarget,
    vao:           u32,
    vbo:           u32,
    ebo:           u32,
}

Node :: struct {
    id:            uintptr,
    name:          string,
    meshes:        [dynamic]Mesh,
    transform:     m.mat4,
    has_transform: bool,
    scale:         m.vec3,
    translation:   m.vec3,
    rotation:      m.quat,
    children:      [dynamic]Node,
}

Model :: struct {
    nodes:            [dynamic]Node,
    materials:        map[uintptr]Material,
    position:         m.vec3,
    scale:            m.vec3,
    rotation:         m.vec3,
    rotation_angle_d: f32,
    animations:       []Animation,
}

@(private = "file")
process_sparse_accessor_vec2 :: proc(accessor: ^cgltf.accessor_sparse, data_out: []f32) {
    indices_byte_offset := accessor.indices_byte_offset + accessor.indices_buffer_view.offset
    values_byte_offset := accessor.values_byte_offset + accessor.values_buffer_view.offset

    sparse_values := intrinsics.ptr_offset(
        transmute([^]f32)accessor.values_buffer_view.buffer.data,
        values_byte_offset / size_of(f32),
    )

    indices := make([]u32, accessor.count)

    process_indices(accessor.indices_buffer_view, accessor.indices_component_type, indices_byte_offset, indices)

    for idx, i in indices {
        data_out[idx * 2] = sparse_values[i * 2]
        data_out[idx * 2 + 1] = sparse_values[i * 2 + 1]
    }
}

@(private = "file")
process_sparse_accessor_vec3 :: proc(accessor: ^cgltf.accessor_sparse, data_out: []f32) {
    indices_byte_offset := accessor.indices_byte_offset + accessor.indices_buffer_view.offset
    values_byte_offset := accessor.values_byte_offset + accessor.values_buffer_view.offset

    sparse_values := intrinsics.ptr_offset(
        transmute([^]f32)accessor.values_buffer_view.buffer.data,
        values_byte_offset / size_of(f32),
    )

    indices := make([]u32, accessor.count)

    process_indices(accessor.indices_buffer_view, accessor.indices_component_type, indices_byte_offset, indices)

    for idx, i in indices {
        data_out[idx * 3] = sparse_values[i * 3]
        data_out[idx * 3 + 1] = sparse_values[i * 3 + 1]
        data_out[idx * 3 + 2] = sparse_values[i * 3 + 2]
    }
}

@(private = "file")
process_sparse_accessor_vec4 :: proc(accessor: ^cgltf.accessor_sparse, data_out: []f32) {
    indices_byte_offset := accessor.indices_byte_offset + accessor.indices_buffer_view.offset
    values_byte_offset := accessor.values_byte_offset + accessor.values_buffer_view.offset

    sparse_values := intrinsics.ptr_offset(
        transmute([^]f32)accessor.values_buffer_view.buffer.data,
        values_byte_offset / size_of(f32),
    )

    indices := make([]u32, accessor.count)

    process_indices(accessor.indices_buffer_view, accessor.indices_component_type, indices_byte_offset, indices)

    for idx, i in indices {
        data_out[idx * 4] = sparse_values[i * 4]
        data_out[idx * 4 + 1] = sparse_values[i * 4 + 1]
        data_out[idx * 4 + 2] = sparse_values[i * 4 + 2]
        data_out[idx * 4 + 3] = sparse_values[i * 4 + 3]
    }
}

@(private = "file")
process_accessor_vec2 :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset

    if accessor.buffer_view != nil {
        byte_offset += accessor.buffer_view.offset

        buf := intrinsics.ptr_offset(transmute([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
        if accessor.buffer_view.stride == 0 {
            copy(data_out, buf[:accessor.count * 2])
        } else {
            for i in 0 ..< accessor.count {
                data_out[i * 2] = buf[i * accessor.buffer_view.stride / size_of(f32)]
                data_out[i * 2 + 1] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 1]
            }
        }

        if accessor.is_sparse {
            process_sparse_accessor_vec2(&accessor.sparse, data_out)
        }
    } else {
        if accessor.is_sparse {
            process_sparse_accessor_vec2(&accessor.sparse, data_out)
        } else {
            log.error("Got a buffer view that is nil and not sparse. Confused on what to do")
        }
    }
}

@(private = "file")
process_accessor_vec3 :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset

    if accessor.buffer_view != nil {
        byte_offset += accessor.buffer_view.offset

        buf := intrinsics.ptr_offset(transmute([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
        if accessor.buffer_view.stride == 0 {
            copy(data_out, buf[:accessor.count * 3])
        } else {
            for i in 0 ..< accessor.count {
                data_out[i * 3] = buf[i * accessor.buffer_view.stride / size_of(f32)]
                data_out[i * 3 + 1] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 1]
                data_out[i * 3 + 2] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 2]
            }
        }

        if accessor.is_sparse {
            process_sparse_accessor_vec3(&accessor.sparse, data_out)
        }
    } else {
        if accessor.is_sparse {
            process_sparse_accessor_vec3(&accessor.sparse, data_out)
        } else {
            log.error("Got a buffer view that is nil and not sparse. Confused on what to do")
        }
    }
}

@(private = "file")
process_accessor_vec4 :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset

    if accessor.buffer_view != nil {
        byte_offset += accessor.buffer_view.offset

        buf := intrinsics.ptr_offset(transmute([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))
        if accessor.buffer_view.stride == 0 {
            copy(data_out, buf[:accessor.count * 4])
        } else {
            for i in 0 ..< accessor.count {
                data_out[i * 4] = buf[i * accessor.buffer_view.stride / size_of(f32)]
                data_out[i * 4 + 1] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 1]
                data_out[i * 4 + 2] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 2]
                data_out[i * 4 + 3] = buf[i * (accessor.buffer_view.stride / size_of(f32)) + 3]
            }
        }

        if accessor.is_sparse {
            process_sparse_accessor_vec4(&accessor.sparse, data_out)
        }
    } else {
        if accessor.is_sparse {
            process_sparse_accessor_vec4(&accessor.sparse, data_out)
        } else {
            log.error("Got a buffer view that is nil and not sparse. Confused on what to do")
        }
    }
}

@(private = "file")
process_accessor_scalar_float :: proc(accessor: ^cgltf.accessor, data_out: []f32) {
    byte_offset := accessor.offset + accessor.buffer_view.offset

    buf := intrinsics.ptr_offset(transmute([^]f32)accessor.buffer_view.buffer.data, byte_offset / size_of(f32))

    if accessor.buffer_view.stride == 0 {
        copy(data_out, buf[:accessor.count])
    } else {
        for i in 0 ..< accessor.count {
            data_out[i] = buf[i * accessor.buffer_view.stride / size_of(f32)]
        }
    }
    // TODO: sparse??
}

@(private = "file")
process_indices :: proc(
    buffer_view: ^cgltf.buffer_view,
    type: cgltf.component_type,
    byte_offset: uint,
    indices_out: []u32,
) {
    context.logger = logger

    #partial switch type {
        case .r_8u:
            start := byte_offset / size_of(u8)
            end := start + len(indices_out)
            ptr_arr := (transmute([^]u8)buffer_view.buffer.data)[start:end]

            for i in 0 ..< len(ptr_arr) {
                indices_out[i] = cast(u32)ptr_arr[i]
            }
        case .r_16u:
            start := byte_offset / size_of(u16)
            end := start + len(indices_out)
            ptr_arr := (transmute([^]u16)buffer_view.buffer.data)[start:end]

            for i in 0 ..< len(ptr_arr) {
                indices_out[i] = cast(u32)ptr_arr[i]
            }
        case .r_32u:
            start := byte_offset / size_of(u32)
            end := start + len(indices_out)
            copy(indices_out, (transmute([^]u32)buffer_view.buffer.data)[start:end])
        case:
            log.warn("Unsupported index type")
    }
}

@(private = "file")
process_mesh :: proc(
    primitive: ^cgltf.primitive,
    materials: ^map[uintptr]Material,
    model_path: string,
    textures: ^map[cstring]TextureId,
    weights_len: int,
) -> (
    Mesh,
    bool,
) {
    context.logger = logger

    if primitive.indices == nil {
        log.error("No indices found")
        return Mesh{}, false
    }

    vertices: [dynamic]Vertex
    material_id: uintptr = 0

    primitive_type := primitive.type
    if primitive.type != .triangles {
        log.warn("Got a primitive that isn't triangles")
    }
    if primitive.material != nil {
        material_id = transmute(uintptr)primitive.material
        if !(material_id in materials) {
            materials[material_id] = process_material(primitive.material, model_path, textures)
        }
    }
    positions: []f32
    defer delete(positions)
    normals: []f32
    defer delete(normals)
    texcoords: []f32
    defer delete(texcoords)
    tangents: []f32
    defer delete(tangents)

    for a in 0 ..< len(primitive.attributes) {
        attribute := primitive.attributes[a]
        accessor := attribute.data

        if attribute.type == .position {
            positions = make([]f32, accessor.count * 3)
            process_accessor_vec3(accessor, positions)
        } else if attribute.type == .normal {
            normals = make([]f32, accessor.count * 3)
            process_accessor_vec3(accessor, normals)
        } else if attribute.type == .texcoord {
            // BUG: we leak memory here for models that have mutiple texcoords
            texcoords = make([]f32, accessor.count * 2)
            process_accessor_vec2(accessor, texcoords)
        } else if attribute.type == .tangent {     // This is explicitly defined as a vec4 in the spec
            tangents = make([]f32, accessor.count * 4)
            process_accessor_vec4(accessor, tangents)
        }
    }

    morph_targets := make([]MorphTarget, len(primitive.targets))
    morph_positions: []f32
    morph_normals: []f32
    morph_tangents: []f32

    for target, i in primitive.targets {
        for attr in target.attributes {
            accessor := attr.data

            #partial switch attr.type {
                case .position:
                    morph_positions = make([]f32, accessor.count * 3)
                    process_accessor_vec3(accessor, morph_positions)
                case .normal:
                    morph_normals = make([]f32, accessor.count * 3)
                    process_accessor_vec3(accessor, morph_normals)
                // This is explicitly defined as a vec3 in the spec
                case .tangent:
                    morph_tangents = make([]f32, accessor.count * 3)
                    process_accessor_vec3(accessor, morph_tangents)
            }
        }

        morph_targets[i] = {
            positions = morph_positions,
            normals   = morph_normals,
            tangents  = morph_tangents,
        }
    }

    if len(normals) == 0 {
        log.warn("No normals found. Some meshes will fall back to flat shading")
    }

    if len(tangents) == 0 {
        log.warn("No tangents found. Some meshes will not have lighting applied")
    }

    for i in 0 ..< len(positions) / 3 {
        tex_coords := len(texcoords) != 0 ? m.vec2{texcoords[i * 2], texcoords[i * 2 + 1]} : m.vec2{0, 0}
        normal := len(normals) != 0 ? m.vec3{normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]} : m.vec3{0, 0, 0}
        tangents :=
            len(tangents) != 0 \
            ? m.vec4{tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2], tangents[i * 4 + 3]} \
            : m.vec4{0, 0, 0, 0}
        append(
            &vertices,
            Vertex {
                position = m.vec3{positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]},
                normal = normal,
                tex_coords = tex_coords,
                tangents = tangents,
            },
        )
    }

    indices := make([]u32, primitive.indices.count)
    offset_into_buffer := primitive.indices.buffer_view.offset
    offset_into_buf_view := primitive.indices.offset

    process_indices(
        primitive.indices.buffer_view,
        primitive.indices.component_type,
        offset_into_buffer + offset_into_buf_view,
        indices,
    )

    return new_mesh(primitive_type, vertices, indices, material_id, weights_len, morph_targets), true
}

@(private = "file")
process_node :: proc(
    node: ^cgltf.node,
    materials: ^map[uintptr]Material,
    model_path: string,
    textures: ^map[cstring]TextureId,
    node_name_idx: ^int,
) -> Node {
    context.logger = logger

    id := transmute(uintptr)node
    name := strings.clone_from_cstring(node.name)
    if node.name == nil {
        name = fmt.aprintf("Node %d", node_name_idx^)
    }
    transform := m.identity(m.mat4)
    translation := m.vec3{0, 0, 0}
    rotation := cast(m.quat)quaternion(x = 0, y = 0, z = 0, w = 1)
    scale := m.vec3{1, 1, 1}
    if node.has_matrix {
        transform = m.mat4 {
            node.matrix_[0],
            node.matrix_[4],
            node.matrix_[8],
            node.matrix_[12],
            node.matrix_[1],
            node.matrix_[5],
            node.matrix_[9],
            node.matrix_[13],
            node.matrix_[2],
            node.matrix_[6],
            node.matrix_[10],
            node.matrix_[14],
            node.matrix_[3],
            node.matrix_[7],
            node.matrix_[11],
            node.matrix_[15],
        }
    } else {
        if node.has_scale {
            scale = m.vec3(node.scale)
        }
        if node.has_rotation {
            rotation =
            cast(m.quat)quaternion(w = node.rotation.w, x = node.rotation.x, y = node.rotation.y, z = node.rotation.z)
        }
        if node.has_translation {
            translation = m.vec3(node.translation)
        }
    }

    meshes := make([dynamic]Mesh, 0, 16)
    if node.mesh != nil {
        // we consider primitives to be different meshes
        for idx in 0 ..< len(node.mesh.primitives) {
            mesh, ok := process_mesh(
                &node.mesh.primitives[idx],
                materials,
                model_path,
                textures,
                len(node.mesh.weights),
            )
            if ok {
                copy(mesh.weights, node.mesh.weights)
                append(&meshes, mesh)
            }
        }
    }

    children := make([dynamic]Node, 0, 8)

    node_name_idx^ += 1
    for idx in 0 ..< len(node.children) {
        child := node.children[idx]
        if child == nil {
            continue
        }
        our_node := process_node(child, materials, model_path, textures, node_name_idx)
        append(&children, our_node)
    }

    return Node{id, name, meshes, transform, cast(bool)node.has_matrix, scale, translation, rotation, children}
}

@(private = "file")
new_mesh :: proc(
    primitive: cgltf.primitive_type,
    vertices: [dynamic]Vertex,
    indices: []u32,
    material_id: uintptr,
    weights_len: int,
    morph_targets: []MorphTarget,
) -> Mesh {
    context.logger = logger

    vertices := vertices
    indices := indices

    vao, vbo, ebo: u32

    usage: u32 = gl.STATIC_DRAW
    if len(morph_targets) != 0 {
        usage = gl.DYNAMIC_DRAW
    }

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * len(vertices), raw_data(vertices), usage)

    // positions
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

    // normals
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 3 * size_of(f32))

    // texcoords
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), 6 * size_of(f32))

    // tangents
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), 8 * size_of(f32))

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u32) * len(indices), raw_data(indices), gl.STATIC_DRAW)

    return Mesh{primitive, vertices, indices, material_id, make([]f32, weights_len), morph_targets, vao, vbo, ebo}
}

@(private = "file")
process_material :: proc(
    material: ^cgltf.material,
    model_path: string,
    textures_map: ^map[cstring]TextureId,
) -> Material {
    textures := make([dynamic]Texture, 0, 8)

    name := strings.clone_from_cstring(material.name)
    if material.name == nil {
        delete(name)
        name = fmt.aprintf("Material")
    }
    diffuse := m.vec4(material.pbr_metallic_roughness.base_color_factor)
    specular := m.vec3(material.specular.specular_color_factor)
    emissive := m.vec3(material.emissive_factor)
    shininess := material.specular.specular_factor != 0 ? material.specular.specular_factor : 32.0
    metallic := material.pbr_metallic_roughness.metallic_factor
    roughness := material.pbr_metallic_roughness.roughness_factor

    if material.has_emissive_strength {
        emissive *= material.emissive_strength.emissive_strength
    }

    // TODO: use ior if available to calculate the specular, otherwise default F0 to 0.04
    // TODO: specularGlossiness
    //ior := material.ior.ior

    if material.has_ior {
        log.debugf("ior: %f", material.ior.ior)
    }

    if material.has_specular {
        log.debugf("specular: %f", material.specular.specular_factor)
    }

    diffuse_tex := material.pbr_metallic_roughness.base_color_texture
    normal_tex := material.normal_texture
    emissive_tex := material.emissive_texture
    metallic_roughness_tex := material.pbr_metallic_roughness.metallic_roughness_texture

    if diffuse_tex.texture != nil {
        append(&textures, process_texture(diffuse_tex.texture, .DIFFUSE, model_path, textures_map))
    }

    if normal_tex.texture != nil {
        append(&textures, process_texture(normal_tex.texture, .NORMAL, model_path, textures_map))
    }

    if emissive_tex.texture != nil {
        append(&textures, process_texture(emissive_tex.texture, .EMISSIVE, model_path, textures_map))
    }

    if metallic_roughness_tex.texture != nil {
        append(
            &textures,
            process_texture(metallic_roughness_tex.texture, .METALLIC_ROUGHNESS, model_path, textures_map),
        )
    }

    return(
        Material {
            name,
            diffuse,
            specular,
            emissive,
            shininess,
            metallic,
            roughness,
            textures,
            cast(bool)material.double_sided,
            cast(bool)material.unlit,
            material.alpha_mode,
            material.alpha_cutoff,
        } \
    )
}

load_gltf_model :: proc(file_path: string) -> (Model, bool) {
    context.logger = logger

    file_path_cstr := strings.clone_to_cstring(file_path)
    defer delete(file_path_cstr)
    node_name_idx := 0

    start := time.now()
    data, res := cgltf.parse_file(cgltf.options{}, file_path_cstr)
    defer cgltf.free(data)

    if res != .success {
        log.errorf("Failed to load gltf file: \"%s\": %s", file_path, res)
        return Model{}, false
    }

    res = cgltf.load_buffers(cgltf.options{}, data, file_path_cstr)
    if res != .success {
        log.error("Failed to load gltf buffers")
        return Model{}, false
    }

    nodes := make([dynamic]Node, 0, 8)
    materials := make(map[uintptr]Material)
    textures_map := make(map[cstring]TextureId)
    defer delete(textures_map)

    materials[0] = DEFAULT_MATERIAL

    animations := make([]Animation, len(data.animations))
    for anim, a in data.animations {
        name := strings.clone_from_cstring(anim.name)
        if anim.name == nil {
            name = fmt.aprintf("Animation %d", a)
        }

        animation := Animation {
            name   = name,
            tracks = make([]AnimationTrack, len(anim.channels)),
            timer  = time.Stopwatch{},
        }

        for channel, t in anim.channels {
            if channel.target_node == nil {
                continue
            }

            animation.tracks[t].interpolation = channel.sampler.interpolation

            input := channel.sampler.input
            output := channel.sampler.output

            time := make([]f32, input.count)
            anim_data: []f32

            // input is always scalar
            process_accessor_scalar_float(input, time)

            animation.max_time = max(time[input.count - 1], animation.max_time)

            #partial switch output.type {
                case .vec4:
                    anim_data = make([]f32, output.count * 4)
                    process_accessor_vec4(output, anim_data)
                case .vec3:
                    anim_data = make([]f32, output.count * 3)
                    process_accessor_vec3(output, anim_data)
                case .scalar:
                    anim_data = make([]f32, output.count)
                    process_accessor_scalar_float(output, anim_data)
                case:
                    log.warnf("Unsupported animation sampler output type: %s", output.type)
            }

            animation.tracks[t].time = time
            animation.tracks[t].data = anim_data
            animation.tracks[t].node_id = transmute(uintptr)channel.target_node
            animation.tracks[t].property = channel.target_path
        }

        animations[a] = animation
    }

    for idx in 0 ..< len(data.scene.nodes) {
        node := process_node(data.scene.nodes[idx], &materials, file_path, &textures_map, &node_name_idx)
        append(&nodes, node)
    }

    log.debugf("Loading model took: %s", time.diff(start, time.now()))

    return Model{nodes, materials, {0, 0, 0}, {1, 1, 1}, {0, 1, 0}, 0, animations}, true
}
