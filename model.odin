package zephr

import "core:intrinsics"
import "core:log"
import m "core:math/linalg/glsl"
import "core:strings"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:cgltf"

#assert(size_of(Vertex) == 48)
@(private = "file")
Vertex :: struct {
    position:   m.vec3,
    normal:     m.vec3,
    tex_coords: m.vec2,
    tangents:   m.vec4,
}

@(private)
Mesh :: struct {
    primitive: cgltf.primitive_type,
    vertices:  []Vertex,
    indices:   []u32,
    material:  Material,
    vao:       u32,
    vbo:       u32,
    ebo:       u32,
}

Node :: struct {
    name:      string,
    meshes:    [dynamic]Mesh,
    transform: m.mat4,
    children:  []Node,
}

Model :: struct {
    nodes:            [dynamic]Node,
    position:         m.vec3,
    scale:            m.vec3,
    rotation:         m.vec3,
    rotation_angle_d: f32,
}

@(private = "file")
process_mesh :: proc(
    primitive: ^cgltf.primitive,
    materials: ^map[string]Material,
    textures: ^map[cstring]TextureId,
) -> (
    Mesh,
    bool,
) {
    context.logger = logger

    vertices: [dynamic]Vertex
    indices: [dynamic]u32
    material: Maybe(Material)

    primitive_type := primitive.type
    if primitive.type != .triangles {
        log.warn("Got a primitive that isn't triangles")
    }
    if primitive.material != nil {
        primitive_material, ok := materials[string(primitive.material.name)]
        material = ok ? primitive_material : nil
    } else {
        material = nil
    }
    pos_arr := make([dynamic]f32, 0, 128)
    defer delete(pos_arr)
    norms_arr := make([dynamic]f32, 0, 128)
    defer delete(norms_arr)
    texcoords_arr := make([dynamic]f32, 0, 128)
    defer delete(texcoords_arr)
    tangents_arr := make([dynamic]f32, 0, 128)
    defer delete(tangents_arr)

    for a in 0 ..< len(primitive.attributes) {
        attribute := primitive.attributes[a]
        accessor := attribute.data
        offset_into_buf_view := accessor.offset
        offset_into_buffer := accessor.buffer_view.offset

        if attribute.type == .position {
            positions := intrinsics.ptr_offset(
                transmute([^]f32)accessor.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(f32),
            )
            if accessor.buffer_view.stride == 0 {
                append(&pos_arr, ..positions[:accessor.count * 3])
            } else {
                for i in 0 ..< accessor.count {
                    append(&pos_arr, positions[i * accessor.buffer_view.stride / size_of(f32)])
                    append(&pos_arr, positions[i * (accessor.buffer_view.stride / size_of(f32)) + 1])
                    append(&pos_arr, positions[i * (accessor.buffer_view.stride / size_of(f32)) + 2])
                }
            }
        } else if attribute.type == .normal {
            normals := intrinsics.ptr_offset(
                transmute([^]f32)accessor.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(f32),
            )
            if accessor.buffer_view.stride == 0 {
                append(&norms_arr, ..normals[:accessor.count * 3])
            } else {
                for i in 0 ..< accessor.count {
                    append(&norms_arr, normals[i * accessor.buffer_view.stride / size_of(f32)])
                    append(&norms_arr, normals[i * (accessor.buffer_view.stride / size_of(f32)) + 1])
                    append(&norms_arr, normals[i * (accessor.buffer_view.stride / size_of(f32)) + 2])
                }
            }
        } else if attribute.type == .texcoord {
            texcoords := intrinsics.ptr_offset(
                transmute([^]f32)accessor.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(f32),
            )
            if accessor.buffer_view.stride == 0 {
                append(&texcoords_arr, ..texcoords[:accessor.count * 2])
            } else {
                for i in 0 ..< accessor.count {
                    append(&texcoords_arr, texcoords[i * accessor.buffer_view.stride / size_of(f32)])
                    append(&texcoords_arr, texcoords[i * (accessor.buffer_view.stride / size_of(f32)) + 1])
                }
            }
        } else if attribute.type == .tangent {
            tangents := intrinsics.ptr_offset(
                transmute([^]f32)accessor.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(f32),
            )
            if accessor.buffer_view.stride == 0 {
                append(&tangents_arr, ..tangents[:accessor.count * 4])
            } else {
                for i in 0 ..< accessor.count {
                    append(&tangents_arr, tangents[i * accessor.buffer_view.stride / size_of(f32)])
                    append(&tangents_arr, tangents[i * (accessor.buffer_view.stride / size_of(f32)) + 1])
                    append(&tangents_arr, tangents[i * (accessor.buffer_view.stride / size_of(f32)) + 2])
                    append(&tangents_arr, tangents[i * (accessor.buffer_view.stride / size_of(f32)) + 3])
                }
            }
        }
    }

    if len(norms_arr) == 0 {
        log.error("No normals found")
        return Mesh{}, false
    }

    if len(tangents_arr) == 0 {
        log.warn("No tangents found. This will cause issue with normal mapping and lighting.")
    }

    for i in 0 ..< len(pos_arr) / 3 {
        tex_coords := len(texcoords_arr) != 0 ? m.vec2{texcoords_arr[i * 2], texcoords_arr[i * 2 + 1]} : m.vec2{0, 0}
        tangents :=
            len(tangents_arr) != 0 \
            ? m.vec4{tangents_arr[i * 4], tangents_arr[i * 4 + 1], tangents_arr[i * 4 + 2], tangents_arr[i * 4 + 3]} \
            : m.vec4{0, 0, 0, 0}
        append(
            &vertices,
            Vertex {
                position = m.vec3{pos_arr[i * 3], pos_arr[i * 3 + 1], pos_arr[i * 3 + 2]},
                normal = m.vec3{norms_arr[i * 3], norms_arr[i * 3 + 1], norms_arr[i * 3 + 2]},
                tex_coords = tex_coords,
                tangents = tangents,
            },
        )
    }

    if primitive.indices == nil {
        log.error("No indices found")
        return Mesh{}, false
    }

    offset_into_buf_view := primitive.indices.offset
    offset_into_buffer := primitive.indices.buffer_view.offset

    #partial switch primitive.indices.component_type {
        case .r_8u:
            indices_slice := intrinsics.ptr_offset(
                transmute([^]u8)primitive.indices.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(u8),
            )
            for i in 0 ..< primitive.indices.count {
                append(&indices, cast(u32)indices_slice[i])
            }
        case .r_16u:
            indices_slice := intrinsics.ptr_offset(
                transmute([^]u16)primitive.indices.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(u16),
            )
            for i in 0 ..< primitive.indices.count {
                append(&indices, cast(u32)indices_slice[i])
            }
        case .r_32u:
            indices_slice := intrinsics.ptr_offset(
                transmute([^]u32)primitive.indices.buffer_view.buffer.data,
                (offset_into_buf_view + offset_into_buffer) / size_of(u32),
            )
            append(&indices, ..indices_slice[:primitive.indices.count])
        case:
            log.warn("Unsupported index type")
    }

    return new_mesh(primitive_type, vertices[:], indices[:], material), true
}

