// Converted from Unity shader: Assets/Resources/Brushes/Basic/TubeToonInverted/TubeToonInverted.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;





uniform sampler2D MainTex : source_color; // Base (RGB) Trans (A) {}
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Vertex conversion needed

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    return vertInflate(v,0);
    */
}

void fragment() {
    ALBEDO = texture(MainTex, UV).rgb;
    // ALBEDO *= Color.rgb;
}

