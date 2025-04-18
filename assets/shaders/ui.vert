// per-instance data
layout (location = 0) in vec4 rect; // x,y is point 0, zw is point 1
layout (location = 1) in vec4 color00;
layout (location = 2) in vec4 color01;
layout (location = 3) in vec4 color10;
layout (location = 4) in vec4 color11;
layout (location = 5) in vec2 border; // x - border thickness. y - border smoothness

out vec4 aColor;
out vec2 aTexCoords;
out vec2 aBorder;
out vec2 rectSize;
uniform mat4 projection;

void main() {
  float x = float(gl_VertexID / 2);
  float y = float(gl_VertexID % 2);
  vec2 vertex = vec2(x, y);
  vec2 size = rect.zw - rect.xy;
  vec2 pos = rect.xy + vertex * size;
  gl_Position = projection * vec4(pos, 0.0, 1.0);
  vec4 colors[4] = vec4[](
    color00,
    color01,
    color10,
    color11
  );
  aColor = colors[gl_VertexID];
  aTexCoords = vec2(x, y);
  aBorder = border;
  rectSize = rect.zw - rect.xy;
}
