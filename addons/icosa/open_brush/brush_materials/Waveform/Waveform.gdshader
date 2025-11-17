shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;

varying vec4 v_color;
varying vec4 v_unbloomed_color;

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
  v_color = bloom_color(COLOR, u_EmissionGain);
  v_unbloomed_color = COLOR;
}

vec4 get_waveform(vec2 texcoord) {
  // Unity's _Time.w = time*3, so we need TIME*3.0 in Godot
  float time_w = TIME * 3.0;

  // Envelope
  float envelope = sin(texcoord.x * 3.14159);

  float waveform = 0.15 * sin(-30.0 * v_unbloomed_color.r * time_w + texcoord.x * 100.0 * v_unbloomed_color.r);
  waveform += 0.15 * sin(-40.0 * v_unbloomed_color.g * time_w + texcoord.x * 100.0 * v_unbloomed_color.g);
  waveform += 0.15 * sin(-50.0 * v_unbloomed_color.b * time_w + texcoord.x * 100.0 * v_unbloomed_color.b);

  float pinch = (1.0 - envelope) * 40.0 + 20.0;
  float procedural_line = clamp(1.0 - pinch * abs(texcoord.y - 0.5 - waveform * envelope), 0.0, 1.0);

  vec4 color = vec4(1.0);
  color.rgb *= envelope * procedural_line;
  color = v_color * color;

  return color;
}

void fragment() {
  vec4 final_color = get_waveform(UV);

  ALBEDO = final_color.rgb;
  ALPHA = final_color.a;
}
