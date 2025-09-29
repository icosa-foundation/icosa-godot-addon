// Converted from Unity shader: Assets/Resources/Brushes/Basic/Disco/Disco.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;



// // Unity _Time -> Godot TIME
// // Unity GetTime() -> TIME
// // Unity _ScreenParams -> Godot SCREEN_PIXEL_SIZE

uniform vec4 Color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Main Color
uniform vec4 SpecColor : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Specular Color
uniform float Shininess : hint_range(0.01, 1) = 0.078125; // Shininess
uniform sampler2D MainTex : source_color; // Base (RGB) TransGloss (A) {}
uniform sampler2D BumpMap : source_color; // Normalmap {}
uniform vec4 TimeOverrideValue = vec4(0.0, 0.0, 0.0, 0.0); // Time Override Value
uniform float TimeBlend : hint_range(0.0, 10.0) = 0; // Time Blend
uniform float TimeSpeed : hint_range(0.0, 10.0) = 1.0; // Time Speed
uniform float Dissolve : hint_range(0, 1) = 1; // _Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion
    // TIME variable available in Godot
    float time_val = TIME;

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    UNITY_INITIALIZE_OUTPUT(Input, o);
      PrepForOds(v.vertex);
      v.color = TbVertToNative(v.color);
      float t, uTileRate, waveIntensity;

      float radius = v.texcoord.z;

#ifdef AUDIO_REACTIVE
      t = _BeatOutputAccum.z * 5;
      uTileRate = 5;
      waveIntensity = (_PeakBandLevels.y * .8 + .5);
      float waveform = tex2Dlod(_WaveFormTex, float4(v.texcoord.x * 2, 0, 0, 0)).b - .5f;
      v.vertex.xyz += waveform * v.normal.xyz * .2;
#else
      t = GetTime().z;
      uTileRate = 10;
      waveIntensity = .6;
#endif
      // Ensure the t parameter wraps (1.0 becomes 0.0) to avoid cracks at the seam.
      float theta = fmod(v.texcoord.y, 1);
      v.vertex.xyz += pow(1 -(sin(t + v.texcoord.x * uTileRate + theta * 10) + 1),2)
              * v.normal.xyz * waveIntensity
              * radius;
      o.id = v.id;
    */
}

void fragment() {
    // Unity tex2D() -> Godot texture()
    vec4 main_tex = texture(MainTex, UV);
    ALBEDO = main_tex.rgb;
    // Apply tint if available
    // ALBEDO *= TintColor.rgb; // or Color.rgb
    EMISSION = emission_color.rgb;
    // TODO: Convert Unity discard to Godot
    // Use ALPHA = 0.0 or conditional logic

    // TODO: Convert Unity fragment logic:
    /* Original Unity fragment code:
    #ifdef SHADER_SCRIPTING_ON
      if (_ClipEnd > 0 && !(IN.id.x > _ClipStart && IN.id.x < _ClipEnd)) discard;
      if (_Dissolve < 1 && Dither8x8(IN.screenPos.xy / IN.screenPos.w * _ScreenParams) >= _Dissolve) discard;
      #endif

      fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
      o.Albedo = tex.rgb * _Color.rgb * IN.color.rgb;
      o.Smoothness = _Shininess;
      o.Specular = _SpecColor * IN.color.rgb;
      o.Normal =  float3(0,0,1);

      // XXX need to convert world normal to tangent space normal somehow...
      float3 worldNormal = normalize(cross(ddy(IN.worldPos), ddx(IN.worldPos)));
      o.Normal = -cross(cross(o.Normal, worldNormal), worldNormal);
      o.Normal = normalize(o.Normal);

      // Add a fake "disco ball" hot spot
      float fakeLight = pow( abs(dot(worldNormal, float3(0,1,0))),100);
      o.Emission = IN.color.rgb * fakeLight * 200;
      SURF_FRAG_MOBILESELECT(o);
    */
}

