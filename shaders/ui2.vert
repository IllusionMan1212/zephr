#version 330 core
// per-instance data
layout (location = 0) in vec4 rect; // x,y is point 0, zw is point 1
layout (location = 1) in vec4 color;

out vec4 aColor;
uniform mat4 projection;
//uniform mat4 model;

void main() {
  float x = gl_VertexID / 2;
  float y = gl_VertexID % 2;
  vec2 vertex = vec2(x, y);
  vec2 size = rect.zw - rect.xy;
  vec2 pos = rect.xy + vertex * size;
  gl_Position = projection * vec4(pos, 0.0, 1.0);
  aColor = color;
}
