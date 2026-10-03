#pragma once

// Remates y arqueros (docs/motor_v2.md, etapa 5): lo que necesitan el que
// patea al arco y el arquero que lo espera.
//
// Nadie adjudica el resultado. El que remata elige un punto del arco y un
// tipo de golpe; `apuntar` busca con la misma física de la pelota la patada
// que llega a ese punto, y al patear se le suma un error según tiro, pie
// malo, postura y presión. Gol, palo, afuera o atajada salen del vuelo: el
// arquero lee la trayectoria, elige parado o estirada y su mano tiene una
// ventana de contacto como cualquier gesto.
//
// Sin Godot: solo C++ y matematica_fija.h.

#include "cuerpo.h"
#include "pelota.h"

namespace motor_v2 {

// Tipos de golpe. Con la cabeza es otro gesto (Cabecear o Palomita), pero se
// apunta igual.
enum TipoRemate : int {
	REMATE_COLOCADO = 0,
	REMATE_FUERTE = 1,
	REMATE_EFECTO = 2,
	REMATE_GLOBO = 3,
	REMATE_CABEZA = 4,
	TIPOS_REMATE = 5,
};

// Salen de data/fisica_v2.json ("remate"; ahí está el porqué de cada uno).
// tests/test_remate_v2.gd falla si se separan.
struct ParametrosRemate {
	// Rapidez de salida (m/s) con el atributo en 0 y en 100 (relativo al
	// nivel del partido): tiro para colocado, efecto y globo; golpe para el
	// fuerte; cabezazo para la cabeza.
	double colocado_min_ms = 19.0, colocado_max_ms = 25.0;
	double fuerte_min_ms = 25.0, fuerte_max_ms = 33.0;
	double efecto_min_ms = 22.0, efecto_max_ms = 28.0;
	double cabeza_min_ms = 13.0, cabeza_max_ms = 20.0;
	// Giro de costado del remate con efecto (rad/s).
	double giro_efecto = 45.0;
	// Ángulo de salida del globo (rad): la rapidez la busca `apuntar`.
	double elevacion_globo = 0.7;
	// Error del ángulo (desvío estándar, rad) con el atributo en 0; con 100
	// es el 20%. El vertical es una fracción del horizontal.
	double error_rad = 0.15;
	double error_vertical = 0.4;
	double error_rapidez = 0.06;
	// Cuánto multiplica el error cada tipo de golpe.
	double error_tipo[TIPOS_REMATE] = { 0.8, 1.3, 1.1, 1.2, 1.4 };
	// De primera: el error crece con la rapidez de la pelota que llega
	// (1 + rapidez / primera_ms).
	double primera_ms = 25.0;
	// Cruzarla hacia el lado del pie malo: hasta 1 + pie_malo.
	double pie_malo = 0.5;
	// El cabezazo con un rival encima: hasta 1 + cabeza_marcado.
	double cabeza_marcado = 3.0;
	// El remate de pie de primera con un rival encima: hasta 1 + primera_marcado.
	double primera_marcado = 2.0;
	// La pelota a la altura de la rodilla o más (volea): 1 + alto_factor.
	double alto_factor = 0.5;
	// Desde qué distancia al arco (m) remata de primera un receptor, y qué
	// factor_geometria necesita.
	double primera_geometria = 0.25;
	// Clips (índices en los clips del cuerpo); los pone quien configura.
	int clip_pie = -1;
	int clip_efecto = -1;
	int clip_volea = -1;
	int clip_palomita = -1;
	int clip_cabeza = -1;
};

// Los clips de atajada que puede elegir el arquero.
enum ClipArquero : int {
	ATAJA_AGARRA = 0,
	ATAJA_ABAJO = 1,
	ATAJA_ARRIBA = 2,
	// Estiradas: hacia su derecha (el clip de Blender) y hacia su izquierda.
	ATAJA_VUELA_DER = 3,
	ATAJA_VUELA_IZQ = 4,
	ATAJA_VUELA_ALTA_DER = 5,
	ATAJA_VUELA_ALTA_IZQ = 6,
	CLIPS_ARQUERO = 7,
};

// Salen de data/fisica_v2.json ("arquero"). El achique y el lugar en la línea
// reusan data/utility_pesos.json ("arquero"), los del motor espacial.
struct ParametrosArquero {
	// Lo que tarda en leer el remate: con reflejos 0 y con 100.
	double reaccion_lenta_seg = 0.44, reaccion_rapida_seg = 0.21;
	// Cuánto puede errarle la mano a la pelota en el piso y tocarla igual:
	// con estirada 0 y con 100 (el ajuste de mano de la vista lo tapa).
	double tolerancia_min_m = 0.25, tolerancia_max_m = 0.5;
	// Y de alto; las estiradas suman el salto que dibuja la vista.
	double tolerancia_alto_m = 0.35;
	double salto_estirada_m = 0.5;
	// En la estirada toca con el brazo entero: desde brazo_desde del camino
	// del cuerpo a la mano (el hombro) hasta la mano.
	double brazo_desde = 0.35;
	// Cuánto gira el cuerpo para llevar la mano a la pelota.
	double giro_alcance_rad = 0.5;
	// Ataja parado (Agarrar, Atajar_Abajo, Atajar_Arriba) solo si se corre
	// hasta esto; si no, se tira. Es la regla de la vista 3D actual
	// (VistaCancha3D.PARADA_TRAVESIA_M): FisicaV2 la lee de ahí.
	double parada_max_m = 1.0;
	// Probabilidad de retenerla: base + por_atributo × agarre (0..1), menos
	// por_rapidez por cada m/s arriba de rapidez_comoda, menos castigo_estirada
	// si se tiró y castigo_borde si la tocó con la punta (al borde de la
	// tolerancia).
	double agarre_base = 0.45, agarre_por_atributo = 0.45;
	double agarre_por_rapidez = 0.03, rapidez_comoda_ms = 12.0;
	double castigo_estirada = 0.25, castigo_borde = 0.35;
	// Con la punta (más allá de roce_desde de la tolerancia) no la despeja: la
	// desvía y la pelota sigue con roce_conserva de su rapidez.
	double roce_desde = 0.75, roce_conserva = 0.75, roce_desvio_rad = 0.35;
	// El rebote: sale con rebote_factor de la rapidez que traía (mínimo
	// rebote_min_ms), hacia afuera y hacia el costado de la estirada.
	double rebote_factor = 0.35, rebote_min_ms = 4.0, rebote_dispersion_rad = 0.6;
	// Cuánto la retiene en las manos antes de soltarla para sacar.
	double retiene_seg = 1.5;
	// Sobre la bisectriz, adelante de la línea linea_por_metro por cada metro
	// que la pelota está del arco, entre linea_m y linea_max_m: más cerca, más
	// ángulo le tapa.
	double linea_m = 0.8, linea_max_m = 3.0, linea_por_metro = 0.15;
	// Parado en su área tapa con el cuerpo y los brazos abiertos: la pelota
	// rebota contra un cilindro de este radio y este alto (los de campo, con
	// las piernas: toque.radio_piernas y alto_cuerpo).
	double radio_cuerpo_m = 0.45, alto_cuerpo_m = 1.6;
	// Mano a mano (data/utility_pesos.json, "arquero", los del motor
	// espacial): sale de achique_min a achique_max metros según achique, si
	// el rival con pelota está a achique_dist_rival o menos y ningún compañero
	// a achique_carril de su camino al arco; nunca a menos de
	// achique_margen_pelota de la pelota.
	double achique_min = 2.5, achique_max = 6.5, achique_dist_rival = 24.0;
	double achique_margen_pelota = 4.0, achique_carril = 2.5;
	// Sale a cortar una pelota de su área solo si llega ventaja_base segundos
	// antes que el rival más rápido, más ventaja_por_metro por cada metro que
	// se aleja de la línea (data/utility_pesos.json, "arquero").
	double ventaja_base = 0.25, ventaja_por_metro = 0.02;
	// Sale a una pelota alta de su área si la alcanza con las manos (el clip
	// de atajar arriba más su tolerancia de alto). El que tiene poco achique
	// la calcula mal: cree que llega salida_error_alto_m más arriba con
	// achique 0 (nada con 100), sale y la pelota le pasa por arriba.
	double salida_error_alto_m = 0.6;
	// Y se tira sin llegar a la pelota hasta salida_error_m más lejos de lo
	// que alcanza (con achique 0; nada con 100).
	double salida_error_m = 1.5;
	int clips[CLIPS_ARQUERO] = { -1, -1, -1, -1, -1, -1, -1 };
	// Se levanta después de tirarse hacia su derecha o su izquierda
	// (Arquero_Levanta: arranca en la pose en que cae la estirada, 1,3 m al
	// costado, y termina parado en su lugar). Ver Canchita::_levantarse.
	int clip_levanta_der = -1, clip_levanta_izq = -1;
};

// Busca la patada (velocidad y giro) que lleva la pelota desde `desde` hasta
// cruzar el plano x = meta.x por (meta.y, meta.z), con la física de la
// pelota sin viento (el que patea no lo sabe: es parte del error). Con
// `rapidez` fija busca los dos ángulos; con `elevacion_fija` >= 0 busca el
// ángulo horizontal y la rapidez. `giro_lateral` es el efecto (rad/s,
// alrededor de la vertical). Un punto a ras del piso (meta.y hasta
// ALTO_RASANTE_M) es un remate rasante: sale por el piso y solo se busca el
// ángulo horizontal. Devuelve false si no hay patada que llegue.
constexpr double ALTO_RASANTE_M = 0.3;
bool apuntar(const ParametrosPelota &param, V3 desde, V3 meta, double rapidez, double elevacion_fija,
		double giro_lateral, V3 &vel, V3 &giro);

// Dónde cruza la pelota el plano x = plano_x, y en cuántos segundos. Simula
// la pelota (copia) hasta `max_seg`. Devuelve false si no llega. `pico`: si
// picó antes de cruzar.
bool cruce_con_plano(const Pelota &p, double plano_x, double max_seg, V3 &donde, double &segundos,
		bool *pico = nullptr);

// Los números de un atributo 0..100 entre `en_0` y `en_100`.
double segun_atributo(double atributo, double en_0, double en_100);

} // namespace motor_v2
