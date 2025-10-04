// Toon shader - Pass 2: Black outline (cull_front, inflated geometry)
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_test_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform float u_OutlineMax : hint_range(0.0, 0.5) = 0.005;

varying float v_fog_coord;

void vertex() {
  float outlineEnabled = 1.0;
  float radius = 1.0;

  #ifdef CUSTOM0
  radius = CUSTOM0.z;
  #else
  // If no CUSTOM0, use a reasonable default based on vertex scale
  radius = length(VERTEX) * 0.01;
  #endif

  float inflate = outlineEnabled * radius * 0.4;

  // Transform to clip space
  vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
  vec4 outline_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX + NORMAL * inflate, 1.0);

  // Displacement in NDC coords
  vec3 disp = outline_clip.xyz / outline_clip.w - clip_pos.xyz / clip_pos.w;

  // Clamp outline width in NDC space
  float mag = length(disp.xy);
  if (mag > 0.0) {
    mag = min(u_OutlineMax, mag) / mag;
  } else {
    mag = 1.0;
  }

  // Apply displacement back in clip space
  clip_pos.xyz += vec3(disp.xy * mag, disp.z) * clip_pos.w * outlineEnabled;

  // Push Z back to avoid z-fighting (subtract = push away from camera in clip space)
  clip_pos.z -= disp.z * clip_pos.w * outlineEnabled;

  POSITION = clip_pos;
  v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
  vec3 outline_color = vec3(0.0, 0.0, 0.0);
  vec3 final_color = apply_fog(outline_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
