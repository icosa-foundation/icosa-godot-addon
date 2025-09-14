// Converted from Unity shader: Assets/Resources/Brushes/Blocks/BlocksPaper/BlocksPaper.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;





uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Main Color
uniform float Shininess : hint_range(0.01, 1) = 0.078125; // Shininess
uniform vec4 SpecColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Specular Color

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    UNITY_INITIALIZE_OUTPUT(Input, o);
      PrepForOds(i.vertex);
      i.color = TbVertToNative(i.color);
    */
}

void fragment() {
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    o.Albedo = _Color.rgb * IN.color.rgb;
      o.Smoothness = _Shininess;
      o.Specular = _SpecColor;

      SURF_FRAG_MOBILESELECT(o);
    */
}

