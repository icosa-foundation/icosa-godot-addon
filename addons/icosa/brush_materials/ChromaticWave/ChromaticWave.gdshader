shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.405;

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

void fragment() {
  vec4 unbloomedColor = COLOR;
  vec4 bloomedColor = bloom_color(COLOR, u_EmissionGain);
  vec2 texcoord = UV;

  float envelope = sin(texcoord.x * 3.14159);
  texcoord.y += texcoord.x * 3.0;

  // Unity's _Time.w = time*3, so we need TIME*3.0 in Godot
  float time_w = TIME * 3.0;

  float waveform_r = 0.15 * sin(-20.0 * unbloomedColor.r * time_w + texcoord.x * 100.0 * unbloomedColor.r);
  float waveform_g = 0.15 * sin(-30.0 * unbloomedColor.g * time_w + texcoord.x * 100.0 * unbloomedColor.g);
  float waveform_b = 0.15 * sin(-40.0 * unbloomedColor.b * time_w + texcoord.x * 100.0 * unbloomedColor.b);

  texcoord.y = mod(texcoord.y + texcoord.x, 1.0);
  texcoord.y = mod(texcoord.y + texcoord.x, 1.0);

  float procedural_line_r = clamp(1.0 - 40.0 * abs(texcoord.y - 0.5 + waveform_r), 0.0, 1.0);
  float procedural_line_g = clamp(1.0 - 40.0 * abs(texcoord.y - 0.5 + waveform_g), 0.0, 1.0);
  float procedural_line_b = clamp(1.0 - 40.0 * abs(texcoord.y - 0.5 + waveform_b), 0.0, 1.0);

  vec4 color = procedural_line_r * vec4(1.0, 0.0, 0.0, 0.0) +
               procedural_line_g * vec4(0.0, 1.0, 0.0, 0.0) +
               procedural_line_b * vec4(0.0, 0.0, 1.0, 0.0);
  color.a = 1.0;
  color = bloomedColor * color;

  ALBEDO = color.rgb * color.a;
  ALPHA = 1.0;
}
