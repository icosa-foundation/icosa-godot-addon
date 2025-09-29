// Converted from Unity shader: Assets/Resources/Brushes/Basic/CelVinyl/CelVinyl.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled;



uniform sampler2D MainTex : source_color; // MainTex {}
uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color
uniform float Cutoff : hint_range(0, 1) = 0.5; // Alpha Cutoff
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);

          v2f o;

          UNITY_SETUP_INSTANCE_ID(v);
          UNITY_INITIALIZE_OUTPUT(v2f, o);
          UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

          o.pos = UnityObjectToClipPos(v.vertex);
          o.texcoord = v.texcoord;
          o.color = TbVertToNative(v.color);
          o.id = (float2)v.id;
          UNITY_TRANSFER_FOG(o, o.pos);
          return o;
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    // tex2D(_MainTex, uv) -> texture(_MainTex, uv)
    ALBEDO = texture(MainTex, UV).rgb;
    // ALBEDO *= Color.rgb;
}

