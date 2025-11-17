shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

// WaveformFFT shader - Audio-reactive waveform visualization
// Based on WaveformFFT-d120944d-772f-4062-99c6-46a6f219eeaf

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 2.0) = 0.5;

varying vec4 v_color;
varying vec4 v_unbloomed_color;

vec4 bloom_color(vec4 color, float gain) {
  float cmin = length(color.rgb) * 0.05;
  color.rgb = max(color.rgb, vec3(cmin));
  color.r = pow(color.r, 2.2);
  color.g = pow(color.g, 2.2);
  color.b = pow(color.b, 2.2);
  color.a = pow(color.a, 2.2);
  color.rgb *= 2.0 * exp(gain * 10.0);
  return color;
}

vec4 get_waveform(vec2 texcoord, vec4 bloomed_color, vec4 unbloomed_color) {
  // Envelope
  float envelope = sin(texcoord.x * 3.14159);

  // Multi-frequency waveform based on color channels
  float waveform = 0.15 * sin(-30.0 * unbloomed_color.r * TIME + texcoord.x * 100.0 * unbloomed_color.r);
  waveform += 0.15 * sin(-40.0 * unbloomed_color.g * TIME + texcoord.x * 100.0 * unbloomed_color.g);
  waveform += 0.15 * sin(-50.0 * unbloomed_color.b * TIME + texcoord.x * 100.0 * unbloomed_color.b);

  float pinch = (1.0 - envelope) * 40.0 + 20.0;
  float procedural_line = clamp(1.0 - pinch * abs(texcoord.y - 0.5 - waveform * envelope), 0.0, 1.0);

  vec4 color = vec4(1.0);
  color.rgb *= envelope * procedural_line;
  color = bloomed_color * color;
  return color;
}

void vertex() {
  v_color = bloom_color(COLOR, u_EmissionGain);
  v_unbloomed_color = COLOR;
}

void fragment() {
  vec4 waveform = get_waveform(UV, v_color, v_unbloomed_color);

  ALBEDO = waveform.rgb * waveform.a * 5.0;
  ALPHA = waveform.a;
}
