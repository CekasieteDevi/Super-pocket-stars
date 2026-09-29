shader_type spatial;
// Casco invertido del contorno: color plano, una sola cara. Es un shader y
// no un StandardMaterial3D para poder cortarlo igual que el toon (si no, la
// tribuna del lado de la cámara desaparecía pero su contorno quedaba).
render_mode unshaded, cull_back;

uniform vec4 color_contorno : source_color = vec4(0.165, 0.09, 0.07, 1.0);
uniform float corte_z = 100000.0;

void fragment() {
	if ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).z > corte_z) {
		discard;
	}
	ALBEDO = color_contorno.rgb;
}
