#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;
layout (location = 3) in vec4 tangent;

out vec3 fragPos;
out vec3 fragNormal;
out vec2 fragTexCoords;
out mat3 TBN;

#define MAX_WEIGHT_COUNT 512

uniform highp sampler2DArray morphTargets;
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform bool useMorphing;
uniform bool hasMorphTargetNormals;
uniform bool hasMorphTargetTangents;
uniform int morphTargetNormalsOffset;
uniform int morphTargetsCount;
uniform int morphTargetTangentsOffset;
uniform float morphTargetWeights[MAX_WEIGHT_COUNT];

void main() {
    vec3 pos = position;
    vec3 norm = normal;
    vec4 tan = tangent;

    if (useMorphing) {
        int texSize = textureSize(morphTargets, 0)[0];
        int x = gl_VertexID % texSize;
        int y = (gl_VertexID - x) / texSize;
        for (int i = 0; i < morphTargetsCount; i++) {
            vec3 morphedPos = texelFetch(morphTargets, ivec3(x, y, i), 0).xyz;
            pos += morphedPos * morphTargetWeights[i];

            if (hasMorphTargetNormals) {
                vec3 morphedNorm = texelFetch(morphTargets, ivec3(x, y, i + morphTargetNormalsOffset), 0).xyz;
                norm += morphedNorm * morphTargetWeights[i];
            }

            if (hasMorphTargetTangents) {
                vec3 morphedTan = texelFetch(morphTargets, ivec3(x, y, i + morphTargetTangentsOffset), 0).xyz;
                tan.xyz += morphedTan * morphTargetWeights[i];
            }
        }
    }

    gl_Position = projection * view * model * vec4(pos, 1.0f);
    fragNormal = mat3(transpose(inverse(model))) * norm;
    fragPos = vec3(model * vec4(pos, 1.0));
    fragTexCoords = texCoords;

    vec3 T = normalize(vec3(model * vec4(tan.xyz, 0.0)));
    vec3 N = normalize(vec3(model * vec4(norm, 0.0)));
    // re-orthogonalize T with respect to N
    T = normalize(T - dot(T, N) * N);
    vec3 B = cross(N, T) * tan.w;
    TBN = mat3(T, B, N);
}
