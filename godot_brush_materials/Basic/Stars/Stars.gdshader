// Converted from Unity shader: Assets/Resources/Brushes/Basic/Stars/Stars.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME

uniform sampler2D MainTex : source_color; // Particle Texture {}
uniform float SparkleRate : hint_range(0.0, 10.0) = 2.5; // Sparkle Rate
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
        const float PI = 3.14159265359;
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        float birthTime = v.texcoord.w;
        float rotation = v.texcoord.z;
        float halfSize = GetParticleHalfSize(v.corner.xyz, v.center, birthTime);
        float spreadProgress = SpreadProgress(birthTime, _SpreadRate);
        float4 center = SpreadParticle(v, spreadProgress);
        PrepForOds(center);

        float phase = v.color.a * (2 * PI);
        float brightness;

#ifdef AUDIO_REACTIVE
        brightness = 800 * pow(abs(sin(_BeatOutputAccum.w * _SparkleRate + phase)), 20);
        brightness = brightness*.25 + 2*brightness * (_BeatOutput.w);
#else
        brightness = 800 * pow(abs(sin(GetTime().y * _SparkleRate + phase)), 20);
#endif
        o.color.rgb = v.color.rgb * brightness;
        o.color.a = 1;
        o.texcoord = TRANSFORM_TEX(v.texcoord.xy,_MainTex);

        float4 corner = OrientParticle(center.xyz, halfSize, v.vid, rotation);
        o.vertex = UnityObjectToClipPos(corner);
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
        float4 color = i.color * texCol;
        color = encodeHdr(color.rgb * color.a);
        color = SrgbToNative(color);
#if SELECTION_ON
        color.rgb = GetSelectionColor() * texCol.r;
        color.a = texCol.a;
#endif
        return color * _Dissolve;
    */
}

