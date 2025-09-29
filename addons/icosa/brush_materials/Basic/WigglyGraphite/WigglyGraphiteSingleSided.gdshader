// Converted from Unity shader: Assets/Resources/Brushes/Basic/WigglyGraphite/WigglyGraphiteSingleSided.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode depth_test_disabled;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME

uniform sampler2D MainTex : source_color; // Main Texture {}
uniform sampler2D SecondaryTex : source_color; // Diffuse Tex {}
uniform float Cutoff : hint_range(0, 1) = 0.5; // Alpha cutoff
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(i.vertex);
        i.color = TbVertToSrgb(i.color);
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    fixed2 scrollUV = IN.uv_MainTex;

        // Animate flipbook motion. Currently tuned to taste.
        float anim = fmod(GetTime().y * 12, 6);
        anim = ceil(anim);
        scrollUV.x += anim;
        scrollUV.x *= 1.1;

        float3 secondary_tex = tex2D(_MainTex, IN.uv_SecondaryTex  ).rgb;

        // Apply the alpha mask
        float primary_tex = tex2D(_MainTex, scrollUV).w;

        float3 tex = secondary_tex * primary_tex;

        o.Specular = 0;
        o.Smoothness = 0;
        o.Albedo = IN.color.rgb;
        o.Alpha = tex * IN.color.a;
    */
}

