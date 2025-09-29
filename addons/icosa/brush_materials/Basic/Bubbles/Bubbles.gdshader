// Converted from Unity shader: Assets/Resources/Brushes/Basic/Bubbles/Bubbles.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME

uniform sampler2D MainTex : source_color; // Particle Texture {}
uniform float ScrollRate : hint_range(0.0, 10.0) = 1.0; // Scroll Rate
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
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot
    // Unity TRANSFORM_TEX -> manual UV transform
    // UV = UV * _MainTex_ST.xy + _MainTex_ST.zw;
    COLOR = COLOR; // Unity color space conversion

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
        PrepForOds(center);

        float3 displacement_SS = spreadProgress * computeDisplacement(center, 1);
        float3 displacement_WS = mul(xf_CS, float4(displacement_SS, 0));
        float3 displacement_OS = mul(unity_WorldToObject, float4(displacement_WS, 0));
        center.xyz += displacement_OS;
        float4 corner = OrientParticle(center.xyz, halfSize, v.vid, rotation);
        o.vertex = UnityObjectToClipPos(corner);

        // Brighten up the bubbles
        o.color = v.color;
        o.color.a = 1;
        o.texcoord = TRANSFORM_TEX(v.texcoord.xy,_MainTex);
        o.id = v.id;

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

        float4 tex = tex2D(_MainTex, i.texcoord);

        // RGB Channels of the texture are affected by color
        float3 basecolor = i.color * tex.rgb;

        // Alpha channel of the texture is not affected by color.  It is the fake "highlight" bubble effect.
        float3 highlightcolor = tex.a;

        float4 color = float4(basecolor + highlightcolor, 1);
        color = SrgbToNative(color);

#if SELECTION_ON
        color.rgb = GetSelectionColor() * tex.r;
        color.a = tex.a;
#endif

        return color * _Opacity;
    */
}

