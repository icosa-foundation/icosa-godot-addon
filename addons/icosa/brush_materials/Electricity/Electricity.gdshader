shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.2;
uniform float u_DisplacementIntensity : hint_range(0.0, 2.0) = 1.0;

varying vec4 v_color;

vec4 bloom_color(vec4 color, float gain) {
  // Guarantee that there's at least a little bit of all 3 channels.
  // This makes fully-saturated strokes (which only have 2 non-zero
  // color channels) eventually clip to white rather than to a secondary.
  float cmin = length(color.rgb) * 0.05;
  color.rgb = max(color.rgb, vec3(cmin, cmin, cmin));
  // If we try to remove this pow() from .a, it brightens up
  // pressure-sensitive strokes; looks better as-is.
  color.r = pow(color.r, 2.2);
  color.g = pow(color.g, 2.2);
  color.b = pow(color.b, 2.2);
  color.a = pow(color.a, 2.2);
  color.rgb *= 2.0 * exp(gain * 10.0);
  return color;
}

void vertex() {
  // Unity's _Time.w = time*3, so we need TIME*3.0 in Godot
  float time_w = TIME * 3.0;

  // Envelope for tapering at stroke edges
  float envelope = sin(UV.x * 3.14159);
  float envelope_pow = 1.0 - pow(1.0 - envelope, 10.0);

  // TEXCOORD_1 (vec3) displacement stored in CUSTOM1
  // GLTF importer maps _TEXCOORD_1 -> _CUSTOM1, accessible as CUSTOM1
  vec3 disp_vec = CUSTOM1.xyz;
  vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

  // Add animated noise to displacement
  disp_vec.x += sin(VERTEX.z * 100.0 + time_w * 13.0) * 0.05;
  disp_vec.y += cos(VERTEX.x * 120.0 + time_w * 10.0) * 0.05;
  disp_vec.z += cos(VERTEX.y * 80.0 + time_w * 7.0) * 0.05;

  disp_vec = (MODEL_MATRIX * vec4(disp_vec, 0.0)).xyz;
  world_pos += disp_vec * u_DisplacementIntensity * envelope_pow;

  VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

  // Boost color at edges
  v_color = COLOR;
  v_color += COLOR * (1.0 - envelope_pow);
}

void fragment() {
  vec4 color = bloom_color(v_color, u_EmissionGain);

  // Procedural brightness in center of ribbon
  float procedural = (abs(UV.y - 0.5) < 0.2) ? 2.0 : 0.0;
  vec4 c = color + color * procedural;

  ALBEDO = c.rgb * c.a;
  ALPHA = c.a;
}
