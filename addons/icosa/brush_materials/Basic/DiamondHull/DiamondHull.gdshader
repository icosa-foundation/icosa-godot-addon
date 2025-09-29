// Converted from Unity shader: Assets/Resources/Brushes/Basic/DiamondHull/DiamondHull.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity _ScreenParams -> Godot SCREEN_PIXEL_SIZE
// // Unity _WorldSpaceCameraPos -> Godot CAMERA_POSITION_WORLD

uniform sampler2D MainTex : source_color; // Texture {}
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Opacity : hint_range(0, 1) = 1; // Opacity
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);
        o.color = TbVertToSrgb(o.color);
        UNITY_INITIALIZE_OUTPUT(Input, o);
        o.tex = v.texcoord.xy;
        o.id = v.id;
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;
    EMISSION = emission_color.rgb;
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic
    ALPHA *= Opacity;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
        if (_ClipEnd > 0 && !(IN.id.x > _ClipStart && IN.id.x < _ClipEnd)) discard;
        if (_Dissolve < 1 && Dither8x8(IN.screenPos.xy / IN.screenPos.w * _ScreenParams) >= _Dissolve) discard;
        #endif

        // Hardcode some shiny specular values
        o.Smoothness = .8;
        o.Albedo = IN.color * .2;

        // Calculate rim
        half rim = 1.0 - abs(dot(normalize(IN.viewDir), IN.worldNormal));
        rim *= 1-pow(rim,5);

        const float3 I = (_WorldSpaceCameraPos - IN.worldPos);
        rim = lerp(rim, 150,
              1 - saturate(abs(dot(normalize(I), IN.worldNormal)) / .1));

        float3 diffraction = tex2D(_MainTex, half2(rim + GetTime().x * .3 + o.Normal.x, rim + o.Normal.y)).xyz;
        diffraction = GetDiffraction(diffraction, o.Normal, normalize(IN.viewDir));

        o.Emission = rim * IN.color * diffraction * .5 + rim * diffraction * .25;
        // SURF_FRAG_MOBILESELECT(o);
        o.Specular = SrgbToNative(IN.color).rgb * clamp(diffraction, .0, 1);
        o.Emission *= _Opacity;
        o.Albedo *= _Opacity;
        o.Specular *= _Opacity;
    */
}

