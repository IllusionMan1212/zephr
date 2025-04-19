out vec4 FragColor;
in vec4 aColor;
in vec2 aTexCoords;
in vec3 aBorder; // x - border thickness. y - border smoothness. Both in pixels. z - border radius.
in vec2 rectSize;

uniform sampler2D image;
uniform int blur;
uniform bool hasTexture;

#define SEPARATION 1.0

// Working box blur.
vec4 boxBlur(sampler2D tex) {
  if (blur <= 0) { return texture(tex, aTexCoords) * aColor; }

  vec2 texSize = vec2(textureSize(tex, 0));
  vec4 avg = vec4(0.0);
  for (int x = -blur; x <= blur; x++) {
    for (int y = -blur; y <= blur; y++) {
      vec2 uv = clamp(aTexCoords + ((vec2(float(x), float(y)) * SEPARATION)) / texSize, vec2(0.0), vec2(1.0));
      avg += texture(tex, uv);
    }
  }

  avg /= pow(float(blur) * 2.0 + 1.0, 2.0);

  return avg * aColor;
}

float rect_sdf(vec2 pos, vec2 halfSize, float radius) {
    return length(max(abs(pos) - halfSize + radius, 0.0)) - radius;
}

void main() {
  if (hasTexture) {
    FragColor = boxBlur(image);
    return;
  }

  float borderThickness = aBorder.x;
  float borderSmoothness = aBorder.y;
  float borderRadius = aBorder.z;

  float alpha = aColor.a;

  vec2 uv = aTexCoords * rectSize;
  vec2 halfSize = rectSize * 0.5;
  float radius = clamp(borderRadius, 0.0, min(halfSize.x, halfSize.y));
  float borderSDF = 1.0;

  if (borderThickness > 0) {
      vec2 centeredPos = uv - halfSize; // Center UV space

      borderSDF = rect_sdf(centeredPos, halfSize - borderThickness, max(radius - borderThickness, 0));
      alpha *= smoothstep(0.0, 1.0, borderSDF);
  }

  vec2 cornerPos = abs(uv - halfSize);
  vec2 rectEdge = halfSize - vec2(radius); // where corners start
  vec2 cornerOffset = cornerPos - rectEdge;

  float smoothness = 1.0;

  // Only apply AA where both x and y are beyond the rectangle’s straight edges (i.e., in actual corners)
  if (cornerOffset.x > 0.0 && cornerOffset.y > 0.0) {
    float distToCorner = length(cornerOffset);
    alpha *= 1.0 - smoothstep(radius - smoothness, radius + smoothness, distToCorner);
  }

  FragColor = vec4(aColor.rgb, alpha);
}
