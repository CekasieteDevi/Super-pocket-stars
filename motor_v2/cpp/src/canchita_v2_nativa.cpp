#include "canchita_v2_nativa.h"
#include "cerebro_v2_nativo.h"
#include "cuerpos_v2_nativos.h"
#include "matematica_fija.h"
#include "pelota_v2_nativa.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <chrono>
#include <algorithm>
#include <cmath>

using namespace godot;

namespace {
void leer(const Dictionary &d, const char *clave, double &destino) {
	if (d.has(clave)) {
		destino = double(d[clave]);
	}
}

int indice(const std::vector<String> &nombres, const Variant &nombre) {
	String n = nombre;
	for (size_t k = 0; k < nombres.size(); k++) {
		if (nombres[k] == n) {
			return int(k);
		}
	}
	return -1;
}

Vector3 a_godot(motor_v2::V3 v) {
	return Vector3(real_t(v.x), real_t(v.y), real_t(v.z));
}
} // namespace

void godot::leer_parametros_toque(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosToque &p) {
	leer(d, "tolerancia_m", p.tolerancia_m);
	leer(d, "tolerancia_alto_m", p.tolerancia_alto_m);
	leer(d, "gatillo_m", p.gatillo_m);
	leer(d, "radio_piernas", p.radio_piernas);
	leer(d, "alto_cuerpo", p.alto_cuerpo);
	leer(d, "restitucion_cuerpo", p.restitucion_cuerpo);
	leer(d, "reaccion_seg", p.reaccion_seg);
	leer(d, "pie_hasta", p.pie_hasta);
	leer(d, "muslo_hasta", p.muslo_hasta);
	leer(d, "pecho_hasta", p.pecho_hasta);
	leer(d, "pecho_control_hasta", p.pecho_control_hasta);
	leer(d, "cabeza_hasta", p.cabeza_hasta);
	leer(d, "llegada_pase_ms", p.llegada_pase_ms);
	leer(d, "pase_min_ms", p.pase_min_ms);
	leer(d, "pase_max_ms", p.pase_max_ms);
	leer(d, "elevacion_globo", p.elevacion_globo);
	leer(d, "error_pase_rad", p.error_pase_rad);
	leer(d, "error_pase_rapidez", p.error_pase_rapidez);
	leer(d, "presion_m", p.presion_m);
	leer(d, "control_ms", p.control_ms);
	leer(d, "error_control_rad", p.error_control_rad);
	leer(d, "error_control_ms", p.error_control_ms);
	leer(d, "toque_largo_m", p.toque_largo_m);
	leer(d, "toque_corto_m", p.toque_corto_m);
	leer(d, "conduccion_factor", p.conduccion_factor);
	leer(d, "conduce_gana_seg", p.conduce_gana_seg);
	leer(d, "conduce_inercia", p.conduce_inercia);
	leer(d, "control_raya_m", p.control_raya_m);
	leer(d, "sin_rebote_seg", p.sin_rebote_seg);
	leer(d, "margen_seguro_seg", p.margen_seguro_seg);
	leer(d, "giro_alcance_rad", p.giro_alcance_rad);
	leer(d, "regate_largo_m", p.regate_largo_m);
	leer(d, "regate_pica_base", p.regate_pica_base);
	leer(d, "regate_pica_por_punto", p.regate_pica_por_punto);
	leer(d, "regate_pasado_seg", p.regate_pasado_seg);
	leer(d, "regate_pica_m", p.regate_pica_m);
	if (d.has("clip_pase")) {
		p.clip_pase = indice(nombres, d["clip_pase"]);
	}
	if (d.has("clip_conduce")) {
		p.clip_conduce = indice(nombres, d["clip_conduce"]);
	}
	if (d.has("clip_recepcion")) {
		Array r = d["clip_recepcion"];
		for (int64_t k = 0; k < r.size() && k < 4; k++) {
			p.clip_recepcion[k] = indice(nombres, r[k]);
		}
	}
	if (d.has("clips_regate")) {
		Array r = d["clips_regate"];
		for (int64_t k = 0; k < r.size() && k < motor_v2::REGATES; k++) {
			p.clips_regate[k] = indice(nombres, r[k]);
		}
	}
}

