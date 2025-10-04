shader_type spatial;
render_mode blend_add, cull_back;

#include "res://addons/icosa/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;

global uniform vec4 u_ambient_light_color;
global uniform vec4 u_SceneLight_0_color;
global uniform vec4 u_SceneLight_1_color;
global uniform vec3 u_SceneLight_0_direction;
global uniform vec3 u_SceneLight_1_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying vec3 v_world_position;
varying vec3 v_world_normal;

void vertex() {
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Amplitude reflection coefficient (s-polarized)
float rs(float n1, float n2, float cosI, float cosT) {
  return (n1 * cosI - n2 * cosT) / (n1 * cosI + n2 * cosT);
}

// Amplitude reflection coefficient (p-polarized)
float rp(float n1, float n2, float cosI, float cosT) {
  return (n2 * cosI - n1 * cosT) / (n1 * cosT + n2 * cosI);
}

// Amplitude transmission coefficient (s-polarized)
float ts(float n1, float n2, float cosI, float cosT) {
  return 2.0 * n1 * cosI / (n1 * cosI + n2 * cosT);
}

// Amplitude transmission coefficient (p-polarized)
float tp(float n1, float n2, float cosI, float cosT) {
  return 2.0 * n1 * cosI / (n1 * cosT + n2 * cosI);
}

float thinFilmReflectance(float cos0, float lambda, float thickness, float n0, float n1, float n2) {
  float PI = 3.1415926536;

  // Phase change terms
  float d10 = mix(PI, 0.0, float(n1 > n0));
  float d12 = mix(PI, 0.0, float(n1 > n2));
  float delta = d10 + d12;

  // Cosine of the reflected angle
  float sin1 = pow(n0 / n1, 2.0) * (1.0 - pow(cos0, 2.0));

  // Total internal reflection
  if (sin1 > 1.0) return 1.0;
  float cos1 = sqrt(1.0 - sin1);

  // Cosine of the final transmitted angle
  float sin2 = pow(n0 / n2, 2.0) * (1.0 - pow(cos0, 2.0));

  // Total internal reflection
  if (sin2 > 1.0) return 1.0;

  float cos2 = sqrt(1.0 - sin2);

  // Reflection transmission amplitude Fresnel coefficients
  float alpha_s = rs(n1, n0, cos1, cos0) * rs(n1, n2, cos1, cos2);
  float alpha_p = rp(n1, n0, cos1, cos0) * rp(n1, n2, cos1, cos2);

  float beta_s = ts(n0, n1, cos0, cos1) * ts(n1, n2, cos1, cos2);
  float beta_p = tp(n0, n1, cos0, cos1) * tp(n1, n2, cos1, cos2);

  // Compute the phase term
  float phi = (2.0 * PI / lambda) * (2.0 * n1 * thickness * cos1) + delta;

  // Evaluate transmitted intensity for both polarizations
  float ts_intensity = pow(beta_s, 2.0) / (pow(alpha_s, 2.0) - 2.0 * alpha_s * cos(phi) + 1.0);
  float tp_intensity = pow(beta_p, 2.0) / (pow(alpha_p, 2.0) - 2.0 * alpha_p * cos(phi) + 1.0);

  // Conservation of energy
  float beamRatio = (n2 * cos2) / (n0 * cos0);

  // Average transmitted intensity
  float t = beamRatio * (ts_intensity + tp_intensity) / 2.0;

  // Derive reflected intensity
  return 1.0 - t;
}

vec3 GetDiffraction(vec3 thickTex, vec3 I, vec3 N) {
  const float thicknessMin = 250.0;
  const float thicknessMax = 400.0;
  const float nmedium = 1.0;
  const float nfilm = 1.3;
  const float ninternal = 1.0;

  float cos0 = abs(dot(I, N));

  float t = (thickTex.r + thickTex.g + thickTex.b) / 3.0;
  float thick = thicknessMin * (1.0 - t) + thicknessMax * t;

  float red = thinFilmReflectance(cos0, 650.0, thick, nmedium, nfilm, ninternal);
  float green = thinFilmReflectance(cos0, 510.0, thick, nmedium, nfilm, ninternal);
  float blue = thinFilmReflectance(cos0, 475.0, thick, nmedium, nfilm, ninternal);

  return vec3(red, green, blue);
}

void fragment() {
  // Hardcode shiny specular values
  float shininess = 0.8;
  vec3 albedo = COLOR.rgb * 0.2;

  // Calculate rim
  vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_position);
  vec3 normal = normalize(v_view_normal);

  if (!FRONT_FACING) {
    normal *= -1.0;
  }

  float rim = 1.0 - abs(dot(view_dir, normalize(v_world_normal)));
  rim *= 1.0 - pow(rim, 5.0);

  rim = mix(rim, 150.0,
            1.0 - clamp(abs(dot(view_dir, normalize(v_world_normal))) / 0.1, 0.0, 1.0));

  // Unity's _Time.x = time/20, so we need TIME/20.0 in Godot
  float time_x = TIME / 20.0;
  vec3 diffraction = texture(u_MainTex, vec2(rim + time_x * 0.3 + normal.x, rim + normal.y)).xyz;
  diffraction = GetDiffraction(diffraction, normal, view_dir);

  vec3 emission = rim * COLOR.rgb * diffraction * 0.5 + rim * diffraction * 0.25;
  vec3 specColor = COLOR.rgb * clamp(diffraction, 0.0, 1.0);

  // Lighting
  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, albedo, specColor, shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, albedo, specColor);

  vec3 ambient = albedo * u_ambient_light_color.rgb;

  vec3 final_color = light_0 + light_1 + ambient + emission;

  ALBEDO = final_color;
  ALPHA = 1.0;
}
