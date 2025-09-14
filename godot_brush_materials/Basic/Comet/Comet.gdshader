// Converted from Unity shader: Assets/Resources/Brushes/Basic/Comet/Comet.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME

uniform sampler2D MainTex : source_color; // Texture {}
uniform sampler2D AlphaMask : source_color; // Alpha Mask {}
uniform float Speed : hint_range(0, 1) = 1; // Animation Speed
uniform float EmissionGain : hint_range(0, 1) = 0.5; // Emission Gain
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Opacity : hint_range(0, 1) = 1; // Opacity
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot
    // Unity TRANSFORM_TEX -> manual UV transform
    // UV = UV * _MainTex_ST.xy + _MainTex_ST.zw;
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
        o.color = TbVertToNative(v.color);

#ifdef AUDIO_REACTIVE
        float3 displacement = _BeatOutput.y * v.normal *
            saturate((1.0 - smoothstep(0, .3, v.texcoord.x)) * v.texcoord.z);
        v.vertex.xyz += displacement;
#endif
        o.pos = UnityObjectToClipPos(v.vertex);
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