namespace {
// Cada número del remate y del arquero: su clave en el JSON y dónde va.
struct NumeroRemate {
	const char *clave;
	double motor_v2::ParametrosRemate::*campo;
};
const NumeroRemate NUMEROS_REMATE[] = {
	{ "colocado_min_ms", &motor_v2::ParametrosRemate::colocado_min_ms },
	{ "colocado_max_ms", &motor_v2::ParametrosRemate::colocado_max_ms },
	{ "fuerte_min_ms", &motor_v2::ParametrosRemate::fuerte_min_ms },
	{ "fuerte_max_ms", &motor_v2::ParametrosRemate::fuerte_max_ms },
	{ "efecto_min_ms", &motor_v2::ParametrosRemate::efecto_min_ms },
	{ "efecto_max_ms", &motor_v2::ParametrosRemate::efecto_max_ms },
	{ "cabeza_min_ms", &motor_v2::ParametrosRemate::cabeza_min_ms },
	{ "cabeza_max_ms", &motor_v2::ParametrosRemate::cabeza_max_ms },
	{ "giro_efecto", &motor_v2::ParametrosRemate::giro_efecto },
	{ "elevacion_globo", &motor_v2::ParametrosRemate::elevacion_globo },
	{ "error_rad", &motor_v2::ParametrosRemate::error_rad },
	{ "error_vertical", &motor_v2::ParametrosRemate::error_vertical },
	{ "error_rapidez", &motor_v2::ParametrosRemate::error_rapidez },
	{ "primera_ms", &motor_v2::ParametrosRemate::primera_ms },
	{ "pie_malo", &motor_v2::ParametrosRemate::pie_malo },
	{ "cabeza_marcado", &motor_v2::ParametrosRemate::cabeza_marcado },
	{ "primera_marcado", &motor_v2::ParametrosRemate::primera_marcado },
	{ "alto_factor", &motor_v2::ParametrosRemate::alto_factor },
	{ "primera_geometria", &motor_v2::ParametrosRemate::primera_geometria },
	{ "primera_geometria_centro", &motor_v2::ParametrosRemate::primera_geometria_centro },
	{ "taco_desde_rad", &motor_v2::ParametrosRemate::taco_desde_rad },
	{ "taco_tiro", &motor_v2::ParametrosRemate::taco_tiro },
};
const char *GOLPES[motor_v2::TIPOS_REMATE] = { "colocado", "fuerte", "efecto", "globo", "cabeza" };

struct NumeroArquero {
	const char *clave;
	double motor_v2::ParametrosArquero::*campo;
};
const NumeroArquero NUMEROS_ARQUERO[] = {
	{ "reaccion_lenta_seg", &motor_v2::ParametrosArquero::reaccion_lenta_seg },
	{ "reaccion_rapida_seg", &motor_v2::ParametrosArquero::reaccion_rapida_seg },
	{ "tolerancia_min_m", &motor_v2::ParametrosArquero::tolerancia_min_m },
	{ "tolerancia_max_m", &motor_v2::ParametrosArquero::tolerancia_max_m },
	{ "tolerancia_alto_m", &motor_v2::ParametrosArquero::tolerancia_alto_m },
	{ "salto_estirada_m", &motor_v2::ParametrosArquero::salto_estirada_m },
	{ "brazo_desde", &motor_v2::ParametrosArquero::brazo_desde },
	{ "giro_alcance_rad", &motor_v2::ParametrosArquero::giro_alcance_rad },
	{ "parada_max_m", &motor_v2::ParametrosArquero::parada_max_m },
	{ "agarre_base", &motor_v2::ParametrosArquero::agarre_base },
	{ "agarre_por_atributo", &motor_v2::ParametrosArquero::agarre_por_atributo },
	{ "agarre_por_rapidez", &motor_v2::ParametrosArquero::agarre_por_rapidez },
	{ "rapidez_comoda_ms", &motor_v2::ParametrosArquero::rapidez_comoda_ms },
	{ "castigo_estirada", &motor_v2::ParametrosArquero::castigo_estirada },
	{ "castigo_borde", &motor_v2::ParametrosArquero::castigo_borde },
	{ "roce_desde", &motor_v2::ParametrosArquero::roce_desde },
	{ "roce_conserva", &motor_v2::ParametrosArquero::roce_conserva },
	{ "roce_desvio_rad", &motor_v2::ParametrosArquero::roce_desvio_rad },
	{ "rebote_factor", &motor_v2::ParametrosArquero::rebote_factor },
	{ "rebote_min_ms", &motor_v2::ParametrosArquero::rebote_min_ms },
	{ "rebote_dispersion_rad", &motor_v2::ParametrosArquero::rebote_dispersion_rad },
	{ "retiene_seg", &motor_v2::ParametrosArquero::retiene_seg },
	{ "linea_m", &motor_v2::ParametrosArquero::linea_m },
	{ "linea_max_m", &motor_v2::ParametrosArquero::linea_max_m },
	{ "linea_por_metro", &motor_v2::ParametrosArquero::linea_por_metro },
	{ "radio_cuerpo_m", &motor_v2::ParametrosArquero::radio_cuerpo_m },
	{ "alto_cuerpo_m", &motor_v2::ParametrosArquero::alto_cuerpo_m },
	{ "achique_min", &motor_v2::ParametrosArquero::achique_min },
	{ "achique_max", &motor_v2::ParametrosArquero::achique_max },
	{ "achique_dist_rival", &motor_v2::ParametrosArquero::achique_dist_rival },
	{ "achique_margen_pelota", &motor_v2::ParametrosArquero::achique_margen_pelota },
	{ "achique_carril", &motor_v2::ParametrosArquero::achique_carril },
	{ "ventaja_base", &motor_v2::ParametrosArquero::ventaja_base },
	{ "ventaja_por_metro", &motor_v2::ParametrosArquero::ventaja_por_metro },
	{ "salida_error_alto_m", &motor_v2::ParametrosArquero::salida_error_alto_m },
	{ "salida_error_m", &motor_v2::ParametrosArquero::salida_error_m },
};
const char *CLIPS_ARQUERO[motor_v2::CLIPS_ARQUERO] = { "clip_agarra", "clip_abajo", "clip_arriba", "clip_vuela_der",
	"clip_vuela_izq", "clip_vuela_alta_der", "clip_vuela_alta_izq" };
const char *CLIPS_REMATE[6] = { "clip_pie", "clip_efecto", "clip_volea", "clip_palomita", "clip_cabeza", "clip_chilena" };
const char *ATRIBUTOS_CANCHITA[7] = { "tiro", "golpe", "cabezazo", "reflejos", "estirada", "agarre", "achique" };

// Etapa 6: data/fisica_v2.json, "reglas" (más lo que FisicaV2.parametros_reglas
// suma de data/utility_pesos.json y del motor espacial).
struct NumeroReglas {
	const char *clave;
	double motor_v2::ParametrosReglas::*campo;
};
const NumeroReglas NUMEROS_REGLAS[] = {
	{ "minutos_tiempo", &motor_v2::ParametrosReglas::minutos_tiempo },
	{ "minutos_alargue", &motor_v2::ParametrosReglas::minutos_alargue },
	{ "segundos_tiempo", &motor_v2::ParametrosReglas::segundos_tiempo },
	{ "cierre_max_seg", &motor_v2::ParametrosReglas::cierre_max_seg },
	{ "adicion_min_seg", &motor_v2::ParametrosReglas::adicion_min_seg },
	{ "adicion_max_seg", &motor_v2::ParametrosReglas::adicion_max_seg },
	{ "adicion_gol_seg", &motor_v2::ParametrosReglas::adicion_gol_seg },
	{ "adicion_cambio_seg", &motor_v2::ParametrosReglas::adicion_cambio_seg },
	{ "adicion_lesion_seg", &motor_v2::ParametrosReglas::adicion_lesion_seg },
	{ "adicion_tarjeta_seg", &motor_v2::ParametrosReglas::adicion_tarjeta_seg },
	{ "tarjeta_seg", &motor_v2::ParametrosReglas::tarjeta_seg },
	{ "recuperacion_entretiempo", &motor_v2::ParametrosReglas::recuperacion_entretiempo },
	{ "tope_entretiempo", &motor_v2::ParametrosReglas::tope_entretiempo },
	{ "reponer_seg", &motor_v2::ParametrosReglas::reponer_seg },
	{ "llegada_m", &motor_v2::ParametrosReglas::llegada_m },
	{ "ubicado_m", &motor_v2::ParametrosReglas::ubicado_m },
	{ "distancia_libre_m", &motor_v2::ParametrosReglas::distancia_libre_m },
	{ "distancia_lateral_m", &motor_v2::ParametrosReglas::distancia_lateral_m },
	{ "distancia_penal_m", &motor_v2::ParametrosReglas::distancia_penal_m },
	{ "saque_arco_m", &motor_v2::ParametrosReglas::saque_arco_m },
	{ "radio_circulo_m", &motor_v2::ParametrosReglas::radio_circulo_m },
	{ "lateral_min_ms", &motor_v2::ParametrosReglas::lateral_min_ms },
	{ "lateral_max_ms", &motor_v2::ParametrosReglas::lateral_max_ms },
	{ "lateral_elevacion_rad", &motor_v2::ParametrosReglas::lateral_elevacion_rad },
	{ "lateral_alto_m", &motor_v2::ParametrosReglas::lateral_alto_m },
	{ "lateral_espera_seg", &motor_v2::ParametrosReglas::lateral_espera_seg },
	{ "lateral_alcance_m", &motor_v2::ParametrosReglas::lateral_alcance_m },
	{ "ejecutor_max_m", &motor_v2::ParametrosReglas::ejecutor_max_m },
	{ "rango_libre_malo", &motor_v2::ParametrosReglas::rango_libre_malo },
	{ "rango_libre_bueno", &motor_v2::ParametrosReglas::rango_libre_bueno },
	{ "angulo_minimo_tiro_libre", &motor_v2::ParametrosReglas::angulo_minimo_tiro_libre },
	{ "dist_libre_al_area", &motor_v2::ParametrosReglas::dist_libre_al_area },
	{ "dist_para_colgar_lejos", &motor_v2::ParametrosReglas::dist_para_colgar_lejos },
	{ "area_desde_m", &motor_v2::ParametrosReglas::area_desde_m },
	{ "area_hasta_m", &motor_v2::ParametrosReglas::area_hasta_m },
	{ "area_ancho_m", &motor_v2::ParametrosReglas::area_ancho_m },
	{ "entrada_dist_m", &motor_v2::ParametrosReglas::entrada_dist_m },
	{ "entrada_prob", &motor_v2::ParametrosReglas::entrada_prob },
	{ "entrada_amonestado", &motor_v2::ParametrosReglas::entrada_amonestado },
	{ "falta_radio_m", &motor_v2::ParametrosReglas::falta_radio_m },
	{ "gravedad_a_fondo", &motor_v2::ParametrosReglas::gravedad_a_fondo },
	{ "gravedad_desde_atras", &motor_v2::ParametrosReglas::gravedad_desde_atras },
	{ "entrada_de_atras", &motor_v2::ParametrosReglas::entrada_de_atras },
	{ "falta_torpeza", &motor_v2::ParametrosReglas::falta_torpeza },
	{ "entrada_en_area", &motor_v2::ParametrosReglas::entrada_en_area },
	{ "entrada_sobrado", &motor_v2::ParametrosReglas::entrada_sobrado },
	{ "entrada_tumba", &motor_v2::ParametrosReglas::entrada_tumba },
	{ "entrada_por_quite", &motor_v2::ParametrosReglas::entrada_por_quite },
	{ "entrada_alcance_m", &motor_v2::ParametrosReglas::entrada_alcance_m },
	{ "entrada_tumba_m", &motor_v2::ParametrosReglas::entrada_tumba_m },
	{ "cruce_falta_prob", &motor_v2::ParametrosReglas::cruce_falta_prob },
	{ "caido_seg", &motor_v2::ParametrosReglas::caido_seg },
	{ "festejo_seg", &motor_v2::ParametrosReglas::festejo_seg },
	{ "festejo_grupo", &motor_v2::ParametrosReglas::festejo_grupo },
	{ "amarilla_por_falta", &motor_v2::ParametrosReglas::amarilla_por_falta },
	{ "roja_por_falta", &motor_v2::ParametrosReglas::roja_por_falta },
	{ "lesion_por_contacto", &motor_v2::ParametrosReglas::lesion_por_contacto },
	{ "lesionado_seg", &motor_v2::ParametrosReglas::lesionado_seg },
	{ "esfuerzo_base", &motor_v2::ParametrosReglas::esfuerzo_base },
	{ "esfuerzo_carrera", &motor_v2::ParametrosReglas::esfuerzo_carrera },
	{ "energia_minima", &motor_v2::ParametrosReglas::energia_minima },
	{ "cambio_desde_min", &motor_v2::ParametrosReglas::cambio_desde_min },
	{ "mano_alcance_m", &motor_v2::ParametrosReglas::mano_alcance_m },
	{ "mano_libre_m", &motor_v2::ParametrosReglas::mano_libre_m },
	{ "voleo_m", &motor_v2::ParametrosReglas::voleo_m },
	{ "juega_m", &motor_v2::ParametrosReglas::juega_m },
	{ "penal_adivina", &motor_v2::ParametrosReglas::penal_adivina },
	{ "penal_error", &motor_v2::ParametrosReglas::penal_error },
};
const char *PARADAS[motor_v2::PARADAS] = { "nada", "saque_medio", "lateral", "saque_arco", "corner", "tiro_libre",
	"penal" };
const char *EVENTOS[motor_v2::EVENTOS] = { "saque", "gol", "falta", "amarilla", "roja", "offside", "lesion", "cambio",
	"fin_tiempo", "penal_tanda", "quite", "jugada", "regate" };

void leer_cuatro(const Dictionary &d, const char *clave, double *destino) {
	if (!d.has(clave)) {
		return;
	}
	Array a = d[clave];
	for (int k = 0; k < 4 && k < a.size(); k++) {
		destino[k] = double(a[k]);
	}
}

Array cuatro(const double *v) {
	Array a;
	for (int k = 0; k < 4; k++) {
		a.push_back(v[k]);
	}
	return a;
}

// Lo que las reglas leen de un jugador: "reglas" (FisicaV2.reglas_de) y su rol.
void leer_ficha_reglas(const Dictionary &fisico, motor_v2::FichaReglas &f) {
	Dictionary d = fisico.get("reglas", Dictionary());
	f.id = int(d.get("id", -1));
	leer(d, "factor_amarilla", f.factor_amarilla);
	leer(d, "factor_roja", f.factor_roja);
	leer(d, "riesgo_lesion", f.riesgo_lesion);
	leer(d, "desgaste_minuto", f.desgaste_minuto);
	leer(d, "energia", f.energia);
	leer(d, "quite", f.quite);
	leer(d, "barrida", f.barrida);
	leer(d, "tiros_libres", f.tiros_libres);
	leer(d, "centros", f.centros);
	leer(d, "fuerza", f.fuerza);
	leer(d, "salto", f.salto);
	leer(d, "tiro", f.tiro);
	leer(d, "amenaza", f.amenaza);
	leer(d, "media", f.media);
	f.designado = int(d.get("designado", 0));
	leer(d, "penal_factor", f.penal_factor);
	leer(d, "penal_puntos", f.penal_puntos);
	String rol = fisico.get("rol", "MC");
	const char *roles[motor_v2::ROLES] = { "ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC" };
	for (int k = 0; k < motor_v2::ROLES; k++) {
		if (rol == roles[k]) {
			f.rol = k;
		}
	}
}
} // namespace

