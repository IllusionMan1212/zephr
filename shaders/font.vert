#version 330 core
layout (location = 0) in vec2 vertex;

// per instance
layout (location = 1) in vec4 offset; // x,y = position, z,w = size
layout (location = 2) in int tex_index;
layout (location = 3) in vec4 color;
layout (location = 4) in mat4 model; // this takes locations 4,5,6,7

out vec2 v_TexCoords;
out vec4 textColor;
uniform mat4 projection;
// buffer for all the 96 ascii characters' texcoords
// TODO: an ssbo would be good for this whenever we support unicode
uniform vec2 texcoords[96 * 4];

void main() {
  vec2 pos = vec2((vertex.x) * offset.z, (vertex.y) * offset.w);
  gl_Position = projection * model * vec4(pos + offset.xy, 0.0, 1.0);
  v_TexCoords = texcoords[tex_index * 4 + gl_VertexID];
  textColor = color;
}
