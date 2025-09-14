// Converted from Unity shader: Assets/Resources/Brushes/Basic/HyperGrid/HyperGrid.shader
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

        // Subtract out the Canvas space pose to keep the verts from popping around while
        // transforming (e.g. apply quantization in an immutable space).
        float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
        PrepForOdsWorldSpace(worldPos);
        worldPos = mul(xf_I_CS, worldPos);

        float waveform = 0;

        float lifetime = GetTime().y - v.texcoord1.w;
        float size = length(v.texcoord1.xyz);
        float release = saturate(lifetime);

#ifdef AUDIO_REACTIVE
        worldPos.y -= release * fmod(_BeatOutputAccum.x - v.texcoord1.w, 5);
        worldPos.y += .3 * release * pow(sin(_BeatOutputAccum.x * 2 + worldPos.x),5);
#endif
        // Quantize vertices
        float q = (1.0f / size) * .5;
        q += 5 * saturate(1- release*10);
        float3 quantPos = ceil(worldPos.xyz * q) / q;
        worldPos.xyz = quantPos;
        worldPos = mul(xf_CS, worldPos);
        o.pos = mul(UNITY_MATRIX_VP,  worldPos);

        o.color = 2 * v.color + v.color.yzxw * _BeatOutput.x;
        o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
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

        float4 c = i.color * _TintColor * tex2D(_MainTex, i.texcoord);
        c = encodeHdr(c.rgb * c.a);
        c = SrgbToNative(c);
        FRAG_MOBILESELECT(c)
        return c * _Opacity;
    */
}

