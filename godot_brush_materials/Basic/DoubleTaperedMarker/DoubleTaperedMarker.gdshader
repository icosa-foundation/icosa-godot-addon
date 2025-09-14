// Converted from Unity shader: Assets/Resources/Brushes/Basic/DoubleTaperedMarker/DoubleTaperedMarker.shader
// Auto-converted with some manual TODOs remaining

shader_type spatial;

render_mode cull_disabled;



uniform float Dissolve : hint_range(0, 1) = 1; // Dissolve
uniform float ClipStart : hint_range(0.0, 10.0) = 0; // Clip Start
uniform float ClipEnd : hint_range(0.0, 10.0) = -1; // Clip End

void vertex() {
    // Unity UnityObjectToClipPos -> Godot built-in vertex processing
    // VERTEX is automatically transformed by Godot
    COLOR = COLOR; // Unity color space conversion

    // TODO: Convert Unity vertex logic:
    /* Original Unity vertex code:
    PrepForOds(v.vertex);

        //
        // XXX - THIS SHADER SHOULD BE DELETED AFTER TAPERING IS DONE IN THE GEOMETRY GENERATION
        //

        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        float envelope = sin(v.texcoord0.x * 3.14159);
        float widthMultiplier = 1 - envelope;
        v.vertex.xyz += -v.texcoord1 * widthMultiplier;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.color = TbVertToNative(v.color);
        o.texcoord = v.texcoord0;
        o.id = (float2)v.id;
        UNITY_TRANSFER_FOG(o, o.pos);
        return o;
    */
}

void fragment() {
    ALBEDO = texture(MainTex, UV).rgb;
}

