// Toon shader - Pass 1: Main colored surface (cull_back)
shader_type spatial;
render_mode unshaded, depth_draw_always, cull_back;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

varying vec3 v_world_normal;
varying float v_fog_coord;

void vertex() {
  v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
  vec4 color = COLOR;

  // Add normal-based lighting (simulates ambient from top)
  color.xyz += v_world_normal.y * 0.2;
  color.xyz = max(vec3(0.0), color.xyz);

  vec3 final_color = apply_fog(color.xyz, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
