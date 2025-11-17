shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;

varying float v_fog_coord;

void vertex() {
  v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
  vec4 brush_tex = texture(u_MainTex, UV);

  // VelvetInk uses texture alpha as a mask for the vertex color
  vec3 final_color = brush_tex.a * COLOR.rgb;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
