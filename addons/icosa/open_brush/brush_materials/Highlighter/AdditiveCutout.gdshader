shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Opacity : hint_range(0.0, 1.0) = 1;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float u_Feather : hint_range(0.0, 8.0) = 1.0;

varying float v_fog_coord;

void vertex() {
  v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
  // Alpha-only texture (use .w channel)
  float brush_mask = texture(u_MainTex, UV).a;
  brush_mask *= COLOR.a;

  ALBEDO = COLOR.rgb;
  ALPHA = smoothstep(u_Cutoff - length(fwidth(UV) * u_Feather), u_Cutoff + length(fwidth(UV) * u_Feather), brush_mask) * u_Opacity;
}
