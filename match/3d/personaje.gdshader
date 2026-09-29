shader_type spatial;
// El personaje entero en una sola malla y un solo material (una llamada de
// dibujo por jugador). Cada cara trae de Blender (exportar_juego3d.py,
// unir_personaje) el color de su material en el color del vértice (sRGB) y
// en el UV cómo se pinta: U = tipo, V = alfa (solo los cachetes).
// Los tonos son los de sombreado_toon.gdshader; lo que era sin luz (ojos,
// boca, contorno) va por EMISSION con ALBEDO negro, que da el mismo color.
render_mode cull_back, specular_disabled;

// Tipos: 0 color fijo con toon, 1 camiseta, 2 short, 3 pelo, 4 piel,
// 5 plano (sin luz), 6 cachetes (semitransparentes sobre la piel), 7 contorno.
// La camiseta lleva además el dorsal en la espalda (ver abajo).
uniform vec4 camiseta : source_color = vec4(1.0);
uniform vec4 color_short : source_color = vec4(1.0);
uniform vec4 pelo : source_color = vec4(1.0);
uniform vec4 piel : source_color = vec4(1.0);
uniform vec4 color_contorno : source_color = vec4(0.165, 0.09, 0.07, 1.0);

// La cara (ojos, cejas, boca) es un dibujo del atlas de tools/generar_caras.py
// y no la geometría del modelo: así cada jugador tiene la suya y cambia de
// gesto (gol, lesión). Jugador3D le da a la piel de la cara el UV2 (el
// rectángulo de la cara visto de frente) y en el alfa del color del vértice
// si es el frente de la cabeza: sin eso la cara salía también en la nuca.
uniform sampler2D caras : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 celda_cara = vec2(0.0);
uniform vec2 tam_celda_cara = vec2(0.2, 0.05);

// El dorsal: cifras del atlas de tools/generar_numeros.py (una celda por
// cifra, del 0 al 9). Jugador3D le da a la espalda de la camiseta el UV2 del
// rectángulo del número y el alfa del color del vértice en 1 (como la cara).
// Con dos cifras cada una ocupa la mitad; con una, va al medio. Espejado
// (escala x negativa) se da vuelta el U: si no, el número se leía al revés.
uniform sampler2D numeros : source_color, filter_linear_mipmap, repeat_disable;
uniform int cifras = 0;
uniform int cifra_1 = 0;
uniform int cifra_2 = 0;
uniform vec4 color_numero : source_color = vec4(1.0);
uniform float espejo = 0.0;

uniform vec3 tono_sombra = vec3(0.72, 0.62, 0.66);
uniform float tono_luz = 1.13;
uniform float umbral_sombra = 0.35;
uniform float umbral_luz = 0.8;

varying flat int tipo;
varying flat float alfa;

vec3 lineal(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	tipo = int(round(UV.x));
	alfa = 1.0 - UV.y; // glTF da vuelta la V
}

void fragment() {
	// El color del vértice viene en sRGB. Compatibility ilumina en sRGB (así
	// también usa los source_color); Forward+ y Mobile, en lineal.
	vec3 c = COLOR.rgb;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	c = lineal(c);
#endif
	if (tipo == 1) {
		c = camiseta.rgb;
	} else if (tipo == 2) {
		c = color_short.rgb;
	} else if (tipo == 3) {
		c = pelo.rgb;
	} else if (tipo == 4) {
		c = piel.rgb;
	}
	// Se muestrea siempre, fuera del if: adentro de una rama las derivadas
	// del mipmap no están definidas.
	vec2 en_cara = clamp(UV2, vec2(0.0), vec2(1.0));
	vec4 dibujo = texture(caras, celda_cara + en_cara * tam_celda_cara);
	bool es_cara = tipo == 4 && COLOR.a > 0.5 && en_cara == UV2;
	// Dorsal: en qué celda cae este punto. Las derivadas van aparte
	// (textureGrad): entre las dos cifras la celda salta y el mipmap del
	// borde se veía como una raya.
	float u = mix(UV2.x, 1.0 - UV2.x, espejo);
	float en_cifra = cifras == 2 ? fract(u * 2.0) : u * 2.0 - 0.5;
	int cual = cifras == 2 && u >= 0.5 ? cifra_2 : cifra_1;
	vec2 celda = vec2((float(cual) + clamp(en_cifra, 0.0, 1.0)) / 10.0, clamp(UV2.y, 0.0, 1.0));
	vec2 escala_uv = vec2(0.2, 1.0);
	vec4 cifra = textureGrad(numeros, celda, dFdx(UV2) * escala_uv, dFdy(UV2) * escala_uv);
	bool es_numero = tipo == 1 && COLOR.a > 0.5 && cifras > 0
		&& u >= 0.0 && u <= 1.0 && en_cifra >= 0.0 && en_cifra <= 1.0
		&& UV2.y >= 0.0 && UV2.y <= 1.0;
	if (es_numero) {
		c = mix(c, color_numero.rgb, cifra.a);
	}
	if (es_cara) {
		// Líneas, ojos y boca (opacos) van sin luz, como en el modelo. El
		// rubor y las ojeras (alfa <= 0.55) se mezclan con la piel y reciben
		// luz: sin luz el rosado quedaba más oscuro que la piel iluminada y
		// se veía marrón (igual que los cachetes del modelo).
		float sin_luz = smoothstep(0.6, 0.95, dibujo.a);
		ALBEDO = mix(c, dibujo.rgb, dibujo.a) * (1.0 - sin_luz);
		EMISSION = dibujo.rgb * sin_luz;
	} else if (tipo == 5) {
		ALBEDO = vec3(0.0);
		EMISSION = c;
	} else if (tipo == 6) {
		// Lo que hacía la mezcla con alfa: la piel con su luz y el rosado encima.
		ALBEDO = piel.rgb * (1.0 - alfa);
		EMISSION = c * alfa;
	} else if (tipo == 7) {
		ALBEDO = vec3(0.0);
		EMISSION = color_contorno.rgb;
	} else {
		ALBEDO = c;
	}
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	vec3 tono = nl < umbral_sombra ? tono_sombra : (nl < umbral_luz ? vec3(1.0) : vec3(tono_luz));
	DIFFUSE_LIGHT += tono * LIGHT_COLOR / PI;
}
