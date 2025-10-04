shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 u_ColorX : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 u_ColorY : source_color = vec3(0.0, 1.0, 0.0);
uniform vec3 u_ColorZ : source_color = vec3(0.0, 0.0, 1.0);

varying vec3 v_world_pos;

void vertex() {
  v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
  // Create faceted normal using derivatives (ddx/ddy)
  vec3 n = normalize(cross(dFdy(v_world_pos), dFdx(v_world_pos)));

  // Blend three colors based on normal direction
  vec3 color = vec3(0.0);
  color += mix(vec3(0.0), u_ColorX, n.x);
  color += mix(vec3(0.0), u_ColorY, n.y);
  color += mix(vec3(0.0), u_ColorZ, n.z);

  ALBEDO = color * COLOR.rgb;
  ALPHA = 1.0;
}
