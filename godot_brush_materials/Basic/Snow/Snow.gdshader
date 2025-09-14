// Converted from Unity shader: Assets/Resources/Brushes/Basic/Snow/Snow.shader
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
uniform vec4 ScrollDistance = vec4(0.0, 0.0, 0.0, 0.0); // Scroll Distance
uniform float ScrollJitterIntensity : hint_range(0.0, 10.0) = 1.0; // Scroll Jitter Intensity
uniform float ScrollJitterFrequency : hint_range(0.0, 10.0) = 1.0; // Scroll Jitter Frequency
uniform float SpreadRate : hint_range(0.3, 5) = 1.539; // Spread Rate
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
    v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        v.color = TbVertToSrgb(v.color);
        float birthTime = v.texcoord.w;
        float rotation = v.texcoord.z;
        float halfSize = GetParticleHalfSize(v.corner.xyz, v.center, birthTime);
        float spreadProgress = SpreadProgress(birthTime, _SpreadRate);
        float4 center = SpreadParticle(v, spreadProgress);
        float4 center_WS = mul(unity_ObjectToWorld, center);

        // Custom vertex animation
        float scrollAmount = GetTime().y;
        float t = fmod(scrollAmount * _ScrollRate + v.color.a, 1);
        float4 dispVec = (t - .5f) * float4(_ScrollDistance, 0.0);
        dispVec.x += sin(t * _ScrollJitterFrequency + GetTime().y) * _ScrollJitterIntensity;
        dispVec.z += cos(t * _ScrollJitterFrequency * .5 + GetTime().y) * _ScrollJitterIntensity;
        dispVec.xyz = spreadProgress * dispVec * kDecimetersToWorldUnits;
        center_WS += mul(xf_CS, dispVec);

        PrepForOdsWorldSpace(center_WS);

        float4 corner_WS = OrientParticle_WS(center_WS.xyz, halfSize, v.vid, rotation);
#ifdef AUDIO_REACTIVE
        o.color = musicReactiveColor(v.color, _BeatOutput.w);
        corner_WS = musicReactiveAnimationWorldSpace(corner_WS, v.color, _BeatOutput.w, corner_WS.y*5);
#else
        o.color = v.color;
#endif

        o.vertex = mul(UNITY_MATRIX_VP, corner_WS);
        o.color.a = pow(1 - abs(2*(t - .5)), 3);
        o.texcoord = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
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
    ALPHA *= Opacity;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(i.id.x > _ClipStart && i.id.x < _ClipEnd)) discard;
        if (_Dissolve < 1 && Dither8x8(i.vertex.xy) >= _Dissolve) discard;
        #endif

        float4 texCol = tex2D(_MainTex, i.texcoord);
        float4 color = SrgbToNative(2.0f * i.color * _TintColor * texCol);
#if SELECTION_ON
        color.rgb = GetSelectionColor() * texCol.r;
        color.a = texCol.a;
#endif
        color.a *= _Opacity;
        return color;
    */
}

