// Converted from Unity shader: Assets/Resources/Brushes/Basic/DoubleTaperedFlat/DiffuseNoTextureDoubleSided.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled;

// // Unity _ScreenParams -> Godot SCREEN_PIXEL_SIZE

uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Main Color
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);

    //
    // XXX - THIS TAPERING CODE SHOULD BE REMOVED ONCE THE TAPERING IS DONE IN THE GEOMETRY GENERATION
    // THE SHADER WILL REMAIN AS A SIMPLE "DiffuseNoTextureDoubleSided" SHADER.
    //

    UNITY_INITIALIZE_OUTPUT(Input, o);
    float envelope = sin(v.texcoord0.x * 3.14159);
    float widthMultiplier = 1 - envelope;
    v.vertex.xyz += -v.texcoord1 * widthMultiplier;
    v.color = TbVertToNative(v.color);
    o.id = v.id;
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

    fixed4 c = _Color;
    o.Normal = float3(0,0,IN.vface);
    o.Albedo = c.rgb * IN.color.rgb;
    SURF_FRAG_MOBILESELECT(o);
    */
}

