shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

instance uniform int display_mode = 2;
// 0 - Reference
// 1 - Result
// 2 - Average
// 3 - Difference

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	switch (display_mode){
		case 0:
			COLOR = vec4(0.0);
			COLOR.a = 0.0;
			break;
		case 1:
			break;
		case 2:
			COLOR = COLOR / 2.0;
			break;
		case 3:
			COLOR.rgb = 0.5 - COLOR.rgb / 2.0;
			COLOR.a = 0.5;
			break;
		default:
			break;
	};
}


//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