void godot::leer_parametros_reglas(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosReglas &p) {
	for (const NumeroReglas &n : NUMEROS_REGLAS) {
		leer(d, n.clave, p.*(n.campo));
	}
	Dictionary pausas = d.get("pausa_seg", Dictionary());
	Dictionary esperas = d.get("espera_max_seg", Dictionary());
	for (int k = 1; k < motor_v2::PARADAS; k++) {
		leer(pausas, PARADAS[k], p.pausa_seg[k]);
		leer(esperas, PARADAS[k], p.espera_max_seg[k]);
	}
	leer_cuatro(d, "franja_piso", p.franja_piso);
	leer_cuatro(d, "factor_franja", p.factor_franja);
	leer_cuatro(d, "riesgo_franja", p.riesgo_franja);
	if (d.has("cambios_max")) {
		p.cambios_max = int(d["cambios_max"]);
	}
	if (d.has("menos_en_centro")) {
		p.menos_en_centro = int(d["menos_en_centro"]);
	}
	if (d.has("menos_en_directo")) {
		p.menos_en_directo = int(d["menos_en_directo"]);
	}
	if (d.has("alargue")) {
		p.alargue = bool(d["alargue"]);
	}
	if (d.has("tanda")) {
		p.tanda = bool(d["tanda"]);
	}
	if (d.has("tanda_pateadores")) {
		p.tanda_pateadores = int(d["tanda_pateadores"]);
	}
	struct {
		const char *clave;
		int *campo;
	} clips[] = { { "clip_lateral", &p.clip_lateral }, { "clip_lateral_prepara", &p.clip_lateral_prepara },
		{ "clip_entrada", &p.clip_entrada }, { "clip_caer", &p.clip_caer }, { "clip_levantarse", &p.clip_levantarse },
		{ "clip_lesionado", &p.clip_lesionado }, { "clip_saque_arco", &p.clip_saque_arco },
		{ "clip_arquero_lanza", &p.clip_arquero_lanza }, { "clip_arquero_voleo", &p.clip_arquero_voleo },
		{ "clip_festejar", &p.clip_festejar } };
	for (auto &c : clips) {
		if (d.has(c.clave)) {
			*c.campo = indice(nombres, d[c.clave]);
		}
	}
}

void CanchitaV2Nativa::configurar_reglas(const Dictionary &reglas) {
	leer_parametros_reglas(reglas, _nombres, _c.param_reglas);
	_c.reglas = true;
}

void CanchitaV2Nativa::configurar_reglas_equipo(int64_t equipo, const Dictionary &club) {
	motor_v2::ParametrosReglas &p = _c.param_reglas;
	int e = int(equipo & 1);
	leer(club, "umbral_cambio", p.umbral_cambio[e]);
	if (club.has("suben_corner")) {
		p.suben_corner[e] = int(club["suben_corner"]);
	}
	if (club.has("cuelga_lejos")) {
		p.cuelga_lejos[e] = bool(club["cuelga_lejos"]);
	}
}

Dictionary CanchitaV2Nativa::reglas_de_fabrica() const {
	motor_v2::ParametrosReglas r;
	Dictionary d, pausas, esperas;
	for (const NumeroReglas &n : NUMEROS_REGLAS) {
		d[n.clave] = r.*(n.campo);
	}
	for (int k = 1; k < motor_v2::PARADAS; k++) {
		pausas[PARADAS[k]] = r.pausa_seg[k];
		esperas[PARADAS[k]] = r.espera_max_seg[k];
	}
	d["pausa_seg"] = pausas;
	d["espera_max_seg"] = esperas;
	d["franja_piso"] = cuatro(r.franja_piso);
	d["factor_franja"] = cuatro(r.factor_franja);
	d["riesgo_franja"] = cuatro(r.riesgo_franja);
	d["cambios_max"] = r.cambios_max;
	d["menos_en_centro"] = r.menos_en_centro;
	d["menos_en_directo"] = r.menos_en_directo;
	d["tanda_pateadores"] = r.tanda_pateadores;
	return d;
}

void godot::leer_parametros_remate(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosRemate &p) {
	for (const NumeroRemate &n : NUMEROS_REMATE) {
		leer(d, n.clave, p.*(n.campo));
	}
	if (d.has("error_tipo")) {
		Dictionary e = d["error_tipo"];
		for (int k = 0; k < motor_v2::TIPOS_REMATE; k++) {
			leer(e, GOLPES[k], p.error_tipo[k]);
		}
	}
	int *clips[6] = { &p.clip_pie, &p.clip_efecto, &p.clip_volea, &p.clip_palomita, &p.clip_cabeza, &p.clip_chilena };
	for (int k = 0; k < 6; k++) {
		if (d.has(CLIPS_REMATE[k])) {
			*clips[k] = indice(nombres, d[CLIPS_REMATE[k]]);
		}
	}
}

void godot::leer_parametros_arquero(const Dictionary &d, const std::vector<String> &nombres,
		motor_v2::ParametrosArquero &p) {
	for (const NumeroArquero &n : NUMEROS_ARQUERO) {
		leer(d, n.clave, p.*(n.campo));
	}
	for (int k = 0; k < motor_v2::CLIPS_ARQUERO; k++) {
		if (d.has(CLIPS_ARQUERO[k])) {
			p.clips[k] = indice(nombres, d[CLIPS_ARQUERO[k]]);
		}
	}
	if (d.has("clip_levanta_der")) {
		p.clip_levanta_der = indice(nombres, d["clip_levanta_der"]);
	}
	if (d.has("clip_levanta_izq")) {
		p.clip_levanta_izq = indice(nombres, d["clip_levanta_izq"]);
	}
}

void CanchitaV2Nativa::configurar_remate(const Dictionary &remate, const Dictionary &arquero) {
	leer_parametros_remate(remate, _nombres, _c.param_remate);
	leer_parametros_arquero(arquero, _nombres, _c.param_arquero);
}

