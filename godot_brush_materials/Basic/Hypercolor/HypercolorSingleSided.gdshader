// Converted from Unity shader: Assets/Resources/Brushes/Basic/Hypercolor/HypercolorSingleSided.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode depth_test_disabled;

// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME

uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Main Color
uniform vec4 SpecColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Specular Color
uniform float Shininess : hint_range(0.01, 1) = 0.078125; // Shininess
uniform sampler2D MainTex : source_color; // Base (RGB) TransGloss (A) {}
uniform sampler2D BumpMap : source_color; // Normalmap {}
uniform float Cutoff : hint_range(0, 1) = 0.5; // Alpha cutoff
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);
      v.color = TbVertToSrgb(v.color);

      float t = 0.0;

      float strokeWidth = abs(v.texcoord.z) * 1.2;

#ifdef AUDIO_REACTIVE
      t = _BeatOutputAccum.z * 5;
      float waveIntensity = _BeatOutput.z * .1 * strokeWidth;
      v.vertex.xyz += (pow(1 - (sin(t + v.texcoord.x * 5 + v.texcoord.y * 10) + 1), 2)
                * cross(v.tangent.xyz, v.normal.xyz)
                * waveIntensity)
              ;
#endif
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    EMISSION = emission_color.rgb;

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);

      float scroll = GetTime().z;
#ifdef AUDIO_REACTIVE
      float3 localPos = mul(xf_I_CS, float4(IN.worldPos, 1.0)).xyz;
      float t = length(localPos) * .5;
      scroll =  _BeatOutputAccum.y*30;
      float angle = atan2(localPos.x, localPos.y);
      float waveform = tex2D(_WaveFormTex, float2(angle * 6,0)).g*2;

      tex.rgb =  float3(1,0,0) * (sin(tex.r*2 + scroll*0.5 - t) + 1);
      tex.rgb += float3(0,1,0) * (sin(tex.r*3 + scroll*1 - t) + 1);
      tex.rgb += float3(0,0,1) * (sin(tex.r*4 + scroll*0.25 - t) + 1);
#else
      tex.rgb =  float3(1,0,0) * (sin(tex.r * 2 + scroll*0.5 - IN.uv_MainTex.x) + 1) * 2;
      tex.rgb += float3(0,1,0) * (sin(tex.r * 3.3 + scroll*1 - IN.uv_MainTex.x) + 1) * 2;
      tex.rgb += float3(0,0,1) * (sin(tex.r * 4.66 + scroll*0.25 - IN.uv_MainTex.x) + 1) * 2;
#endif

      o.Albedo = SrgbToNative(tex * IN.color).rgb;
      o.Smoothness = _Shininess;
      o.Specular = SrgbToNative(_SpecColor * tex).rgb;
      o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
      o.Alpha = tex.a * IN.color.a;
#ifdef AUDIO_REACTIVE
      o.Emission = o.Albedo;
      o.Albedo = .2;
      o.Specular *= .5;
#endif
    */
}

