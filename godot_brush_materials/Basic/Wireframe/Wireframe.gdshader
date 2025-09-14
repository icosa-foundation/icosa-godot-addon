// Converted from Unity shader: Assets/Resources/Brushes/Basic/Wireframe/Wireframe.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;



uniform float Opacity : hint_range(0, 1) = 1; // Opacity
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);

        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.texcoord = v.texcoord;
        o.color = v.color;
        o.vertex = UnityObjectToClipPos(v.vertex);
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

