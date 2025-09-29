// Converted from Unity shader: Assets/Resources/Brushes/Blocks/BlocksGem/BlocksGem.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode blend_mix;



uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color
uniform float Shininess : hint_range(0, 1) = 0.8; // Shininess
uniform float RimIntensity : hint_range(0, 1) = .2; // Rim Intensity
uniform float RimPower : hint_range(0, 16) = 5; // Rim Power
uniform float Frequency : hint_range(0.0, 10.0) = 1; // Frequency
uniform float Jitter : hint_range(0.0, 10.0) = 1; // Jitter

void vertex() {
    // Vertex conversion needed

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    UNITY_INITIALIZE_OUTPUT(Input,o);
   PrepForOds(v.vertex);
   o.localPos = v.vertex.xyz;
    */
}

void fragment() {
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    EMISSION = emission_color.rgb;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    const float kPerturbIntensity = 10;
    float2 F = fBm_F0(IN.localPos, OCTAVES);
    float gem = (F.y - F.x);

    // Perturb normal with voronoi cells

    // Note: can't do "o.Normal += perturb" because tangent-space o.Normal
    // comes in as (0, 0, 0), not (0, 0, 1)
    o.Normal = (float3(0, 0, 1) +
                kPerturbIntensity * float3(ddy(gem), ddx(gem), 0));

    o.Albedo = 0;

    // Artifical diffraction highlights to simulate what I see in blocks. Tuned to taste.
    half3 refl = clamp(WorldReflectionVector (IN, o.Normal) + gem, -1.0,1.0);
    float3 colorRamp = float3(1,.3,0)*sin(refl.x * 30) + float3(0,1,.5)*cos(refl.y * 37.77) + float3(0,0,1)*sin(refl.z*43.33);

    // Use the voronoi for a specular mask
    half mask = saturate((1 - gem) + .25);
    o.Specular = _Color.rgb + colorRamp*.1;
    o.Smoothness = _Shininess;

    // Artificial rim lighting
    o.Emission =  (pow(1 - saturate(dot(IN.viewDir, o.Normal)), _RimPower)) * _RimIntensity;
    SURF_FRAG_MOBILESELECT(o);
    */
}

