shader_type spatial;
// La mancha de SombrasRedondas: una elipse oscura con el borde difuso.
// Sin luz: es un oscurecido del pasto, no una superficie que se ilumina.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Verde muy oscuro: sobre el pasto da el tono de la sombra toon del sol.
uniform vec4 color_sombra : source_color = vec4(0.05, 0.16, 0.04, 0.55);

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float borde = 1.0 - smoothstep(0.45, 1.0, d);
	ALBEDO = color_sombra.rgb;
	ALPHA = color_sombra.a * borde * COLOR.a;
}
