// Converted from Unity shader: Assets/Resources/Brushes/Blocks/BlocksGlass/BlocksGlass.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, blend_mix;



uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color
uniform sampler2D Noise : source_color; // Noise (RGB) {}
uniform float Shininess : hint_range(0, 1) = 0.8; // Shininess
uniform float RimIntensity : hint_range(0, 1) = .2; // Rim Intensity
uniform float RimPower : hint_range(0, 16) = 5; // Rim Power

void vertex() {
    // Vertex conversion needed

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(i.vertex);
    UNITY_INITIALIZE_OUTPUT(Input, o);
    */
}

void fragment() {
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    EMISSION = emission_color.rgb;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    o.Normal = float3(0,0,IN.vface);

    // Dim Backfaces
    float backfaceDimming = IN.vface == -1 ? .25 : 1;

    o.Albedo = 0;
    o.Specular = _Color.rgb * backfaceDimming;

// Currently rim lighting is causing the entire object to go white in ODS renders.
// TODO: figure out what's causing this.
#if !defined(ODS_RENDER_CM)
    // Rim Lighting
    o.Emission = (pow(1 - saturate(dot(IN.viewDir, o.Normal)), _RimPower)) * _RimIntensity * backfaceDimming;
#endif

    o.Smoothness = _Shininess;
    SURF_FRAG_MOBILESELECT(o);
    */
}

