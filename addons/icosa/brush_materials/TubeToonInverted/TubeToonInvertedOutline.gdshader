// TubeToonInverted - Pass 2: Colored back faces with inflation (cull_front)
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_test_disabled;

varying vec3 v_world_normal;

void vertex() {
  // Scale-based inflation - converts 0.05 units from canvas space to object space
  // Unity: float scale = length(mul(xf_I_CS, float3(0.05, 0, 0)));
  vec3 canvas_vec = (inverse(MODEL_MATRIX) * vec4(0.05, 0.0, 0.0, 0.0)).xyz;
  float scale = length(canvas_vec);

  // Inflate along normal
  VERTEX = VERTEX + NORMAL * scale;

  v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
  vec4 color = COLOR;

  // Add normal-based lighting
  color.xyz += v_world_normal.y * 0.2;
  color.a = 1.0;

  ALBEDO = color.xyz;
  ALPHA = 1.0;
}
