// Converted from Unity shader: Assets/Resources/Brushes/Basic/WaveformParticles/WaveformParticles.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX
// // Unity UNITY_MATRIX_VP -> Godot PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX

uniform vec4 TintColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Tint Color
uniform sampler2D MainTex : source_color; // Particle Texture {}
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
    // TIME variable available in Godot
    float time_val = TIME;

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);

        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
        float3 perVertOffset = v.texcoord1.xyz;
        float lifetime = GetTime().y - v.texcoord1.w;
        o.lifetime = lifetime;
        float release = saturate(lifetime * .1);
        float3 localMidpointPos = v.vertex.xyz - perVertOffset;
        float4 worldMidpointPos = mul(unity_ObjectToWorld, localMidpointPos);

#ifdef AUDIO_REACTIVE
        lifetime = -lifetime*.1 + _BeatOutputAccum.x;

#endif

        float time = lifetime;
        float d = 10 + v.color.g * 3;
        float freq = 1.5 + v.color.r;
        float3 disp = float3(1,0,0) * curlX(worldMidpointPos.xyz * freq + time, d);
        disp += float3(0,1,0) * curlY(worldMidpointPos.xyz * freq +time, d);
        disp += float3(0,0,1) * curlZ(worldMidpointPos.xyz * freq + time, d);

        worldMidpointPos.xyz += release * disp * 10;
        worldPos.xyz = worldMidpointPos.xyz + perVertOffset;

        o.vertex = mul(UNITY_MATRIX_VP, worldPos);
        o.color = v.color;
        o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
        o.worldPos = worldPos.xyz;
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
        if (_Dissolve < 1 && Dither8x8(i.vertex.xy) >= _Dissolve) discard;
        #endif

        float4 c = i.color * _TintColor * tex2D(_MainTex, i.texcoord);
        c = encodeHdr(c.rgb * c.a);
        return c * _Opacity;
    */
}

