// Converted from Unity shader: Assets/Resources/Brushes/Basic/WaveformPulse/NeonPulse.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity _ScreenParams -> Godot SCREEN_PIXEL_SIZE

uniform float EmissionGain : hint_range(0, 1) = 0.5; // Emission Gain
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(i.vertex);
    UNITY_INITIALIZE_OUTPUT(Input, o);
    o.color = TbVertToSrgb(o.color);
    o.id = (float2)i.id;
    */
}

void fragment() {
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    EMISSION = emission_color.rgb;
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
    if (_ClipEnd > 0 && !(IN.id.x > _ClipStart && IN.id.x < _ClipEnd)) discard;
    // It's hard to get alpha curves right so use dithering for hdr shaders
    if (_Dissolve < 1 && Dither8x8(IN.screenPos.xy / IN.screenPos.w * _ScreenParams) >= _Dissolve) discard;
    #endif

    o.Smoothness = .8;
    o.Specular = .05;
    float audioMultiplier = 1;
#ifdef AUDIO_REACTIVE
    audioMultiplier += audioMultiplier * _BeatOutput.x;
    IN.tex.x -= _BeatOutputAccum.z;
    IN.color += IN.color * _BeatOutput.w * .25;
#else
    IN.tex.x -= GetTime().x*15;
#endif
    IN.tex.x = fmod( abs(IN.tex.x),1);
    float neon = saturate(pow( 10 * saturate(.2 - IN.tex.x),5) * audioMultiplier);
    float4 bloom = bloomColor(IN.color, _EmissionGain);
    float3 n = WorldNormalVector (IN, o.Normal);
    half rim = 1.0 - saturate(dot (normalize(IN.viewDir), n));
    bloom *= pow(1-rim,5);
    o.Emission = SrgbToNative(bloom * neon);
    o.Alpha *= _Dissolve;
    o.Emission *= _Dissolve;
    o.Albedo *= _Dissolve;
    o.Specular *= _Dissolve;
    SURF_FRAG_MOBILESELECT(o);
    */
}

