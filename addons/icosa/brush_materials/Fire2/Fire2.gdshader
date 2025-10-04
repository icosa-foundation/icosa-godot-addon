shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform sampler2D u_DisplaceTex : source_color, filter_linear_mipmap;
uniform float u_Scroll1 : hint_range(0.0, 30.0) = 15.0;
uniform float u_Scroll2 : hint_range(0.0, 30.0) = 2.5;
uniform float u_DisplacementIntensity : hint_range(0.0, 1.0) = 0.04;
uniform float u_FlameFadeMin : hint_range(0.0, 10.0) = 5.0;
uniform float u_FlameFadeMax : hint_range(0.0, 10.0) = 5.0;

void fragment() {
  // Unity's _Time.x = time/20, so we need TIME/20.0 in Godot
  float time_x = TIME / 20.0;

  vec2 displacement;
  float flame_fade_mix = 0.0;

  // Sample displacement texture
  displacement = texture(u_DisplaceTex, UV).xy;
  displacement = displacement * 2.0 - 1.0;
  displacement *= u_DisplacementIntensity;

  // Sample mask from MainTex y channel
  float mask = texture(u_MainTex, UV).y;

  // Apply displacement to UV coordinates
  vec2 uv = UV;
  uv += displacement;

  // Sample flame textures with scrolling animation
  float flame1 = texture(u_MainTex, uv * 0.7 + vec2(-time_x * u_Scroll1, 0.0)).x;
  float flame2 = texture(u_MainTex, vec2(uv.x, 1.0 - uv.y) + vec2(-time_x * u_Scroll2, -time_x * u_Scroll2 / 4.0)).x;

  // Combine flames
  float flames = clamp((flame2 + flame1) / 2.0, 0.0, 1.0);
  flames = smoothstep(0.0, 0.8, mask * flames);
  flames *= mask;

  // Create flame texture
  vec4 tex = vec4(flames, flames, flames, 1.0);
  float flame_fade = mix(u_FlameFadeMin, u_FlameFadeMax, flame_fade_mix);

  // Apply flame fade along stroke
  tex.xyz *= pow(1.0 - UV.x, flame_fade) * (flame_fade * 2.0);

  // Final color calculation
  vec4 color = COLOR * tex;

  // Boost brightness
  color.rgb *= color.a * 15.0;

  ALBEDO = color.rgb;
  ALPHA = 1.0;
}
