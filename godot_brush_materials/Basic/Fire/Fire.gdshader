// Converted from Unity shader: Assets/Resources/Brushes/Basic/Fire/Fire.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX

uniform sampler2D MainTex : source_color; // Particle Texture {}
uniform float Scroll1 : hint_range(0.0, 10.0) = 0; // Scroll1
uniform float Scroll2 : hint_range(0.0, 10.0) = 0; // Scroll2
uniform float DisplacementIntensity : hint_range(0.0, 10.0) = .1; // Displacement
uniform float EmissionGain : hint_range(0, 1) = 0.5; // Emission Gain
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
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
        v.color = TbVertToSrgb(v.color);
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
        o.color = bloomColor(v.color, _EmissionGain);
        o.pos = UnityObjectToClipPos(v.vertex);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
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

