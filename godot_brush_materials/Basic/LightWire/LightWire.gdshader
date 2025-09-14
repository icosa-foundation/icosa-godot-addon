// Converted from Unity shader: Assets/Resources/Brushes/Basic/LightWire/LightWire.shader
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
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    UNITY_INITIALIZE_OUTPUT(Input, o);
      PrepForOds(v.vertex);
      v.color = TbVertToSrgb(v.color);

      // Radius is stored in texcoord (used to be tangent.w)
      float radius = v.texcoord.z;

      float t;
      float envelope = sin ( fmod ( v.texcoord.x * 2, 1.0f) * 3.14159);
      float lights = envelope < .15 ? 1 : 0;

      radius *= 0.9;
      v.vertex.xyz += v.normal * lights * radius;
      o.id = (float2)v.id;
    */
}

void fragment() {
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

      float envelope = sin ( fmod ( IN.uv_MainTex.x*2, 1.0f) * 3.14159);
      float lights = envelope < .1 ? 1 : 0;
      float border = abs(envelope - .1) < .01 ? 0 : 1;
      o.Specular =   .3 - lights * .15;
      o.Smoothness = .3 + lights * .3;

      float t;
#ifdef AUDIO_REACTIVE
      t = _BeatOutputAccum.x*10;
#else
      t = GetTime().w;
#endif

      if (lights) {
        int colorindex = fmod(IN.uv_MainTex.x*2 + 0.5, 3);
        if (colorindex == 0) IN.color.rgb = IN.color.rgb * float3(.2,.2,1);
        else if (colorindex == 1) IN.color.rgb = IN.color.rgb * float3(1,.2,.2);
        else IN.color.rgb = IN.color.rgb * float3(.2,1,.2);

        float lightindex =  fmod(IN.uv_MainTex.x*2 + .5,7);
        float timeindex = fmod(t, 7);
        float delta = abs(lightindex - timeindex);
        float on = 1 - saturate(delta*1.5);
        IN.color = bloomColor(IN.color * on, .7);
      }

      o.Albedo = (1-lights) *  IN.color.rgb * .2;
      o.Albedo *= border;
      o.Specular *= border;

#ifdef AUDIO_REACTIVE
      IN.color.rgb = IN.color.rgb * .25 + IN.color.rgb*_BeatOutput.x * .75;
#endif
      o.Emission += lights * IN.color.rgb;

      o.Albedo   = SrgbToNative3(o.Albedo);
      o.Emission = SrgbToNative3(o.Emission);
      o.Specular = SrgbToNative3(o.Specular);

      SURF_FRAG_MOBILESELECT(o);
    */
}

