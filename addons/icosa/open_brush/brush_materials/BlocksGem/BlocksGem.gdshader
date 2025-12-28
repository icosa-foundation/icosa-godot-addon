shader_type spatial;
render_mode blend_add, cull_back;

#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform float u_Shininess : hint_range(0.0, 1.0) = 0.8;
uniform float u_RimIntensity : hint_range(0.0, 5.0) = 1.0;
uniform float u_RimPower : hint_range(0.0, 10.0) = 4.0;
uniform vec4 u_Color : source_color = vec4(1.0);
uniform float u_Frequency : hint_range(0.0, 10.0) = 1.0;
uniform float u_Jitter : hint_range(0.0, 1.0) = 0.9;

global uniform vec4 u_SceneLight_0_color;
global uniform vec3 u_SceneLight_0_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying vec3 v_local_position;

void vertex() {
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_local_position = VERTEX;
}

// Voronoi noise implementation
#define K 0.142857142857
#define Ko 0.428571428571

vec3 Permutation(vec3 x) {
  return mod((34.0 * x + 1.0) * x, 289.0);
}

vec2 inoise(vec3 P, float jitter) {
  vec3 Pi = mod(floor(P), 289.0);
  vec3 Pf = fract(P);
  vec3 oi = vec3(-1.0, 0.0, 1.0);
  vec3 of = vec3(-0.5, 0.5, 1.5);
  vec3 px = Permutation(Pi.x + oi);
  vec3 py = Permutation(Pi.y + oi);

  vec3 p, ox, oy, oz, dx, dy, dz;
  vec2 F = vec2(1e6, 1e6);

  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      p = Permutation(px[i] + py[j] + Pi.z + oi);

      ox = fract(p * K) - Ko;
      oy = mod(floor(p * K), 7.0) * K - Ko;
      p = Permutation(p);

      oz = fract(p * K) - Ko;

      dx = Pf.x - of[i] + jitter * ox;
      dy = Pf.y - of[j] + jitter * oy;
      dz = Pf.z - of + jitter * oz;

      vec3 d = dx * dx + dy * dy + dz * dz;

      for (int n = 0; n < 3; n++) {
        if (d[n] < F[0]) {
          F[1] = F[0];
          F[0] = d[n];
        } else if (d[n] < F[1]) {
          F[1] = d[n];
        }
      }
    }
  }
  return F;
}

vec2 fBm_F0(vec3 p) {
  float freq = u_Frequency * 4.0;
  float amp = 0.5;
  vec2 F = inoise(p * freq, u_Jitter) * amp;
  return F;
}

void fragment() {
  vec3 normal = normalize(v_view_normal);

  // Get Voronoi
  vec2 F = fBm_F0(v_local_position);
  float gem = (F.y - F.x);

  // Perturb normal with voronoi cells
  float perturbIntensity = 50.0;
  normal.y += dFdy(gem) * perturbIntensity;
  normal.x += dFdx(gem) * perturbIntensity;
  normal = normalize(normal);

  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 eye_dir = -normalize(v_view_position);
  vec3 diffuseColor = vec3(0.0);

  // Artificial diffraction highlights
  vec3 refl = eye_dir - 2.0 * dot(eye_dir, normal) * normal + vec3(gem);
  vec3 colorRamp = vec3(1.0, 0.3, 0.0) * sin(refl.x * 30.0) + vec3(0.0, 1.0, 0.5) * cos(refl.y * 37.77) + vec3(0.0, 0.0, 1.0) * sin(refl.z * 43.33);

  vec3 specularColor = u_Color.rgb + colorRamp * 0.5;
  float smoothness = u_Shininess;

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuseColor, specularColor, smoothness);

  // Calculate rim lighting
  float viewAngle = clamp(dot(eye_dir, normal), 0.0, 1.0);
  float rim = pow(1.0 - viewAngle, u_RimPower);
  vec3 rimColor = vec3(rim) * u_RimIntensity;

  vec3 final_color = light_0 + rimColor;

  ALBEDO = final_color;
  ALPHA = 1.0;
}
