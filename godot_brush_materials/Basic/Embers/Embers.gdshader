// Converted from Unity shader: Assets/Resources/Brushes/Basic/Embers/Embers.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX
// // Unity UNITY_MATRIX_VP -> Godot PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX

uniform vec4 TintColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Tint Color
uniform sampler2D MainTex : source_color; // Particle Texture {}
uniform float ScrollRate : hint_range(0.0, 10.0) = 1.0; // Scroll Rate
uniform vec4 ScrollDistance = vec4(0.0, 0.0, 0.0, 0.0); // Scroll Distance
uniform float ScrollJitterIntensity : hint_range(0.0, 10.0) = 1.0; // Scroll Jitter Intensity
uniform float ScrollJitterFrequency : hint_range(0.0, 10.0) = 1.0; // Scroll Jitter Frequency
uniform float SpreadRate : hint_range(0.3, 5) = 1.539; // Spread Rate
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
    // TIME variable available in Godot
    float time_val = TIME;

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    v.color = TbVertToSrgb(v.color);
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        // Used as a random-ish seed for various calculations
        float seed = v.color.a;
        float t01 = fmod(GetTime().y*_ScrollRate + seed * 10, 1);
        float birthTime = v.texcoord.w;
        float rotation = v.texcoord.z;
        float halfSize = GetParticleHalfSize(v.corner.xyz, v.center, birthTime);
        float spreadProgress = SpreadProgress(birthTime, _SpreadRate);
        float4 center = SpreadParticle(v, spreadProgress);
        float3 disp = ComputeDisplacement(center.xyz, seed, t01);
        disp = spreadProgress * disp;

        // Ramp color from bright to dark over particle lifetime
        float3 incolor = v.color.rgb;
        float t_minus_1 = 1-t01;
        float sparkle = (pow(abs(sin(GetTime().y * 3 + seed * 10)), 30));
        v.color.rgb += pow(t_minus_1,10)*incolor*200;
        v.color.rgb += incolor * sparkle * 50;

#ifdef AUDIO_REACTIVE
        // Additional color boost from beat detection
        v.color.rgb = v.color.rgb * .5 + 2*_BeatOutput.x * v.color.rgb;
#endif

        // Dim over lifetime
        v.color.rgb *= incolor * pow (1 - t01, 2)*5;

        // Custom vertex animation
#if 1
        // Displacement is in scene space
        // Note that xf_CS is actually scene, not canvas
        // The problem with this is that if you scale up a layer, the particles
        // get big but the overall motion stays the same.
        float4 center_WS = mul(unity_ObjectToWorld, center);
        center_WS.xyz += mul(xf_CS, float4(disp, 0));
        PrepForOdsWorldSpace(center_WS);
        float4 corner_WS = OrientParticle_WS(center_WS.xyz, halfSize, v.vid, rotation);
        o.vertex = mul(UNITY_MATRIX_VP, corner_WS);
#else
        // Displacement is in canvas space
        // Note that we assume object space == canvas space (which it is, for TB)
        PrepForOds(center);
        center = center + float4(disp.xyz, 0);
        float4 corner = OrientParticle(center.xyz, halfSize, v.vid, rotation);
        o.vertex = UnityObjectToClipPos(corner);
#endif

        o.color = v.color;
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
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(i.id.x > _ClipStart && i.id.x < _ClipEnd)) discard;
        // It's hard to get alpha curves right so use dithering for hdr shaders
        if (_Dissolve < 1 && Dither8x8(i.vertex.xy) >= _Dissolve) discard;
        #endif

        float4 texCol = tex2D(_MainTex, i.texcoord);
        float4 color = 2.0f * i.color * _TintColor * texCol;
        color = encodeHdr(color.rgb * color.a);
        color = SrgbToNative(color);
#if SELECTION_ON
        color.rgb = GetSelectionColor() * texCol.a;
#endif
        return color * _Dissolve;
    */
}

