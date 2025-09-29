// Converted from Unity shader: Assets/Resources/Brushes/Basic/WigglyGraphite/WigglyGraphiteDoubleSided.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_test_disabled;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity _ScreenParams -> Godot SCREEN_PIXEL_SIZE

uniform sampler2D MainTex : source_color; // Main Texture {}
uniform sampler2D SecondaryTex : source_color; // Diffuse Tex {}
uniform float Cutoff : hint_range(0, 1) = 0.5; // Alpha cutoff
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    UNITY_INITIALIZE_OUTPUT(Input, o);
        o.vertex = UnityObjectToClipPos(i.vertex);
        PrepForOds(i.vertex);
        o.color = TbVertToSrgb(i.color);
        o.id = i.id;
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(IN.id.x > _ClipStart && IN.id.x < _ClipEnd)) discard;
        if (_Dissolve < 1 && Dither8x8(IN.screenPos.xy / IN.screenPos.w * _ScreenParams) >= _Dissolve) discard;
        #endif

        fixed2 scrollUV = IN.uv_MainTex;

        // Animate flipbook motion. Currently tuned to taste.
#ifdef AUDIO_REACTIVE
        float anim = ceil(fmod(GetTime().y * 3.0 + _BeatOutput.x * 3.0, 6.0));
#else
        float anim = ceil(fmod(GetTime().y * 12.0, 6.0));
#endif
        scrollUV.x += anim;
        scrollUV.x *= 1.1;

        o.Specular = 0;
        o.Smoothness = 0;
        o.Albedo = IN.color.rgb;
        o.Alpha = tex2D(_MainTex, scrollUV).w * IN.color.a;
        if (o.Alpha < _Cutoff) {
          discard;
        }
        o.Alpha = 1;
        o.Normal.z *= IN.vface;

        SURF_FRAG_MOBILESELECT(o);
    */
}

