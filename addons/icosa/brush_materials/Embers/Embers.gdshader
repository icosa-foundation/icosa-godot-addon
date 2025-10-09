shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(1.0);
uniform float u_ScrollRate : hint_range(0.0, 5.0) = 0.3;
uniform vec3 u_ScrollDistance = vec3(0.0, 3.0, 0.0);
uniform float u_ScrollJitterIntensity : hint_range(0.0, 2.0) = 1.0;
uniform float u_ScrollJitterFrequency : hint_range(0.0, 20.0) = 3.0;

varying vec4 v_color;

const float kRecipSquareRootOfTwo = 0.70710678;

// Given a centerpoint and vertex corner, create a camera-facing quad
vec3 recreate_corner(vec3 center_view, float corner, float rotation, float size) {
  float c = cos(rotation);
  float s = sin(rotation);

  // Basis in camera/view space
  vec3 up = vec3(s, c, 0.0);
  vec3 right = vec3(c, -s, 0.0);

  // Corner layout: 0=bottom-left, 1=bottom-right, 2=top-left, 3=top-right
  float f_up = (corner == 0.0 || corner == 1.0) ? -1.0 : 1.0;
  float f_right = (corner == 0.0 || corner == 2.0) ? -1.0 : 1.0;

  vec3 result = center_view;
  result += f_right * right * size;
  result += f_up * up * size;
  return result;
}

void vertex() {
  float time_y = TIME;

  vec4 custom0 = CUSTOM0;
  vec3 center_OS = custom0.yzw;
  float vertex_id = custom0.x;
  float rotation = TANGENT.z;

  float corner = mod(vertex_id, 4.0);
  float halfSize_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  vec3 basis_y = MODEL_MATRIX[1].xyz;
  float scale = max(length(basis_y), 0.0001);

  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  vec3 center_view = (modelview_mat * vec4(center_OS, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, halfSize_OS * scale);
  vec3 vertex_obj = (inv_modelview_mat * vec4(vertex_view, 1.0)).xyz;

  float particle_id = COLOR.a;
  float t = mod(time_y * u_ScrollRate + particle_id * 10.0, 1.0);

  vec3 world_pos = (MODEL_MATRIX * vec4(vertex_obj, 1.0)).xyz;
  vec3 disp_world = (MODEL_MATRIX * vec4(u_ScrollDistance, 0.0)).xyz * t;
  float jitter_x = sin(t * u_ScrollJitterFrequency + particle_id * 100.0 + time_y + world_pos.z) * u_ScrollJitterIntensity;
  float jitter_y = (mod(particle_id * 100.0, 1.0) - 0.5) * u_ScrollDistance.y * t;
  float jitter_z = cos(t * u_ScrollJitterFrequency + particle_id * 100.0 + time_y + world_pos.x) * u_ScrollJitterIntensity;
  disp_world += vec3(jitter_x, jitter_y, jitter_z);
  disp_world *= 0.1;
  vec3 world_pos_final = world_pos + disp_world;
  vec3 vertex_final_OS = (inverse(MODEL_MATRIX) * vec4(world_pos_final, 1.0)).xyz;

  vec3 in_color = COLOR.rgb;
  float t_minus_1 = 1.0 - t;
  float sparkle = pow(abs(sin(time_y * 3.0 + particle_id * 10.0)), 30.0);

  v_color.rgb = in_color;
  v_color.rgb += pow(t_minus_1, 10.0) * in_color * 200.0;
  v_color.rgb += in_color * sparkle * 50.0;
  v_color.rgb *= in_color * pow(1.0 - t, 2.0) * 5.0;
  v_color.a = 1.0;

  VERTEX = vertex_final_OS;
}


void fragment() {
  vec4 color = 2.0 * v_color * u_TintColor * texture(u_MainTex, UV);

  ALBEDO = color.rgb;
  ALPHA = color.a;
}
