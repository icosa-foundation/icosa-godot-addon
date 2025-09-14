// Converted from Unity shader: Assets/Resources/Brushes/Basic/Dots/Dots.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX

uniform vec4 TintColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Tint Color
uniform sampler2D MainTex : source_color; // Particle Texture {}
uniform float WaveformFreq : hint_range(0.0, 10.0) = 1; // Waveform Freq
uniform vec4 WaveformIntensity = vec4(0.0, 0.0, 0.0, 0.0); // Waveform Intensity
uniform float BaseGain : hint_range(0.0, 10.0) = 0; // Base Gain
uniform float EmissionGain : hint_range(0.0, 10.0) = 0; // Emission Gain
uniform float Dissolve : hint_range(0, 1) = 1; // _Dissolve
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
    v.color = TbVertToSrgb(v.color);
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        float birthTime = v.texcoord.w;
        float rotation = v.texcoord.z;
        float halfSize = GetParticleHalfSize(v.corner.xyz, v.center, birthTime);
        float4 center = float4(v.center.xyz, 1);
        PrepForOds(center);
        float4 corner = OrientParticle(center.xyz, halfSize, v.vid, rotation);
        float waveform = 0;
        // TODO: displacement should happen before orientation
#ifdef AUDIO_REACTIVE
        float4 dispVec = float4(0,0,0,0);
        float4 corner_WS = mul(unity_ObjectToWorld, corner);
        // TODO: worldspace is almost certainly incorrect: use scene or object?
        waveform = tex2Dlod(_FFTTex, float4(fmod(corner_WS.x * _WaveformFreq + _BeatOutputAccum.z*.5,1),0,0,0) ).b * .25;
        dispVec.xyz += waveform * _WaveformIntensity.xyz;
        corner = corner + dispVec;
#endif
        o.vertex = UnityObjectToClipPos(corner);
        o.color = v.color * _BaseGain;
        o.texcoord = TRANSFORM_TEX(v.texcoord.xy,_MainTex);
        o.waveform = waveform * 15;
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
    ALPHA = main_tex.a;
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(i.id.x > _ClipStart && i.id.x < _ClipEnd)) discard;
        // It's hard to get alpha curves right so use dithering for hdr shaders
        if (_Dissolve < 1 && Dither8x8(i.vertex.xy) >= _Dissolve) discard;
        #endif

        #ifdef AUDIO_REACTIVE
        // Deform uv's by waveform displacement amount vertically
        // Envelop by "V" UV to keep the edges clean
        float vDistance = abs(i.texcoord.y - .5)*2;
        float vStretched = (i.texcoord.y - 0.5) * (.5 - abs(i.waveform)) * 2 + 0.5;
        i.texcoord.y = lerp(vStretched, i.texcoord.y, vDistance);
#endif
        float4 tex = tex2D(_MainTex, i.texcoord);
        float4 c = i.color * _TintColor * tex;

        // Only alpha channel receives emission boost
        c.rgb += c.rgb * c.a * _EmissionGain;
        c.a = 1;
        c = SrgbToNative(c);
        c = encodeHdr(c.rgb);
#if SELECTION_ON
        c.rgb = GetSelectionColor() * tex.r;
#endif
          return c * _Dissolve;
    */
}

