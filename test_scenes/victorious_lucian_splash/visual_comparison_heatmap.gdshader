shader_type canvas_item;

instance uniform int display_mode = 2;
instance uniform float mip = 0.0;
uniform sampler2D gradient;
uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	switch (display_mode){
		case 0: // Reference
			break;
		case 1: // Result
			break;
		case 2: // Average
			break;
		case 3: // Difference
			break;
		case 4: // Difference Heatmap
	COLOR = texture(gradient, vec2(distance(textureLod(screen_texture, SCREEN_UV, mip).rgb, vec3(0.5)), 0.5));
		default:
			break;
	};
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