Dictionary CanchitaV2Nativa::remate_de_fabrica() const {
	motor_v2::ParametrosRemate r;
	motor_v2::ParametrosArquero a;
	Dictionary dr, da, errores;
	for (const NumeroRemate &n : NUMEROS_REMATE) {
		dr[n.clave] = r.*(n.campo);
	}
	for (int k = 0; k < motor_v2::TIPOS_REMATE; k++) {
		errores[GOLPES[k]] = r.error_tipo[k];
	}
	dr["error_tipo"] = errores;
	for (const NumeroArquero &n : NUMEROS_ARQUERO) {
		da[n.clave] = a.*(n.campo);
	}
	Dictionary d;
	d["remate"] = dr;
	d["arquero"] = da;
	return d;
}

void CanchitaV2Nativa::rematar(int64_t i, int64_t golpe, double alto, double lateral) {
	_c.rematar(int(i), int(golpe), alto, lateral);
}

Dictionary CanchitaV2Nativa::apuntar_prueba(const Dictionary &pelota, const Vector3 &desde, const Vector3 &meta,
		double rapidez, double elevacion_fija, double giro_lateral) {
	motor_v2::ParametrosPelota p;
	leer_parametros_pelota(pelota, p);
	motor_v2::V3 vel, giro;
	motor_v2::V3 d0 = { desde.x, desde.y, desde.z };
	motor_v2::V3 m0 = { meta.x, meta.y, meta.z };
	bool ok = motor_v2::apuntar(p, d0, m0, rapidez, elevacion_fija, giro_lateral, vel, giro);
	Dictionary r;
	r["ok"] = ok;
	r["vel"] = a_godot(vel);
	r["giro"] = a_godot(giro);
	if (ok) {
		// Dónde cruza de verdad, sin viento, con la misma pelota.
		p.viento = {};
		motor_v2::Pelota bola;
		bola.configurar(p);
		bola.poner(d0, vel, giro);
		motor_v2::V3 donde;
		double segundos;
		motor_v2::cruce_con_plano(bola, m0.x, 3.0, donde, segundos);
		r["cruce"] = a_godot(donde);
		r["segundos"] = segundos;
	}
	return r;
}

void CanchitaV2Nativa::configurar(const Dictionary &pelota, const Dictionary &cuerpo, const Dictionary &clips,
		const Dictionary &toque) {
	_c = motor_v2::Canchita();
	leer_parametros_pelota(pelota, _c.param_pelota);
	leer_parametros_cuerpo(cuerpo, _c.param_cuerpo);
	leer_clips(clips, _c.clips, _nombres);
	leer_parametros_toque(toque, _nombres, _c.param_toque);
}

int64_t CanchitaV2Nativa::agregar(int64_t equipo, const Dictionary &fisico) {
	_agregar_jugador(int(equipo), fisico);
	return int64_t(_c.jugadores.size()) - 1;
}

void CanchitaV2Nativa::agregar_suplente(int64_t equipo, const Dictionary &fisico) {
	// Se arma igual que un titular y se pasa al banco.
	size_t fichas = _c.cerebro.fichas.size();
	_agregar_jugador(int(equipo), fisico);
	motor_v2::JugadorCanchita j = _c.jugadores.back();
	_c.jugadores.pop_back();
	motor_v2::FichaCerebro f;
	if (_c.cerebro.fichas.size() > fichas) {
		f = _c.cerebro.fichas.back();
		_c.cerebro.fichas.pop_back();
	}
	_c.agregar_suplente(int(equipo), j, f);
}

void CanchitaV2Nativa::_agregar_jugador(int equipo, const Dictionary &fisico) {
	motor_v2::Cuerpo c;
	leer(fisico, "vel_max", c.vel_max);
	leer(fisico, "aceleracion", c.aceleracion);
	leer(fisico, "giro", c.giro);
	leer(fisico, "cansancio", c.cansancio);
	double pases = 50.0, control = 50.0;
	leer(fisico, "pases", pases);
	leer(fisico, "control", control);
	_c.agregar(int(equipo), c, pases, control);
	// Etapa 5: relativos al nivel del partido si vienen; si no, sueltos.
	motor_v2::JugadorCanchita &j = _c.jugadores.back();
	double *atributos[7] = { &j.tiro, &j.golpe, &j.cabezazo, &j.reflejos, &j.estirada, &j.agarre, &j.achique };
	Dictionary relativos = fisico.get("relativos", Dictionary());
	for (int k = 0; k < 7; k++) {
		leer(fisico, ATRIBUTOS_CANCHITA[k], *atributos[k]);
		leer(relativos, ATRIBUTOS_CANCHITA[k], *atributos[k]);
	}
	j.pie_malo_lado = int(fisico.get("pie_malo_lado", 0));
	j.arquero = bool(fisico.get("arquero", false)) || String(fisico.get("rol", "")) == "ARQ";
	leer_ficha_reglas(fisico, j.reglas);
	if (fisico.has("rol")) {
		motor_v2::FichaCerebro f;
		leer_ficha_cerebro(int(equipo), fisico, f);
		_c.cerebro.agregar(f);
	}
}

void CanchitaV2Nativa::configurar_cerebro(const Dictionary &utility, const Dictionary &nuevos) {
	leer_pesos_cerebro(utility, nuevos, _c.cerebro.pesos);
}

void CanchitaV2Nativa::configurar_plan(int64_t equipo, const Dictionary &plan) {
	leer_plan_equipo(plan, _c.cerebro.planes[equipo & 1]);
}

Dictionary CanchitaV2Nativa::pesos_cerebro_de_fabrica() const {
	return pesos_cerebro_a_diccionario(motor_v2::PesosCerebro());
}

double CanchitaV2Nativa::exponencial(double x) {
	return mate::exponencial(x);
}

double CanchitaV2Nativa::logaritmo(double x) {
	return mate::logaritmo(x);
}

void CanchitaV2Nativa::empezar(int64_t modo, int64_t semilla) {
	_c.empezar(int(modo), semilla);
}

void CanchitaV2Nativa::poner_jugador(int64_t i, const Vector2 &pos, double rumbo) {
	_c.poner_jugador(int(i), pos.x, pos.y, rumbo);
}

void CanchitaV2Nativa::lanzar(const Vector3 &pos, const Vector3 &vel, const Vector3 &giro, int64_t equipo) {
	_c.lanzar({ pos.x, pos.y, pos.z }, { vel.x, vel.y, vel.z }, { giro.x, giro.y, giro.z }, int(equipo));
}

void CanchitaV2Nativa::avanzar() {
	_c.avanzar();
}

double CanchitaV2Nativa::simular(int64_t pasos) {
	auto inicio = std::chrono::steady_clock::now();
	for (int64_t k = 0; k < pasos; k++) {
		_c.avanzar();
	}
	std::chrono::duration<double> dura = std::chrono::steady_clock::now() - inicio;
	return dura.count();
}

bool CanchitaV2Nativa::_valido(int64_t i) const {
	return i >= 0 && i < int64_t(_c.jugadores.size());
}

int64_t CanchitaV2Nativa::cantidad() const {
	return int64_t(_c.jugadores.size());
}

PackedVector2Array CanchitaV2Nativa::get_pos() const {
	PackedVector2Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(Vector2(real_t(j.cuerpo.x), real_t(j.cuerpo.z)));
	}
	return r;
}

PackedVector2Array CanchitaV2Nativa::get_pos_previa() const {
	PackedVector2Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(Vector2(real_t(j.cuerpo.previa_x), real_t(j.cuerpo.previa_z)));
	}
	return r;
}

PackedFloat32Array CanchitaV2Nativa::get_rumbo() const {
	PackedFloat32Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(float(j.cuerpo.rumbo));
	}
	return r;
}

PackedFloat32Array CanchitaV2Nativa::get_rapidez() const {
	PackedFloat32Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(float(j.cuerpo.rapidez()));
	}
	return r;
}

PackedInt32Array CanchitaV2Nativa::get_equipos() const {
	PackedInt32Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(j.equipo);
	}
	return r;
}

String CanchitaV2Nativa::get_accion(int64_t i) const {
	if (!_valido(i) || _c.jugadores[size_t(i)].cuerpo.clip < 0) {
		return String();
	}
	return _nombres[size_t(_c.jugadores[size_t(i)].cuerpo.clip)];
}

int64_t CanchitaV2Nativa::get_fase(int64_t i) const {
	return _valido(i) ? int64_t(_c.jugadores[size_t(i)].cuerpo.fase) : 0;
}

double CanchitaV2Nativa::get_tiempo_accion(int64_t i) const {
	return _valido(i) ? _c.jugadores[size_t(i)].cuerpo.tiempo_accion : 0.0;
}

// Si el gesto en curso llega a la pelota (JugadorCanchita::alcanza).
bool CanchitaV2Nativa::get_alcanza(int64_t i) const {
	return !_valido(i) || _c.jugadores[size_t(i)].alcanza;
}

