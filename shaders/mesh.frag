#version 330 core

in vec3 fragPos;
in vec3 fragNormal;
in vec2 fragTexCoords;
in mat3 TBN;

out vec4 fragColor;

struct Material {
  sampler2D texture_diffuse;
  sampler2D texture_specular;
  sampler2D texture_normal;
  sampler2D texture_emissive;
  sampler2D texture_metallic_roughness;

  vec4 diffuse;
  vec3 specular;
  vec3 emissive;
  float metallic;
  float roughness;
  float shininess;
};

struct DirLight {
  vec3 direction;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

struct PointLight {
  vec3 position;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;

  float constant;
  float linear;
  float quadratic;
};

struct SpotLight {
  vec3 position;
  vec3 direction;
  float cutOff;
  float outerCutOff;

  vec3 ambient;
  vec3 diffuse;
  vec3 specular;

  float constant;
  float linear;
  float quadratic;
};

#define NR_POINT_LIGHTS 2
#define GAMMA 2.2
#define PI 3.14159265359

#define ALPHAMODE_OPAQUE 0
#define ALPHAMODE_MASK 1
#define ALPHAMODE_BLEND 2

uniform vec3 viewPos;
uniform Material material;
uniform DirLight dirLight;
uniform PointLight pointLights[NR_POINT_LIGHTS];
uniform bool useTextures;
uniform bool hasDiffuseTexture;
uniform bool hasEmissiveTexture;
uniform bool hasNormalTexture;
uniform bool hasMetallicRoughnessTexture;
uniform bool doubleSided;
uniform bool unlit;
uniform float alphaCutoff;
uniform int alphaMode;

// This calculates the ratio between specular/reflected and diffuse/refracted light
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float distributionGGX(vec3 N, vec3 H, float roughness) {
  float a = roughness * roughness;
  float a2 = a * a;
  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH * NdotH;

  float num = a2;
  float denom = (NdotH2 * (a2 - 1.0) + 1.0);
  denom = PI * denom * denom;

  return num / denom;
}

float geometrySchlickGGX(float NdotV, float roughness) {
  float r = (roughness + 1.0);
  float k = (r * r) / 8.0;

  float num = NdotV;
  float denom = NdotV * (1.0 - k) + k;

  return num / denom;
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
  float NdotV = max(dot(N, V), 0.0);
  float NdotL = max(dot(N, L), 0.0);
  float ggx2 = geometrySchlickGGX(NdotV, roughness);
  float ggx1 = geometrySchlickGGX(NdotL, roughness);

  return ggx1 * ggx2;
}

vec3 F_Schlick(vec3 f0, vec3 f90, float VdotH)
{
    return f0 + (f90 - f0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

float F_Schlick(float f0, float f90, float VdotH)
{
    float x = clamp(1.0 - VdotH, 0.0, 1.0);
    float x2 = x * x;
    float x5 = x * x2 * x2;
    return f0 + (f90 - f0) * x5;
}

float F_Schlick(float f0, float VdotH)
{
    float f90 = 1.0; //clamp(50.0 * f0, 0.0, 1.0);
    return F_Schlick(f0, f90, VdotH);
}

vec3 F_Schlick(vec3 f0, float f90, float VdotH)
{
    float x = clamp(1.0 - VdotH, 0.0, 1.0);
    float x2 = x * x;
    float x5 = x * x2 * x2;
    return f0 + (f90 - f0) * x5;
}

vec3 F_Schlick(vec3 f0, float VdotH)
{
    float f90 = 1.0; //clamp(dot(f0, vec3(50.0 * 0.33)), 0.0, 1.0);
    return F_Schlick(f0, f90, VdotH);
}

vec3 BRDF_lambertian(vec3 f0, vec3 f90, vec3 diffuseColor, float specularWeight, float VdotH) {
    return (1.0 - specularWeight * F_Schlick(f0, f90, VdotH)) * (diffuseColor / PI);
}

float V_GGX(float NdotL, float NdotV, float alphaRoughness)
{
    float alphaRoughnessSq = alphaRoughness * alphaRoughness;

    float GGXV = NdotL * sqrt(NdotV * NdotV * (1.0 - alphaRoughnessSq) + alphaRoughnessSq);
    float GGXL = NdotV * sqrt(NdotL * NdotL * (1.0 - alphaRoughnessSq) + alphaRoughnessSq);

    float GGX = GGXV + GGXL;
    if (GGX > 0.0)
    {
        return 0.5 / GGX;
    }
    return 0.0;
}


// The following equation(s) model the distribution of microfacet normals across the area being drawn (aka D())
// Implementation from "Average Irregularity Representation of a Roughened Surface for Ray Reflection" by T. S. Trowbridge, and K. P. Reitz
// Follows the distribution function recommended in the SIGGRAPH 2013 course notes from EPIC Games [1], Equation 3.
float D_GGX(float NdotH, float alphaRoughness)
{
    float alphaRoughnessSq = alphaRoughness * alphaRoughness;
    float f = (NdotH * NdotH) * (alphaRoughnessSq - 1.0) + 1.0;
    return alphaRoughnessSq / (PI * f * f);
}

vec3 BRDF_specularGGX(vec3 f0, vec3 f90, float alphaRoughness, float specularWeight, float VdotH, float NdotL, float NdotV, float NdotH)
{
    vec3 F = F_Schlick(f0, f90, VdotH);
    float Vis = V_GGX(NdotL, NdotV, alphaRoughness);
    float D = D_GGX(NdotH, alphaRoughness);

    return specularWeight * F * Vis * D;
}

vec3 specular_brdf(vec3 specular, vec3 viewDir, vec3 lightDir, vec3 normal, float roughness) {
  vec3 halfwayDir = normalize(viewDir + lightDir);
  vec3 F = fresnelSchlick(max(dot(halfwayDir, viewDir), 0.0), specular);
  float NDF = distributionGGX(normal, halfwayDir, roughness);
  float G = geometrySmith(normal, viewDir, lightDir, roughness);

  return F * NDF * G / (4 * max(dot(normal, viewDir), 0.0) * max(dot(normal, lightDir), 0.0));
}

vec3 diffuse_brdf(vec3 diffuse) {
  return (1 / PI) * diffuse;
}

vec3 CalculateDirLight(vec3 albedo, float metallic, float roughness, DirLight light, vec3 normal, vec3 viewDir) {
  vec3 lightDir = normalize(-light.direction);

  vec3 halfwayDir = normalize(lightDir + viewDir);
  vec3 radiance = light.diffuse;

  //float VdotH = dot(viewDir, halfwayDir);
  //float NdotL = max(dot(normal, lightDir), 0.0);
  //float NdotV = max(dot(normal, viewDir), 0.0);
  //float NdotH = max(dot(normal, halfwayDir), 0.0);
  //vec3 c_diff = mix(albedo, vec3(0), metallic);
  //float alphaRoughness = roughness * roughness;
  //float specularWeight = 1.0;
  //vec3 F0 = mix(vec3(0.04), albedo, metallic);

  //vec3 diffuse = radiance * NdotL * BRDF_lambertian(F0, vec3(1), c_diff, specularWeight, VdotH);
  //vec3 specular = radiance * NdotL * BRDF_specularGGX(F0, vec3(1), alphaRoughness, specularWeight, VdotH, NdotL, NdotV, NdotH);

  //vec3 ambient = vec3(0.03) * albedo;
  //vec3 color = diffuse + specular + ambient;

  // ----------------------------------------

  vec3 F0 = vec3(0.04);
  F0 = mix(F0, albedo, metallic);

  float NDF = distributionGGX(normal, halfwayDir, roughness);
  float G = geometrySmith(normal, viewDir, lightDir, roughness);
  vec3 F = fresnelSchlick(max(dot(halfwayDir, viewDir), 0.0), F0);

  vec3 numerator = NDF * G * F;
  // we add 0.0001 to prevent division by zero
  float denominator = 4.0 * max(dot(normal, viewDir), 0.0) * max(dot(normal, lightDir), 0.0) + 0.0001;
  vec3 specular = numerator / denominator;

  vec3 kS = F;
  vec3 kD = vec3(1.0) - kS;

  kD *= 1.0 - metallic;

  float NdotL = max(dot(normal, lightDir), 0.0);
  vec3 Lo = (kD * albedo / PI + specular) * radiance * NdotL;

  vec3 ambient = vec3(0.03) * albedo;
  vec3 color = ambient + Lo;

  // tone mapping because color can get very bright
  color = color / (color + vec3(1.0));

  return color;
}

vec3 CalculatePointLights(vec3 albedo, float metallic, float roughness, vec3 normal, vec3 viewDir) {
  vec3 Lo = vec3(0.0);

  for (int i = 0; i < NR_POINT_LIGHTS; i++) {
    vec3 lightDir = normalize(pointLights[i].position - fragPos);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float distance = length(pointLights[i].position - fragPos);
    float attenuation = 1.0 / (distance * distance);
    vec3 radiance = pointLights[i].diffuse * attenuation;

    //float VdotH = dot(viewDir, halfwayDir);
    //float NdotL = max(dot(normal, lightDir), 0.0);
    //float NdotV = max(dot(normal, viewDir), 0.0);
    //float NdotH = max(dot(normal, halfwayDir), 0.0);
    //vec3 c_diff = mix(albedo, vec3(0), metallic);
    //float alphaRoughness = roughness * roughness;
    //float specularWeight = 1.0;
    //vec3 F0 = mix(vec3(0.04), albedo, metallic);

    //vec3 diffuse = radiance * NdotL * BRDF_lambertian(F0, vec3(1), c_diff, specularWeight, VdotH);
    //vec3 specular = radiance * NdotL * BRDF_specularGGX(F0, vec3(1), alphaRoughness, specularWeight, VdotH, NdotL, NdotV, NdotH);

    //vec3 ambient = vec3(0.03) * albedo;
    //Lo += diffuse + specular + ambient;

    // -------------------------------------------

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, metallic);

    float NDF = distributionGGX(normal, halfwayDir, roughness);
    float G = geometrySmith(normal, viewDir, lightDir, roughness);
    vec3 F = fresnelSchlick(max(dot(halfwayDir, viewDir), 0.0), F0);

    vec3 numerator = NDF * G * F;
    // we add 0.0001 to prevent division by zero
    float denominator = 4.0 * max(dot(normal, viewDir), 0.0) * max(dot(normal, lightDir), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;

    kD *= 1.0 - metallic;

    float NdotL = max(dot(normal, lightDir), 0.0);
    Lo += (kD * albedo / PI + specular) * radiance * NdotL;
  }

  vec3 ambient = vec3(0.03) * albedo;
  vec3 color = ambient + Lo;

  // tone mapping because color can get very bright
  color = color / (color + vec3(1.0));

  return color;
}

void main() {
  // TODO: multiply baseColor with vertex color too but idc about that for now

  vec4 baseColor = material.diffuse;
  if (hasDiffuseTexture) {
    baseColor *= texture(material.texture_diffuse, fragTexCoords);
  }

  if (alphaMode == ALPHAMODE_MASK) {
    if (hasDiffuseTexture && texture(material.texture_diffuse, fragTexCoords).a < alphaCutoff) {
      discard;
    } else if (material.diffuse.a < alphaCutoff) {
      discard;
    }
  } else if (alphaMode == ALPHAMODE_OPAQUE) {
    baseColor.a = 1.0;
  }

  if (unlit) {
    vec3 result = baseColor.rgb;

    if (useTextures && hasEmissiveTexture) {
      result += texture(material.texture_emissive, fragTexCoords).rgb * material.emissive;
    } else {
      result += material.emissive;
    }

    fragColor = vec4(pow(result, vec3(1.0 / GAMMA)), baseColor.a);

    return;
  }

  vec3 norm = normalize(fragNormal);

  if (hasNormalTexture) {
    vec3 normal = texture(material.texture_normal, fragTexCoords).rgb;
    normal = normal * 2.0 - 1.0;
    norm = normalize(TBN * normal);
  }

  vec3 albedo = material.diffuse.rgb;
  float metallic = material.metallic;
  float roughness = material.roughness;

  if (hasDiffuseTexture) {
    // Convert from sRGB to linear because PBR requires us to work in linear space
    albedo *= pow(texture(material.texture_diffuse, fragTexCoords).rgb, vec3(GAMMA));
  }

  if (hasMetallicRoughnessTexture) {
    vec4 metallic_roughness = texture(material.texture_metallic_roughness, fragTexCoords);
    metallic *= metallic_roughness.b;
    roughness *= metallic_roughness.g;
  }

  // GLTF 2.0 spec says the normal MUST be flipped if the mesh is double sided
  if (doubleSided && gl_FrontFacing == false) {
    norm = -norm;
  }

  vec3 viewDir = normalize(viewPos - fragPos);

  vec3 result = CalculateDirLight(albedo, metallic, roughness, dirLight, norm, viewDir);
  result += CalculatePointLights(albedo, metallic, roughness, norm, viewDir);

  if (hasEmissiveTexture) {
    result += texture(material.texture_emissive, fragTexCoords).rgb * material.emissive;
  } else {
    result += material.emissive;
  }

  vec3 gammaCorrected = pow(result, vec3(1.0/GAMMA));

  fragColor = vec4(gammaCorrected, baseColor.a);
}
