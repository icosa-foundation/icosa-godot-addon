// Converted from Unity shader: Assets/Resources/Brushes/Basic/Electricity/Electricity.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled, depth_draw_never, blend_mix;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME

uniform sampler2D MainTex : source_color; // Color {}
uniform float DisplacementIntensity : hint_range(0.0, 10.0) = .1; // Displacement
uniform float EmissionGain : hint_range(0, 1) = 0.5; // Emission Gain
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // No Unity vertex function found - using default
}

void fragment() {
    ALBEDO = texture(MainTex, UV).rgb;
    // ALBEDO *= Color.rgb;
}

