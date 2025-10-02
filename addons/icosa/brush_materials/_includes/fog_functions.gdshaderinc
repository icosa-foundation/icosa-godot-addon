// fog_functions.gdshaderinc
// Exponential fog matching Unity/Open Brush behavior

uniform vec3 u_fogColor : source_color = vec3(1.0);
uniform float u_fogDensity : hint_range(0.0, 1.0) = 0.0;

vec3 apply_fog(vec3 color, float fog_coord) {
  // Unity fog density conversion
  float density = (u_fogDensity / 0.693147) * 10.0;
  float fog_factor = fog_coord * density;
  fog_factor = exp2(-fog_factor);
  fog_factor = clamp(fog_factor, 0.0, 1.0);
  return mix(u_fogColor, color, fog_factor);
}
