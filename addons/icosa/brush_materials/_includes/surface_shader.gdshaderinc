// surface_shader.gdshaderinc
// Disney BRDF lighting (Unity-compatible)

const float INV_PI = 0.318309886;
const vec3 GAMMA_DIELECTRIC_SPEC = vec3(0.220916301);
const float GAMMA_ONE_MINUS_DIELECTRIC = 0.779083699;

float pow5(float x) {
  return x * x * x * x * x;
}

float disney_diffuse_term(float NdotV, float NdotL, float LdotH, float perceptual_roughness) {
  float fd90 = 0.5 + 2.0 * LdotH * LdotH * perceptual_roughness;
  float light_scatter = 1.0 + (fd90 - 1.0) * pow5(1.0 - NdotL);
  float view_scatter  = 1.0 + (fd90 - 1.0) * pow5(1.0 - NdotV);
  return light_scatter * view_scatter;
}

float smith_joint_visibility_term(float NdotL, float NdotV, float roughness) {
  float lambdaV = NdotL * mix(NdotV, 1.0, roughness);
  float lambdaL = NdotV * mix(NdotL, 1.0, roughness);
  return 0.5 / (lambdaV + lambdaL + 1e-5);
}

float ggx_distribution_term(float NdotH, float roughness) {
  float a2 = roughness * roughness;
  float d = (NdotH * a2 - NdotH) * NdotH + 1.0;
  return INV_PI * a2 / (d * d + 1e-7);
}

vec3 fresnel_term(vec3 F0, float cosA) {
  float t = pow5(1.0 - cosA);
  return F0 + (vec3(1.0) - F0) * t;
}

vec3 surface_shader_internal(
    vec3 normal,
    vec3 light_dir,
    vec3 eye_dir,
    vec3 light_color,
    vec3 diffuse_color,
    vec3 specular_color,
    float perceptual_roughness) {

  float NdotL = clamp(dot(normal, light_dir), 0.0, 1.0);
  float NdotV = abs(dot(normal, eye_dir));

  vec3 half_vector = normalize(light_dir + eye_dir);
  float NdotH = clamp(dot(normal, half_vector), 0.0, 1.0);
  float LdotH = clamp(dot(light_dir, half_vector), 0.0, 1.0);

  float diffuse_term = NdotL * disney_diffuse_term(NdotV, NdotL, LdotH, perceptual_roughness);

  if (length(specular_color) < 1e-5) {
    return diffuse_color * (light_color * diffuse_term);
  }

  float roughness = perceptual_roughness * perceptual_roughness;
  float V = ggx_distribution_term(NdotH, roughness);
  float D = smith_joint_visibility_term(NdotL, NdotV, roughness);
  float specular_term = V * D * PI;

  specular_term = sqrt(max(1e-4, specular_term));
  specular_term *= NdotL;

  vec3 fresnel_color = fresnel_term(specular_color, LdotH);

  return light_color * (diffuse_term * diffuse_color + specular_term * fresnel_color);
}

vec3 surface_shader_specular_gloss(
    vec3 normal,
    vec3 light_dir,
    vec3 eye_dir,
    vec3 light_color,
    vec3 albedo_color,
    vec3 specular_color,
    float gloss) {

  float one_minus_spec = 1.0 - clamp(max(max(specular_color.r, specular_color.g), specular_color.b), 0.0, 1.0);
  vec3 diffuse_color = albedo_color * one_minus_spec;
  float perceptual_roughness = 1.0 - gloss;

  return surface_shader_internal(normal, light_dir, eye_dir, light_color, diffuse_color, specular_color, perceptual_roughness);
}

vec3 sh_shader_with_spec(vec3 normal, vec3 light_dir, vec3 light_color, vec3 diffuse_color, vec3 specular_color) {
  float spec_gray = dot(specular_color, vec3(0.3, 0.59, 0.11));
  float NdotL = clamp(dot(normal, light_dir), 0.0, 1.0);
  float sh_multiplier = 1.0 - spec_gray;
  sh_multiplier *= sh_multiplier;
  return diffuse_color * light_color * NdotL * sh_multiplier;
}
