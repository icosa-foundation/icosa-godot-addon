vec3 unpack_tangent_normal(vec3 normal_map_sample) {
	vec3 tangent_normal = normalize(normal_map_sample * 2.0 - 1.0);
	tangent_normal.y = -tangent_normal.y;
	return tangent_normal;
}

vec3 perturb_tangent_normal(
	vec3 tangent,
	vec3 bitangent,
	vec3 normal,
	vec2 uv,
	sampler2D bump_map,
	bool front_facing
) {
	if (!front_facing) {
		normal = -normal;
		tangent = -tangent;
		bitangent = -bitangent;
	}
	vec3 tangent_normal = unpack_tangent_normal(texture(bump_map, uv).xyz);
	mat3 tbn = mat3(normalize(tangent), normalize(bitangent), normalize(normal));
	return normalize(tbn * tangent_normal);
}
