// TubeToonInverted - Pass 1: Black front faces (cull_back)
shader_type spatial;
render_mode unshaded, blend_mix, cull_back;

varying vec3 v_world_normal;

void vertex() {
  v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
  vec4 color = COLOR;

  // Add normal-based lighting
  color.xyz += v_world_normal.y * 0.2;
  color.a = 1.0;

  // Front faces are black
  ALBEDO = vec3(0.0, 0.0, 0.0);
  ALPHA = 1.0;
}
