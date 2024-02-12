#version 330 core

in vec3 fragPos;
in vec3 fragNormal;
in vec2 fragTexCoords;

out vec4 fragColor;

struct Material {
  sampler2D texture_diffuse;
  sampler2D texture_specular;
  sampler2D texture_normal;
  sampler2D texture_emissive;

  vec4 ambient;
  vec4 diffuse;
  vec3 specular;
  vec3 emissive;
  float shininess;
  float opacity;
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

#define NR_POINT_LIGHTS 4
#define BLINN_LIGHTING true

uniform vec3 viewPos;
uniform Material material;
uniform DirLight dirLight;
//uniform PointLight pointLights[NR_POINT_LIGHTS];
//uniform SpotLight spotLight;
uniform bool useTextures;
uniform bool hasEmissiveTexture;
//uniform bool isAABB;

vec3 CalculateDirLight(DirLight light, vec3 normal, vec3 viewDir) {
  vec3 lightDir = normalize(-light.direction);

  float diff = max(dot(lightDir, normal), 0.0);
  float spec = 0.0f;

  if (BLINN_LIGHTING) {
    vec3 halfwayDir = normalize(lightDir + viewDir);
    spec = pow(max(dot(normal, halfwayDir), 0.0), material.shininess);
  } else {
    vec3 reflectDir = reflect(-lightDir, normal);
    spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
  }

  vec3 ambient = vec3(0.0, 0.0, 0.0);
  vec3 diffuse = vec3(0.0, 0.0, 0.0);
  vec3 specular = vec3(0.0, 0.0, 0.0);

  if (useTextures) {
    ambient = light.ambient * vec3(texture(material.texture_diffuse, fragTexCoords)) * vec3(material.ambient);
    diffuse = light.diffuse * diff * vec3(texture(material.texture_diffuse, fragTexCoords)) * vec3(material.diffuse);
    specular = light.specular * spec * vec3(texture(material.texture_specular, fragTexCoords)) * vec3(material.specular);
  } else {
    ambient = light.ambient * vec3(material.ambient);
    diffuse = light.diffuse * (diff * vec3(material.diffuse));
    specular = light.specular * (spec * vec3(material.specular));
  }

  return (ambient + diffuse + specular);
}

void main() {
  // discard completely transparent fragments
  if (useTextures && texture(material.texture_diffuse, fragTexCoords).a == 0.0) {
    discard;
  }

  vec3 norm = normalize(fragNormal);
  vec3 viewDir = normalize(viewPos - fragPos);

  vec3 result = CalculateDirLight(dirLight, norm, viewDir);

  if (useTextures && hasEmissiveTexture) {
    result += texture(material.texture_emissive, fragTexCoords).rgb * material.emissive;
  } else {
    result += material.emissive;
  }

  fragColor = vec4(result, 1.0);
}
