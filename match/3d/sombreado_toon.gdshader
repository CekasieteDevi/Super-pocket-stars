shader_type spatial;
// Toon de tres tonos constantes, igual que los materiales de Blender
// (Shader to RGB + Color Ramp constante). Sin luz ambiente: el tono de
// sombra lo pone este shader, así el lado oscuro nunca queda negro.
render_mode cull_back, specular_disabled;

uniform vec4 color_base : source_color = vec4(1.0);
// Multiplicadores medidos en los renders de Blender: sombra apenas violácea,
// tono medio neutro y un brillo corto del lado del sol.
uniform vec3 tono_sombra = vec3(0.72, 0.62, 0.66);
uniform float tono_luz = 1.13;
uniform float umbral_sombra = 0.35;
uniform float umbral_luz = 0.8;
// Todo lo que está más allá de esta Z del mundo no se dibuja. Lo usa la
// tribuna del lado de la cámara; el resto queda con el valor por defecto.
uniform float corte_z = 100000.0;

void fragment() {
	if ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).z > corte_z) {
		discard;
	}
	ALBEDO = color_base.rgb;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	vec3 tono = nl < umbral_sombra ? tono_sombra : (nl < umbral_luz ? vec3(1.0) : vec3(tono_luz));
	// LIGHT_COLOR viene multiplicado por PI; se divide para que un sol de
	// energía 1 deje el color base tal cual en el tono medio.
	DIFFUSE_LIGHT += tono * LIGHT_COLOR / PI;
}