double CanchitaV2Nativa::get_rapidez_buscada(int64_t i) const {
	return _valido(i) ? _c.jugadores[size_t(i)].cuerpo.rapidez_buscada(_c.param_cuerpo) : 0.0;
}

double CanchitaV2Nativa::get_metros_para_parar(int64_t i) const {
	return _valido(i) ? _c.jugadores[size_t(i)].cuerpo.metros_para_parar(_c.param_cuerpo) : -1.0;
}

double CanchitaV2Nativa::get_giro_pendiente(int64_t i) const {
	return _valido(i) ? _c.jugadores[size_t(i)].cuerpo.giro_pendiente(_c.param_cuerpo) : 0.0;
}

double CanchitaV2Nativa::get_rumbo_buscado(int64_t i) const {
	return _valido(i) ? _c.jugadores[size_t(i)].cuerpo.rumbo_buscado() : 0.0;
}

int64_t CanchitaV2Nativa::get_poseedor() const {
	return _c.poseedor;
}

int64_t CanchitaV2Nativa::get_equipo_con_pelota() const {
	return _c.equipo_con_pelota;
}

int64_t CanchitaV2Nativa::get_ultimo_toque() const {
	return _c.ultimo_toque;
}

int64_t CanchitaV2Nativa::get_receptor() const {
	return _c.receptor();
}

int64_t CanchitaV2Nativa::get_en_manos() const {
	return _c.en_manos();
}

int64_t CanchitaV2Nativa::get_ultimo_resultado() const {
	return _c.ultimo_resultado();
}

PackedInt32Array CanchitaV2Nativa::get_arqueros() const {
	PackedInt32Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(j.arquero ? 1 : 0);
	}
	return r;
}

PackedInt32Array CanchitaV2Nativa::get_goles() const {
	PackedInt32Array r;
	r.push_back(int32_t(_c.cuenta.goles[0]));
	r.push_back(int32_t(_c.cuenta.goles[1]));
	return r;
}

Vector3 CanchitaV2Nativa::get_pelota_pos() const {
	return a_godot(_c.pelota.pos);
}

Vector3 CanchitaV2Nativa::get_pelota_previa() const {
	return a_godot(_c.pelota.previa);
}

Vector3 CanchitaV2Nativa::get_pelota_vel() const {
	return a_godot(_c.pelota.vel);
}

Vector3 CanchitaV2Nativa::get_pelota_giro() const {
	return a_godot(_c.pelota.giro);
}

PackedVector3Array CanchitaV2Nativa::prediccion() const {
	PackedVector3Array r;
	for (const motor_v2::V3 &p : _c.trayectoria.pos) {
		r.push_back(a_godot(p));
	}
	return r;
}

Dictionary CanchitaV2Nativa::contadores() const {
	const motor_v2::ContadoresCanchita &k = _c.cuenta;
	Dictionary d;
	d["pases"] = k.pases;
	d["pases_globo"] = k.pases_globo;
	d["pases_despeje"] = k.pases_despeje;
	d["salidas_pase"] = k.salidas_pase;
	d["salidas_conduce"] = k.salidas_conduce;
	d["salidas_control"] = k.salidas_control;
	d["salidas_remate"] = k.salidas_remate;
	d["salidas_rebote"] = k.salidas_rebote;
	d["salidas_otra"] = k.salidas_otra;
	d["conduce_pasos"] = k.conduce_pasos;
	d["conduce_lejos"] = k.conduce_lejos;
	d["conduce_metros"] = k.conduce_metros;
	d["conduce_corre"] = k.conduce_corre;
	d["conduce_max_m"] = k.conduce_max_m;
	for (int t = 0; t < 2; t++) {
		for (int f = 0; f < 5; f++) {
			d[String(t == 0 ? "separa_control_" : "separa_conduce_") + String::num_int64(f)] = k.separa[t][f];
			d[String(t == 0 ? "pierde_control_" : "pierde_conduce_") + String::num_int64(f)] = k.separa_pierde[t][f];
		}
	}
	d["lleva_pasos"] = k.lleva_pasos;
	{
		const char *decisiones[motor_v2::DECISIONES] = { "nada", "conducir", "pase", "pase_hueco", "pase_largo", "centro",
			"pared", "despeje", "remate", "regate" };
		for (int f = 0; f < 3; f++) {
			for (int t = 0; t < motor_v2::DECISIONES; t++) {
				d[String("libre") + String::num_int64(f) + "_" + decisiones[t]] = k.via_libre[f][t];
			}
		}
	}
	d["lleva_a_fondo"] = k.lleva_a_fondo;
	d["completados"] = k.completados;
	d["completados_otro"] = k.completados_otro;
	d["de_primera"] = k.de_primera;
	d["cortes"] = k.cortes;
	d["desvios"] = k.desvios;
	d["quites"] = k.quites;
	d["pases_afuera"] = k.pases_afuera;
	d["salidas"] = k.salidas;
	d["reinicios"] = k.reinicios;
	d["conducciones"] = k.conducciones;
	d["controles"] = k.controles;
	d["pie"] = k.recepciones[motor_v2::PIE];
	d["muslo"] = k.recepciones[motor_v2::MUSLO];
	d["pecho"] = k.recepciones[motor_v2::PECHO];
	d["cabeza"] = k.recepciones[motor_v2::CABEZA];
	d["fallos"] = k.fallos;
	{
		const char *partes[4] = { "pie", "muslo", "pecho", "cabeza" };
		for (int p = 0; p < 4; p++) {
			d[String("gestos_") + partes[p]] = k.gestos_parte[p];
			d[String("fallos_") + partes[p]] = k.fallos_parte[p];
			d[String("fallos_lejos_") + partes[p]] = k.fallos_lejos[p];
			d[String("fallos_altura_") + partes[p]] = k.fallos_altura[p];
			d[String("fallos_metros_") + partes[p]] = k.fallos_metros[p];
		}
	}
	d["cruces_perdidos"] = k.cruces_perdidos;
	d["rebotes_cuerpo"] = k.rebotes_cuerpo;
	d["correcciones"] = k.correcciones;
	d["corte_mas_lejos_m"] = k.corte_mas_lejos_m;
	d["recepciones_medidas"] = k.recepciones_medidas;
	d["espera_media"] = k.recepciones_medidas > 0 ? k.espera_suma / double(k.recepciones_medidas) : 0.0;
	d["espera_max"] = k.espera_max;
	d["esperas_largas"] = k.esperas_largas;
	d["frenadas_en_seco"] = k.frenadas_en_seco;
	d["peor_salto_cuerpo_m"] = k.peor_salto_cuerpo_m;
	d["saltos_pelota"] = _c.pelota.saltos;
	d["posesion_0"] = k.posesion_seg[0];
	d["posesion_1"] = k.posesion_seg[1];
	d["pasos"] = _c.paso;
	d["posesiones"] = k.posesiones;
	d["pases_en_posesiones"] = k.pases_en_posesiones;
	d["posesiones_3_pases"] = k.posesiones_3_pases;
	d["posesiones_5_pases"] = k.posesiones_5_pases;
	d["max_pases_posesion"] = k.max_pases_posesion;
	d["pases_al_espacio"] = k.pases_al_espacio;
	d["pases_al_espacio_completos"] = k.pases_al_espacio_completos;
	d["pases_a_corrida"] = k.pases_a_corrida;
	d["offsides"] = k.offsides;
	d["llegadas_0"] = k.llegadas[0];
	d["llegadas_1"] = k.llegadas[1];
	d["saques_de_arco"] = k.saques_de_arco;
	d["laterales"] = k.laterales;
	d["corners"] = k.corners;
	d["paredes_devueltas"] = k.paredes_devueltas;
	d["quites_conduccion"] = k.quites_conduccion;
	d["quites_control"] = k.quites_control;
	d["quites_suelta"] = k.quites_suelta;
	d["regates"] = k.regates;
	d["regates_amague"] = k.regates_amague;
	d["regates_ganados"] = k.regates_ganados;
	// Etapa 5: el embudo de remates.
	const char *resultados[motor_v2::RESULTADOS_REMATE] = { "gol", "atajado", "palo", "bloqueado", "afuera", "otro" };
	for (int r = 0; r < motor_v2::RESULTADOS_REMATE; r++) {
		d[String("remates_") + resultados[r]] = k.resultados[r];
	}
	for (int g = 0; g < motor_v2::TIPOS_REMATE; g++) {
		d[String("golpe_") + GOLPES[g]] = k.golpes[g];
	}
	d["remates"] = k.remates;
	d["remates_0"] = k.remates_equipo[0];
	d["remates_1"] = k.remates_equipo[1];
	d["remates_cabeza"] = k.remates_cabeza;
	d["remates_primera"] = k.remates_primera;
	d["giros_al_arco"] = k.giros_al_arco;
	d["goles_0"] = k.goles[0];
	d["goles_1"] = k.goles[1];
	d["goles_cabeza"] = k.goles_cabeza;
	d["distancia_remates"] = k.distancia_remates;
	d["remates_tras_rebote"] = k.remates_tras_rebote;
	d["goles_tras_rebote"] = k.goles_tras_rebote;
	d["agarres"] = k.agarres;
	d["rebotes_arquero"] = k.rebotes_arquero;
	d["roces_arquero"] = k.roces_arquero;
	d["estiradas"] = k.estiradas;
	d["paradas"] = k.paradas;
	d["salidas_arquero"] = k.salidas_arquero;
	d["atajadas_falladas"] = k.atajadas_falladas;
	d["salidas_falladas"] = k.salidas_falladas;
	d["salidas_por_arriba"] = k.salidas_por_arriba;
	d["salidas_lejos"] = k.salidas_lejos;
	// Etapa 6: las reglas.
	for (int t = 1; t < motor_v2::PARADAS; t++) {
		String n = PARADAS[t];
		d[String("paradas_") + n] = k.paradas_tipo[t];
		d[String("saques_") + n] = k.saques[t];
		d[String("espera_media_") + n] = k.saques[t] > 0 ? k.espera_parada_suma[t] / double(k.saques[t]) : 0.0;
		d[String("espera_max_") + n] = k.espera_parada_max[t];
		d[String("camina_") + n] = k.ejecutor_camina[t];
	}
	d["saques_de_lejos"] = k.saques_de_lejos;
	d["laterales_lentos"] = k.laterales_lentos;
	d["entradas"] = k.entradas;
	d["entradas_limpias"] = k.entradas_limpias;
	d["entrada_gana"] = k.entrada_gana;
	d["entradas_tumban"] = k.entradas_tumban;
	d["entrada_pierde"] = k.entrada_pierde;
	d["entrada_afuera"] = k.entrada_afuera;
	d["faltas_0"] = k.faltas[0];
	d["faltas_1"] = k.faltas[1];
	d["faltas_entrada"] = k.faltas_entrada;
	d["faltas_cruce"] = k.faltas_cruce;
	d["faltas_arquero"] = k.faltas_arquero;
	d["amarillas_0"] = k.amarillas[0];
	d["amarillas_1"] = k.amarillas[1];
	d["rojas_0"] = k.rojas[0];
	d["rojas_1"] = k.rojas[1];
	d["rojas_directas"] = k.rojas_directas;
	d["gravedad_media"] = (k.faltas[0] + k.faltas[1]) > 0 ? k.gravedad_suma / double(k.faltas[0] + k.faltas[1]) : 0.0;
	d["gravedad_max"] = k.gravedad_max;
	d["offsides_cobrados_0"] = k.offsides_cobrados[0];
	d["offsides_cobrados_1"] = k.offsides_cobrados[1];
	d["penales"] = k.penales;
	d["penales_gol"] = k.penales_gol;
	d["lesiones"] = k.lesiones;
	d["cambios_0"] = k.cambios[0];
	d["cambios_1"] = k.cambios[1];
	d["libres_corto"] = k.tiros_libres[motor_v2::LIBRE_CORTO];
	d["libres_centro"] = k.tiros_libres[motor_v2::LIBRE_CENTRO];
	d["libres_directo"] = k.tiros_libres[motor_v2::LIBRE_DIRECTO];
	d["arquero_mano"] = k.arquero_mano;
	d["arquero_voleo"] = k.arquero_voleo;
	d["arquero_pie"] = k.arquero_pie;

	return d;
}

