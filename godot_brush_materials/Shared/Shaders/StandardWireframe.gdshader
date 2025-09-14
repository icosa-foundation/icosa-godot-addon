// Converted from Unity shader: Assets/Resources/Brushes/Shared/Shaders/StandardWireframe.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode depth_test_disabled;



uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Main Color
uniform vec4 SpecColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Specular Color
uniform float Shininess : hint_range(0.01, 1) = 0.078125; // Shininess
uniform sampler2D MainTex : source_color; // Base (RGB) TransGloss (A) {}
uniform sampler2D BumpMap : source_color; // Normalmap {}
uniform float Cutoff : hint_range(0, 1) = 0.5; // Alpha cutoff

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    o.color = TbVertToNative(i.color);
      o.uv_MainTex = i.texcoord;
      o.uv_BumpMap = i.texcoord1;

      int corner;
      if (_VertOrder == 0) {
          corner = i.vid % 3;
      } else {
          corner = (((i.vid / 2)  + 1) / 2) % 3;
      }
      o.barycentric = float3(corner, corner, corner) == float3(0,1,2);
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
      o.Albedo = tex.rgb * _Color.rgb * IN.color.rgb;
      o.Smoothness = _Shininess;
      o.Specular = _SpecColor;
      o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
      o.Alpha = tex.a * IN.color.a;

      if (any(IN.barycentric < float3(0.02, 0.02, 0.02))) {
        o.Albedo = float4(1,1,1,1);
        o.Alpha = 1;
      }
    */
}

