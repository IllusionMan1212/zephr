out vec4 FragColor;
in vec4 aColor;
in vec2 aTexCoords;
in vec2 aBorder; // x - border thickness. y - border smoothness. Both in pixels.
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

// Function to compute the SDF for a rectangle
float rectangleSDF(vec2 p, float aspectRatio) {
    p.y *= aspectRatio;
    // Center the rectangle at (0.5, 0.5) in normalized space
    vec2 d = abs(p - vec2(0.5, 0.5 * aspectRatio)) - vec2(0.5, 0.5 * aspectRatio); // Distance from the center to the edges
    return max(d.x, d.y);
}

void main() {
  if (hasTexture) {
    FragColor = boxBlur(image);
    return;
  }

  float borderThickness = aBorder.x;
  float borderSmoothness = aBorder.y;

  float alpha = aColor.w;
  if (borderThickness != 0) {
    {
      // Compute the SDF for the rectangle
      float sdf = rectangleSDF(aTexCoords, rectSize.y / rectSize.x);

      // Convert border thickness to normalized space
      float borderWidthNormalized = borderThickness / rectSize.x;
      float smoothnessNormalized = borderSmoothness / rectSize.x;

      float edge0 = borderWidthNormalized - smoothnessNormalized * 2.0; // Inner edge of the smooth range
      float edge1 = borderWidthNormalized + smoothnessNormalized * 2.0;

      // Small bias for edge1 to prevent flip-flopping when edge0 is bigger or equal to edge1
      alpha = aColor.w - smoothstep(edge0, edge1 + 0.001, abs(sdf));

      if (alpha <= 0.0) {
        discard;
      }
    }
  }

  FragColor = vec4(aColor.xyz, alpha);
}