Array CanchitaV2Nativa::eventos() const {
	Array r;
	for (const motor_v2::EventoPartido &e : _c.eventos) {
		Dictionary d;
		d["paso"] = e.paso;
		d["minuto"] = e.minuto;
		d["tipo"] = EVENTOS[std::clamp(e.tipo, 0, motor_v2::EVENTOS - 1)];
		d["equipo"] = e.equipo;
		d["jugador"] = e.jugador;
		d["otro"] = e.otro;
		d["detalle"] = e.detalle;
		d["pos"] = Vector2(real_t(e.x), real_t(e.z));
		r.push_back(d);
	}
	return r;
}

PackedInt32Array CanchitaV2Nativa::get_ids() const {
	PackedInt32Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(j.reglas.id);
	}
	return r;
}

// Etapa 8: la energía de todos al terminar, por id de Player: los que están
// en la cancha, los que salieron (con la que se fueron) y el banco.
Dictionary CanchitaV2Nativa::energias_por_id() const {
	Dictionary d;
	for (const motor_v2::Suplente &s : _c.banco) {
		d[s.jugador.reglas.id] = s.jugador.reglas.energia;
	}
	for (const std::pair<int, double> &e : _c.energia_al_salir) {
		d[e.first] = e.second;
	}
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		d[j.reglas.id] = j.energia;
	}
	return d;
}

PackedFloat32Array CanchitaV2Nativa::get_energias() const {
	PackedFloat32Array r;
	for (const motor_v2::JugadorCanchita &j : _c.jugadores) {
		r.push_back(float(j.energia));
	}
	return r;
}

Array CanchitaV2Nativa::get_afuera() const {
	Array r;
	for (const motor_v2::Saliente &s : _c.afuera) {
		Dictionary d;
		d["id"] = s.id;
		d["equipo"] = s.equipo;
		d["pos"] = Vector2(real_t(s.cuerpo.x), real_t(s.cuerpo.z));
		d["rumbo"] = s.cuerpo.rumbo;
		d["rapidez"] = s.cuerpo.rapidez();
		d["expulsado"] = s.expulsado;
		d["accion"] = s.cuerpo.clip >= 0 ? _nombres[size_t(s.cuerpo.clip)] : String();
		d["tiempo_accion"] = s.cuerpo.tiempo_accion;
		r.push_back(d);
	}
	return r;
}

Dictionary CanchitaV2Nativa::get_estado() const {
	Dictionary d;
	const char *periodos[6] = { "primer_tiempo", "segundo_tiempo", "alargue_1", "alargue_2", "tanda", "terminado" };
	d["periodo"] = periodos[std::clamp(_c.periodo, 0, 5)];
	d["reloj"] = _c.reloj_seg();
	d["minuto"] = _c.minuto();
	d["adicion"] = _c.adicion_seg();
	d["lado"] = _c.lado();
	d["suspendido"] = _c.suspendido();
	d["paso"] = _c.paso;
	d["corte"] = _c.corte_paso;
	PackedInt32Array entrando;
	for (int e : _c.entrando()) {
		entrando.push_back(e);
	}
	d["entrando"] = entrando;
	// El que festeja el gol (índice), -1 si no hay festejo.
	d["festeja"] = _c.festeja();
	d["parada"] = PARADAS[std::clamp(_c.parada_tipo(), 0, motor_v2::PARADAS - 1)];
	d["ejecutor"] = _c.parada_ejecutor();
	d["saca"] = _c.parada_equipo();
	motor_v2::V3 p = _c.parada_punto();
	d["punto"] = Vector2(real_t(p.x), real_t(p.z));
	d["goles_tanda"] = Vector2i(_c.goles_tanda[0], _c.goles_tanda[1]);
	d["pateados_tanda"] = Vector2i(_c.pateados_tanda[0], _c.pateados_tanda[1]);
	return d;
}

bool CanchitaV2Nativa::forzar_parada(const String &tipo, int64_t equipo, const Vector2 &pos) {
	for (int k = 1; k < motor_v2::PARADAS; k++) {
		if (tipo == PARADAS[k]) {
			return _c.forzar_parada(k, int(equipo), pos.x, pos.y);
		}
	}
	return false;
}

bool CanchitaV2Nativa::forzar_falta(int64_t tarjeta, bool lesion) {
	return _c.forzar_falta(int(tarjeta), lesion);
}

bool CanchitaV2Nativa::forzar_fin_de_tiempo() {
	return _c.forzar_fin_de_tiempo();
}

int64_t CanchitaV2Nativa::get_lateral_en_manos() const {
	return _c.lateral_en_manos();
}

