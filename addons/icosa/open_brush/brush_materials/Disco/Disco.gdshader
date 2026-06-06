shader_type spatial;
render_mode cull_back, unshaded, vertex_lighting;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform float u_Shininess : hint_range(0.0, 1.0) = 0.8;
uniform vec3 u_SpecColor : source_color = vec3(0.5);

uniform vec4 u_ambient_light_color;
uniform vec4 u_SceneLight_0_color;
uniform vec4 u_SceneLight_1_color;
uniform vec3 u_SceneLight_0_direction;
uniform vec3 u_SceneLight_1_direction;

//uniform vec4 time_override_value = vec4(.0,.0,.0,.0);
//uniform float time_blend = 0.0;
//uniform float time_speed = 1.0;
//uniform sampler2D waveform_texture;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying float v_fog_coord;

void vertex() {
	float t = TIME * 5.0;
	float tile_rate = 10.0;
	float wave_intensity = 0.01;
	
	// workaround, because we don't have acces to UV
	VERTEX += sin(t + VERTEX.z * tile_rate * 0.5) * BINORMAL * wave_intensity * 3.0;
	VERTEX += cos(t + VERTEX.z * tile_rate * 2.0) * TANGENT * wave_intensity * 1.0;
	//VERTEX += sin(t + VERTEX.x * tile_rate * 10.0) * NORMAL * wave_intensity * 0.25;
	//VERTEX += cos(t + VERTEX.y * tile_rate * 5.0) * TANGENT * wave_intensity * 0.25;
	v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_fog_coord = v_view_position.z;
	
	// Original code 
    //float theta = mod(UV.y, 1.0);
    //VERTEX += pow(1 -(sin(t + UV.x * tile_rate + theta * 10.0) + 1.0),2.0)
              //* v.normal.xyz * waveIntensity
              //* radius;
      //o.id = v.id;
    //}
	//

}

void fragment() {
  vec3 normal = normalize(v_view_normal);

  // Create faceted normal using derivatives for disco ball effect
  normal.x = dFdx(normal.x);
  vec3 faceted_normal = normalize(cross(dFdy(v_view_position), dFdx(v_view_position)));

  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);
  vec3 eye_dir = -normalize(v_view_position);

  vec3 diffuseColor = vec3(0.0);
  vec3 specularColor = COLOR.rgb + u_SpecColor;

  vec3 light_0 = surface_shader_specular_gloss(
    faceted_normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuseColor, specularColor, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, diffuseColor, u_SpecColor);

  vec3 ambient = diffuseColor * u_ambient_light_color.rgb;

  // Fake "disco ball" hot spot
  float fakeLightIntensity = pow(abs(dot(faceted_normal, vec3(0.0, 1.0, 0.0))), 10.0) * 20.0;
  vec3 fakeLight = vec3(fakeLightIntensity * specularColor);

  vec3 final_color = light_0 + light_1 + ambient + fakeLight;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  SPECULAR = 0.0;
  //ALBEDO = vec3(LIGHT_VERTEX.xyz);
  //ALPHA = 1.0;
}
