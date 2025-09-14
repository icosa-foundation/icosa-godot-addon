// Converted from Unity shader: Assets/Shaders/FlatLit.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode blend_mix;

// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX
// // Unity _WorldSpaceCameraPos -> Godot CAMERA_POSITION_WORLD

uniform sampler2D MainTex : source_color; // Texture {}
uniform float Smoothness : hint_range(0, 1) = 0.5; // Smoothness
uniform float Metallic : hint_range(0, 1) = 0; // Metallic
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    v2f o;

      UNITY_SETUP_INSTANCE_ID(v);
      UNITY_INITIALIZE_OUTPUT(v2f, o);
      UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

      o.uv = v.uv  * _MainTex_ST.xy + _MainTex_ST.zw;
      o.pos = UnityObjectToClipPos(v.vertex);
      o.worldPos = mul(unity_ObjectToWorld, v.vertex);
      o.color = v.color;
      TRANSFER_SHADOW(o);

      // normal is set in geom method

      o.id = (float2)v.id;
      return o;
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    // tex2D(_MainTex, uv) -> texture(_MainTex, uv)
    ALBEDO = texture(MainTex, UV).rgb;
    // ALBEDO *= Color.rgb;
}

