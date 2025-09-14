// Converted from Unity shader: Assets/Resources/Brushes/Basic/Petal/Petal.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled;

// // Unity _ScreenParams -> Godot SCREEN_PIXEL_SIZE

uniform vec4 SpecColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Specular Color
uniform float Shininess : hint_range(0.01, 1) = 0.3; // Shininess
uniform sampler2D MainTex : source_color; // Base (RGB) TransGloss (A) {}
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    UNITY_INITIALIZE_OUTPUT(Input, o);
        PrepForOds(i.vertex);
        i.color = TbVertToNative(i.color);
        o.id = i.id;
    */
}

void fragment() {
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(IN.id.x > _ClipStart && IN.id.x < _ClipEnd)) discard;
        if (_Dissolve < 1 && Dither8x8(IN.screenPos.xy / IN.screenPos.w * _ScreenParams) >= _Dissolve) discard;
        #endif

        // Fade from center outward (dark to light)
        float4 darker_color = IN.color;
        darker_color *= 0.6;
        float4 finalColor = lerp(IN.color, darker_color, 1- IN.uv_MainTex.x);

        float fAO = IN.vface == -1 ? .5 * IN.uv_MainTex.x : 1;
        o.Albedo = finalColor * fAO;
        o.Smoothness = _Shininess;
        o.Specular = _SpecColor * fAO;
        o.Alpha = 1;

        SURF_FRAG_MOBILESELECT(o);
    */
}