Array CanchitaV2Nativa::registro_pases() const {
	Array r;
	for (const motor_v2::RegistroPase &g : _c.registro_pases) {
		Dictionary d;
		d["paso"] = g.paso;
		d["paso_fin"] = g.paso_fin;
		d["equipo"] = g.equipo;
		d["pateador"] = g.pateador;
		d["pateador_id"] = g.pateador_id;
		d["toca_id"] = g.toca_id;
		d["receptor"] = g.receptor;
		d["tipo"] = g.tipo;
		d["minuto"] = g.minuto;
		d["globo"] = g.globo;
		d["al_espacio"] = g.al_espacio;
		d["de_primera"] = g.de_primera;
		d["desde"] = Vector2(real_t(g.x), real_t(g.z));
		d["meta"] = Vector2(real_t(g.meta_x), real_t(g.meta_z));
		d["de_lado"] = g.de_lado;
		d["presion_m"] = g.presion_m;
		d["receptor_al_punto_m"] = g.receptor_al_punto_m;
		d["margen"] = g.margen;
		d["resultado"] = g.resultado;
		d["receptor_a_pelota_m"] = g.receptor_a_pelota_m;
		d["receptor_iba"] = g.receptor_iba;
		d["afuera"] = g.afuera;
		d["toque_fin"] = g.toque_fin;
		d["parte_fin"] = g.parte_fin;
		d["alto_fin"] = g.alto_fin;
		d["error_m"] = g.error_m;
		d["pasos_receptor_iba"] = g.pasos_receptor_iba;
		r.push_back(d);
	}
	return r;
}

Array CanchitaV2Nativa::registro_remates() const {
	Array r;
	for (const motor_v2::RegistroRemate &g : _c.registro) {
		Dictionary d;
		d["equipo"] = g.equipo;
		d["pateador"] = g.pateador;
		d["pateador_id"] = g.pateador_id;
		d["minuto"] = g.minuto;
		d["paso"] = g.paso_remate;
		d["golpe"] = g.golpe;
		d["de_primera"] = g.de_primera;
		d["chilena"] = g.chilena;
		d["de_lado"] = g.de_lado;
		d["desde"] = Vector2(real_t(g.desde_x), real_t(g.desde_z));
		d["alto"] = g.alto;
		d["lateral"] = g.lateral;
		d["rapidez"] = g.rapidez;
		d["presion_m"] = g.presion_m;
		d["arquero"] = Vector2(real_t(g.arquero_x), real_t(g.arquero_z));
		d["clip_arquero"] = g.clip_arquero;
		d["arquero_ocupado"] = g.arquero_ocupado;
		d["demora_plan"] = g.paso_plan >= 0 ? double(g.paso_plan - g.paso_remate) / 60.0 : -1.0;
		d["resultado"] = g.resultado;
		r.push_back(d);
	}
	return r;
}

Dictionary CanchitaV2Nativa::contadores_cerebro() const {
	const motor_v2::ContadoresCerebro &k = _c.cerebro.cuenta;
	const char *decisiones[motor_v2::DECISIONES] = { "nada", "conducir", "pase", "pase_hueco", "pase_largo", "centro",
		"pared", "despeje", "remate", "regate" };
	Dictionary d;
	for (int t = 0; t < motor_v2::DECISIONES; t++) {
		d[decisiones[t]] = k.decisiones[t];
	}
	d["corridas_preparadas"] = k.corridas_preparadas;
	d["piques"] = k.piques;
	d["pases_al_pique"] = k.pases_al_pique;
	for (int f = 0; f < 4; f++) {
		for (int t = 0; t < motor_v2::DECISIONES; t++) {
			d[String("zona") + String::num_int64(f) + "_" + decisiones[t]] = k.en_zona[f][t];
		}
		d[String("zona") + String::num_int64(f) + "_con_tiro"] = k.zona_con_tiro[f];
	}
	d["desmarque_apoyo"] = k.desmarques[motor_v2::DES_APOYO];
	d["desmarque_ruptura"] = k.desmarques[motor_v2::DES_RUPTURA];
	d["desmarque_arrastre"] = k.desmarques[motor_v2::DES_ARRASTRE];
	d["desmarque_llegada"] = k.desmarques[motor_v2::DES_LLEGADA];
	d["apoyos_de_grilla"] = k.apoyos_de_grilla;
	d["fase_circulacion"] = k.fases_ritmo[0];
	d["fase_aceleracion"] = k.fases_ritmo[1];
	d["fase_transicion"] = k.fases_ritmo[2];
	return d;
}

PackedInt32Array CanchitaV2Nativa::get_papeles() const {
	PackedInt32Array r;
	for (size_t i = 0; i < _c.cerebro.fichas.size() && i < _c.jugadores.size(); i++) {
		r.push_back(_c.cerebro.papel(int(i)));
	}
	return r;
}

PackedVector2Array CanchitaV2Nativa::get_objetivos() const {
	PackedVector2Array r;
	if (_c.modo != motor_v2::PARTIDO) {
		return r;
	}
	for (size_t i = 0; i < _c.cerebro.fichas.size() && i < _c.jugadores.size(); i++) {
		motor_v2::Objetivo o = _c.cerebro.objetivo(_c.mundo(), int(i));
		r.push_back(Vector2(real_t(o.x), real_t(o.z)));
	}
	return r;
}

PackedVector2Array CanchitaV2Nativa::get_desmarques() const {
	PackedVector2Array r;
	for (size_t i = 0; i < _c.cerebro.fichas.size() && i < _c.jugadores.size(); i++) {
		const motor_v2::PlanDesmarque &p = _c.cerebro.desmarque(int(i));
		r.push_back(p.vivo ? Vector2(real_t(p.x), real_t(p.z)) : Vector2(NAN, NAN));
	}
	return r;
}

PackedInt32Array CanchitaV2Nativa::get_roles() const {
	PackedInt32Array r;
	for (const motor_v2::FichaCerebro &f : _c.cerebro.fichas) {
		r.push_back(f.rol);
	}
	return r;
}

PackedFloat32Array CanchitaV2Nativa::get_lineas() const {
	PackedFloat32Array r;
	r.push_back(float(_c.cerebro.linea_offside(0)));
	r.push_back(float(_c.cerebro.linea_offside(1)));
	r.push_back(float(_c.cerebro.linea_defensiva(0)));
	r.push_back(float(_c.cerebro.linea_defensiva(1)));
	return r;
}

int64_t CanchitaV2Nativa::get_fase_ritmo() const {
	return _c.cerebro.fase_ritmo();
}

Dictionary CanchitaV2Nativa::ultima_decision() const {
	const char *tipos[motor_v2::DECISIONES] = { "nada", "conducir", "pase", "pase_hueco", "pase_largo", "centro", "pared",
		"despeje", "remate", "regate" };
	Dictionary d;
	d["decisor"] = _c.cerebro.ultimo_decisor;
	d["temperatura"] = _c.cerebro.ultima_temperatura;
	d["puede_pasar"] = _c.cerebro.ultimo_puede_pasar;
	d["ofrecidas"] = _c.cerebro.ultimas_ofrecidas;
	d["cortados"] = _c.cerebro.ultimos_cortados;
	Array opciones;
	for (const motor_v2::OpcionVista &o : _c.cerebro.ultimas_opciones) {
		Dictionary v;
		v["tipo"] = tipos[std::clamp(o.tipo, 0, motor_v2::DECISIONES - 1)];
		v["receptor"] = o.receptor;
		v["punto"] = Vector2(real_t(o.x), real_t(o.z));
		v["utilidad"] = o.utilidad;
		opciones.push_back(v);
	}
	d["opciones"] = opciones;
	return d;
}

int64_t CanchitaV2Nativa::huella() const {
	return int64_t(_c.huella() & 0x7fffffffffffffffULL);
}

