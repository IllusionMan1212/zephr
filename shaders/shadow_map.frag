#version 330 core

#define BIAS -0.011

void main() {
  // Empty fragment shader since we have no color buffer and the following line is what happens under the hood anyways.
  gl_FragDepth = gl_FragCoord.z;
  //gl_FragDepth += gl_FrontFacing ? BIAS : 0.0;
}
