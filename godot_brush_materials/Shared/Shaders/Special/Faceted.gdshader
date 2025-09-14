// Converted from Unity shader: Assets/Resources/Brushes/Shared/Shaders/Special/Faceted.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;



// // Unity unity_ObjectToWorld -> Godot WORLD_MATRIX

uniform sampler2D MainTex : source_color; // Base (RGB) Trans (A) {}
uniform vec4 ColorX : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color X
uniform vec4 ColorY : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color Y
uniform vec4 ColorZ : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color Z
uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot
    // Unity TRANSFORM_TEX -> manual UV transform
    // UV = UV * _MainTex_ST.xy + _MainTex_ST.zw;

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);
      v2f o;

      UNITY_SETUP_INSTANCE_ID(v);
      UNITY_INITIALIZE_OUTPUT(v2f, o);
      UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

      o.vertex = UnityObjectToClipPos(v.vertex);
      o.color = v.color;
      o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
      o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
      o.id = (float2)v.id;
      return o;
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
      if (_ClipEnd > 0 && !(i.id.x > _ClipStart && i.id.x < _ClipEnd)) discard;
      if (_Dissolve < 1 && Dither8x8(i.vertex.xy) >= _Dissolve) discard;
      #endif

      float3 n = normalize(cross(ddy(i.worldPos), ddx(i.worldPos)));
      i.color.xyz = float3(
        lerp(float3(0,0,0), _ColorX, n.x) +
        lerp(float3(0,0,0), _ColorY, n.y) +
        lerp(float3(0,0,0), _ColorZ, n.z)
      );
      return i.color;
    */
}