void CanchitaV2Nativa::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurar", "pelota", "cuerpo", "clips", "toque"), &CanchitaV2Nativa::configurar);
	ClassDB::bind_method(D_METHOD("agregar", "equipo", "fisico"), &CanchitaV2Nativa::agregar);
	ClassDB::bind_method(D_METHOD("agregar_suplente", "equipo", "fisico"), &CanchitaV2Nativa::agregar_suplente);
	ClassDB::bind_method(D_METHOD("configurar_reglas", "reglas"), &CanchitaV2Nativa::configurar_reglas);
	ClassDB::bind_method(D_METHOD("configurar_reglas_equipo", "equipo", "club"), &CanchitaV2Nativa::configurar_reglas_equipo);
	ClassDB::bind_method(D_METHOD("reglas_de_fabrica"), &CanchitaV2Nativa::reglas_de_fabrica);
	ClassDB::bind_method(D_METHOD("eventos"), &CanchitaV2Nativa::eventos);
	ClassDB::bind_method(D_METHOD("get_ids"), &CanchitaV2Nativa::get_ids);
	ClassDB::bind_method(D_METHOD("get_energias"), &CanchitaV2Nativa::get_energias);
	ClassDB::bind_method(D_METHOD("energias_por_id"), &CanchitaV2Nativa::energias_por_id);
	ClassDB::bind_method(D_METHOD("get_afuera"), &CanchitaV2Nativa::get_afuera);
	ClassDB::bind_method(D_METHOD("get_estado"), &CanchitaV2Nativa::get_estado);
	ClassDB::bind_method(D_METHOD("forzar_parada", "tipo", "equipo", "pos"), &CanchitaV2Nativa::forzar_parada);
	ClassDB::bind_method(D_METHOD("forzar_falta", "tarjeta", "lesion"), &CanchitaV2Nativa::forzar_falta);
	ClassDB::bind_method(D_METHOD("forzar_fin_de_tiempo"), &CanchitaV2Nativa::forzar_fin_de_tiempo);
	ClassDB::bind_method(D_METHOD("get_lateral_en_manos"), &CanchitaV2Nativa::get_lateral_en_manos);
	ClassDB::bind_method(D_METHOD("configurar_remate", "remate", "arquero"), &CanchitaV2Nativa::configurar_remate);
	ClassDB::bind_method(D_METHOD("remate_de_fabrica"), &CanchitaV2Nativa::remate_de_fabrica);
	ClassDB::bind_method(D_METHOD("rematar", "i", "golpe", "alto", "lateral"), &CanchitaV2Nativa::rematar);
	ClassDB::bind_static_method(get_class_static(),
			D_METHOD("apuntar_prueba", "pelota", "desde", "meta", "rapidez", "elevacion_fija", "giro_lateral"),
			&CanchitaV2Nativa::apuntar_prueba);
	ClassDB::bind_method(D_METHOD("get_en_manos"), &CanchitaV2Nativa::get_en_manos);
	ClassDB::bind_method(D_METHOD("get_ultimo_resultado"), &CanchitaV2Nativa::get_ultimo_resultado);
	ClassDB::bind_method(D_METHOD("get_arqueros"), &CanchitaV2Nativa::get_arqueros);
	ClassDB::bind_method(D_METHOD("get_goles"), &CanchitaV2Nativa::get_goles);
	ClassDB::bind_method(D_METHOD("empezar", "modo", "semilla"), &CanchitaV2Nativa::empezar);
	ClassDB::bind_method(D_METHOD("configurar_cerebro", "utility", "nuevos"), &CanchitaV2Nativa::configurar_cerebro);
	ClassDB::bind_method(D_METHOD("configurar_plan", "equipo", "plan"), &CanchitaV2Nativa::configurar_plan);
	ClassDB::bind_method(D_METHOD("pesos_cerebro_de_fabrica"), &CanchitaV2Nativa::pesos_cerebro_de_fabrica);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("exponencial", "x"), &CanchitaV2Nativa::exponencial);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("logaritmo", "x"), &CanchitaV2Nativa::logaritmo);
	ClassDB::bind_method(D_METHOD("contadores_cerebro"), &CanchitaV2Nativa::contadores_cerebro);
	ClassDB::bind_method(D_METHOD("get_papeles"), &CanchitaV2Nativa::get_papeles);
	ClassDB::bind_method(D_METHOD("get_objetivos"), &CanchitaV2Nativa::get_objetivos);
	ClassDB::bind_method(D_METHOD("get_desmarques"), &CanchitaV2Nativa::get_desmarques);
	ClassDB::bind_method(D_METHOD("get_roles"), &CanchitaV2Nativa::get_roles);
	ClassDB::bind_method(D_METHOD("get_lineas"), &CanchitaV2Nativa::get_lineas);
	ClassDB::bind_method(D_METHOD("get_fase_ritmo"), &CanchitaV2Nativa::get_fase_ritmo);
	ClassDB::bind_method(D_METHOD("ultima_decision"), &CanchitaV2Nativa::ultima_decision);
	ClassDB::bind_method(D_METHOD("poner_jugador", "i", "pos", "rumbo"), &CanchitaV2Nativa::poner_jugador);
	ClassDB::bind_method(D_METHOD("lanzar", "pos", "vel", "giro", "equipo"), &CanchitaV2Nativa::lanzar);
	ClassDB::bind_method(D_METHOD("avanzar"), &CanchitaV2Nativa::avanzar);
	ClassDB::bind_method(D_METHOD("simular", "pasos"), &CanchitaV2Nativa::simular);
	ClassDB::bind_method(D_METHOD("cantidad"), &CanchitaV2Nativa::cantidad);
	ClassDB::bind_method(D_METHOD("get_pos"), &CanchitaV2Nativa::get_pos);
	ClassDB::bind_method(D_METHOD("get_pos_previa"), &CanchitaV2Nativa::get_pos_previa);
	ClassDB::bind_method(D_METHOD("get_rumbo"), &CanchitaV2Nativa::get_rumbo);
	ClassDB::bind_method(D_METHOD("get_rapidez"), &CanchitaV2Nativa::get_rapidez);
	ClassDB::bind_method(D_METHOD("get_equipos"), &CanchitaV2Nativa::get_equipos);
	ClassDB::bind_method(D_METHOD("get_accion", "i"), &CanchitaV2Nativa::get_accion);
	ClassDB::bind_method(D_METHOD("get_fase", "i"), &CanchitaV2Nativa::get_fase);
	ClassDB::bind_method(D_METHOD("get_tiempo_accion", "i"), &CanchitaV2Nativa::get_tiempo_accion);
	ClassDB::bind_method(D_METHOD("get_alcanza", "i"), &CanchitaV2Nativa::get_alcanza);
	ClassDB::bind_method(D_METHOD("get_rapidez_buscada", "i"), &CanchitaV2Nativa::get_rapidez_buscada);
	ClassDB::bind_method(D_METHOD("get_metros_para_parar", "i"), &CanchitaV2Nativa::get_metros_para_parar);
	ClassDB::bind_method(D_METHOD("get_giro_pendiente", "i"), &CanchitaV2Nativa::get_giro_pendiente);
	ClassDB::bind_method(D_METHOD("get_rumbo_buscado", "i"), &CanchitaV2Nativa::get_rumbo_buscado);
	ClassDB::bind_method(D_METHOD("get_poseedor"), &CanchitaV2Nativa::get_poseedor);
	ClassDB::bind_method(D_METHOD("get_equipo_con_pelota"), &CanchitaV2Nativa::get_equipo_con_pelota);
	ClassDB::bind_method(D_METHOD("get_ultimo_toque"), &CanchitaV2Nativa::get_ultimo_toque);
	ClassDB::bind_method(D_METHOD("get_receptor"), &CanchitaV2Nativa::get_receptor);
	ClassDB::bind_method(D_METHOD("get_pelota_pos"), &CanchitaV2Nativa::get_pelota_pos);
	ClassDB::bind_method(D_METHOD("get_pelota_previa"), &CanchitaV2Nativa::get_pelota_previa);
	ClassDB::bind_method(D_METHOD("get_pelota_vel"), &CanchitaV2Nativa::get_pelota_vel);
	ClassDB::bind_method(D_METHOD("get_pelota_giro"), &CanchitaV2Nativa::get_pelota_giro);
	ClassDB::bind_method(D_METHOD("prediccion"), &CanchitaV2Nativa::prediccion);
	ClassDB::bind_method(D_METHOD("contadores"), &CanchitaV2Nativa::contadores);
	ClassDB::bind_method(D_METHOD("registro_remates"), &CanchitaV2Nativa::registro_remates);
	ClassDB::bind_method(D_METHOD("registro_pases"), &CanchitaV2Nativa::registro_pases);
	ClassDB::bind_method(D_METHOD("huella"), &CanchitaV2Nativa::huella);
	const StringName clase = get_class_static();
	ClassDB::bind_integer_constant(clase, "", "RONDO", motor_v2::RONDO);
	ClassDB::bind_integer_constant(clase, "", "PARTIDITO", motor_v2::PARTIDITO);
	ClassDB::bind_integer_constant(clase, "", "PRUEBA", motor_v2::PRUEBA);
	ClassDB::bind_integer_constant(clase, "", "PARTIDO", motor_v2::PARTIDO);
	ClassDB::bind_integer_constant(clase, "", "ARCO", motor_v2::ARCO);
	for (int g = 0; g < motor_v2::TIPOS_REMATE; g++) {
		ClassDB::bind_integer_constant(clase, "", String("REMATE_") + String(GOLPES[g]).to_upper(), g);
	}
	const char *resultados[motor_v2::RESULTADOS_REMATE] = { "GOL", "ATAJADO", "PALO", "BLOQUEADO", "AFUERA", "OTRO" };
	for (int r = 0; r < motor_v2::RESULTADOS_REMATE; r++) {
		ClassDB::bind_integer_constant(clase, "", String("RESULTADO_") + resultados[r], r);
	}
}
