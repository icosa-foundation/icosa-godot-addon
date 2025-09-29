// Converted from Unity shader: Assets/Resources/Brushes/Basic/Smoke/Smoke.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix, blend_add;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX
// // Unity UNITY_MATRIX_VP -> Godot PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX

uniform vec4 TintColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Tint Color
uniform sampler2D MainTex : source_color; // Particle Texture {}
uniform float ScrollRate : hint_range(0.0, 10.0) = 1.0; // Scroll Rate
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Opacity : hint_range(0, 1) = 1; // Opacity
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity TRANSFORM_TEX -> manual UV transform
    // UV = UV * _MainTex_ST.xy + _MainTex_ST.zw;
    COLOR = COLOR; // Unity color space conversion
    // TIME variable available in Godot
    float time_val = TIME;

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    v.color = TbVertToSrgb(v.color);
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        float birthTime = v.texcoord.w;
        float rotation = v.texcoord.z;
        float halfSize = GetParticleHalfSize(v.corner.xyz, v.center, birthTime);
        float4 center = float4(v.center.xyz, 1);
        float4 center_WS = mul(unity_ObjectToWorld, center);

        float t = GetTime().y*_ScrollRate + v.color.a * 10;
        float time = GetTime().x * 5;
        float d = 30;
        float freq = .1;
        float3 disp = float3(1,0,0) * curlX(center_WS.xyz * freq + time, d);
        disp += float3(0,1,0) * curlY(center_WS.xyz * freq +time, d);
        disp += float3(0,0,1) * curlZ(center_WS.xyz * freq + time, d);
        disp = disp * 5 * kDecimetersToWorldUnits;

        center_WS.xyz += mul(xf_CS, float4(disp, 0));

        PrepForOdsWorldSpace(center_WS);
        float4 corner = OrientParticle_WS(center_WS.xyz, halfSize, v.vid, rotation);
        o.pos = mul(UNITY_MATRIX_VP, corner);

        o.color = v.color;
        v.color.a = 1;
        o.texcoord = TRANSFORM_TEX(v.texcoord.xy,_MainTex);
        o.id = (float2)v.id;

        return o;
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    ALPHA = main_tex.a;
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic
    ALPHA *= Opacity;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(i.id.x > _ClipStart && i.id.x < _ClipEnd)) discard;
        if (_Dissolve < 1 && Dither8x8(i.pos.xy) >= _Dissolve) discard;
        #endif

        float4 c =  tex2D(_MainTex, i.texcoord);
        c *= i.color * _TintColor;
        c = SrgbToNative(c);
#if SELECTION_ON
        float strength = length(c.rgb * c.a) * 3;
        FRAG_MOBILESELECT(c)
        c.rgb *= strength;
#endif
        c.a *= _Opacity;
        return c;
    */
}