@(private = "file")
process_node :: proc(node: ^cgltf.node, materials: ^map[string]Material, textures: ^map[cstring]TextureId) -> Node {
    context.logger = logger

    name := strings.clone_from_cstring(node.name)
    if node.name == nil {
        //name = fmt.tprintf("node_%d", idx)
        name = "node"
    }
    transform := m.identity(m.mat4)
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
            transform = m.mat4Scale(m.vec3(node.scale)) * transform
        }
        if node.has_rotation {
            rot_mat := m.mat4FromQuat(
                quaternion(w = node.rotation.w, x = node.rotation.x, y = node.rotation.y, z = node.rotation.z),
            )
            transform = rot_mat * transform
        }
        if node.has_translation {
            transform = m.mat4Translate(m.vec3(node.translation)) * transform
        }
    }

    meshes := make([dynamic]Mesh, 0, 16)
    if node.mesh != nil {
        // we consider primitives to be different meshes
        for idx in 0 ..< len(node.mesh.primitives) {
            mesh, ok := process_mesh(&node.mesh.primitives[idx], materials, textures)
            if ok {
                append(&meshes, mesh)
            }
        }
    }

    children := make([dynamic]Node, 0, 8)

    for idx in 0 ..< len(node.children) {
        child := node.children[idx]
        our_node := process_node(child, materials, textures)
        append(&children, our_node)
    }

    return Node{name, meshes, transform, children[:]}
}

@(private = "file")
new_mesh :: proc(
    primitive: cgltf.primitive_type,
    vertices: []Vertex,
    indices: []u32,
    material: Maybe(Material),
) -> Mesh {
    context.logger = logger

    vertices := vertices
    indices := indices

    vao, vbo, ebo: u32

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)

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

    material, ok := material.?

    return Mesh{primitive, vertices, indices, ok ? material : DEFAULT_MATERIAL, vao, vbo, ebo}
}

load_gltf_model :: proc(file_path: cstring) -> (Model, bool) {
    context.logger = logger

    now := time.now()
    data, res := cgltf.parse_file(cgltf.options{}, file_path)
    defer cgltf.free(data)

    if res != .success {
        log.errorf("Failed to load gltf file: \"%s\": %s", file_path, res)
        return Model{}, false
    }

    res = cgltf.load_buffers(cgltf.options{}, data, file_path)
    if res != .success {
        log.error("Failed to load gltf buffers")
        return Model{}, false
    }

    nodes := make([dynamic]Node, 0, 8)
    materials := make(map[string]Material)
    defer delete(materials)
    textures_map := make(map[cstring]TextureId)
    defer delete(textures_map)

    for material in data.materials {
        textures := make([dynamic]Texture, 0, 4)

        name := strings.clone_from_cstring(material.name)
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
            append(&textures, process_texture(diffuse_tex.texture, .DIFFUSE, file_path, &textures_map))
        }

        if normal_tex.texture != nil {
            append(&textures, process_texture(normal_tex.texture, .NORMAL, file_path, &textures_map))
        }

        if emissive_tex.texture != nil {
            append(&textures, process_texture(emissive_tex.texture, .EMISSIVE, file_path, &textures_map))
        }

        if metallic_roughness_tex.texture != nil {
            append(
                &textures,
                process_texture(metallic_roughness_tex.texture, .METALLIC_ROUGHNESS, file_path, &textures_map),
            )
        }

        materials[name] = Material {
            name,
            diffuse,
            specular,
            emissive,
            shininess,
            metallic,
            roughness,
            textures[:],
            cast(bool)material.double_sided,
            cast(bool)material.unlit,
            material.alpha_mode,
            material.alpha_cutoff,
        }
    }

    for idx in 0 ..< len(data.scene.nodes) {
        node := process_node(data.scene.nodes[idx], &materials, &textures_map)
        append(&nodes, node)
    }

    log.debugf("Loading model took: %s", time.diff(now, time.now()))

    return Model{nodes = nodes, scale = {1, 1, 1}, rotation = {1, 1, 1}}, true
}
