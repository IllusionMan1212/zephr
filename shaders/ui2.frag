#version 330 core

out vec4 FragColor;
in vec4 aColor;
in vec2 aTexCoords;

uniform sampler2D image;
uniform int blur;
uniform bool hasTexture;

#define SEPARATION 1

// Working box blur.
vec4 boxBlur(sampler2D tex) {
  if (blur <= 0) { return texture(tex, aTexCoords) * aColor; }

  vec2 texSize = textureSize(tex, 0);
  vec4 avg = vec4(0.0);
  for (int x = -blur; x <= blur; x++) {
    for (int y = -blur; y <= blur; y++) {
      vec2 uv = clamp(aTexCoords + ((vec2(x, y) * SEPARATION)) / texSize, vec2(0.0), vec2(1.0));
      avg += texture(tex, uv);
    }
  }

  avg /= pow(blur * 2 + 1, 2);

  return avg * aColor;
}

void main() {
  if (hasTexture) {
    FragColor = boxBlur(image);
  } else {
    FragColor = aColor;
  }
}
