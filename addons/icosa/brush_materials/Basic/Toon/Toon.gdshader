// Converted from Unity shader: Assets/Resources/Brushes/Basic/Toon/Toon.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;





uniform sampler2D MainTex : source_color; // Base (RGB) Trans (A) {}
uniform float OutlineMax : hint_range(0, .5) = .005; // Maximum outline size
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    v.color = TbVertToNative(v.color);
    return vertInflate(v,0);
    */
}

void fragment() {
    ALBEDO = texture(MainTex, UV).rgb;
    // ALBEDO *= Color.rgb;
}

