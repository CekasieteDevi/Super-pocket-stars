#include "cerebro_v2_nativo.h"

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;
using motor_v2::PesosCerebro;

namespace {
// Cada peso: su sección y su clave en el JSON, y dónde va en PesosCerebro.
struct Entrada {
	const char *seccion;
	const char *clave;
	double PesosCerebro::*campo;
};

const Entrada ENTRADAS[] = {
	{ "conducir", "base", &PesosCerebro::conducir_base },
	{ "conducir", "espacio", &PesosCerebro::conducir_espacio },
	{ "conducir", "progreso", &PesosCerebro::conducir_progreso },
	{ "conducir", "camino", &PesosCerebro::conducir_camino },
	{ "pase", "base", &PesosCerebro::pase_base },
	{ "pase", "progreso", &PesosCerebro::pase_progreso },
	{ "pase", "seguridad", &PesosCerebro::pase_seguridad },
	{ "pase", "distancia", &PesosCerebro::pase_distancia },
	{ "pase", "retroceso_libre", &PesosCerebro::pase_retroceso_libre },
	{ "despeje", "base", &PesosCerebro::despeje_base },
	{ "despeje", "presion", &PesosCerebro::despeje_presion },
	{ "despeje", "zona", &PesosCerebro::despeje_zona },
	{ "centro", "base", &PesosCerebro::centro_base },
	{ "centro", "punteria", &PesosCerebro::centro_punteria },
	{ "centro", "progreso", &PesosCerebro::centro_progreso },
	{ "pared", "base", &PesosCerebro::pared_base },
	{ "pared", "progreso", &PesosCerebro::pared_progreso },
	{ "pared", "seguridad", &PesosCerebro::pared_seguridad },
	{ "pase_largo", "base", &PesosCerebro::largo_base },
	{ "pase_largo", "progreso", &PesosCerebro::largo_progreso },
	{ "pase_largo", "presion", &PesosCerebro::largo_presion },
	{ "pase_largo", "salida", &PesosCerebro::largo_salida },
	{ "tiro", "base", &PesosCerebro::tiro_base },
	{ "tiro", "geometria", &PesosCerebro::tiro_geometria },
	{ "pase_hueco", "base", &PesosCerebro::hueco_base },
	{ "pase_hueco", "progreso", &PesosCerebro::hueco_progreso },
	{ "pase_hueco", "seguridad", &PesosCerebro::hueco_seguridad },
	{ "pase_hueco", "distancia", &PesosCerebro::hueco_distancia },
	{ "temperatura", "base", &PesosCerebro::temp_base },
	{ "temperatura", "k_vision", &PesosCerebro::temp_k_vision },
	{ "temperatura", "k_inteligencia", &PesosCerebro::temp_k_inteligencia },
	{ "temperatura", "k_presion", &PesosCerebro::temp_k_presion },
	{ "temperatura", "min", &PesosCerebro::temp_min },
	{ "temperatura", "max", &PesosCerebro::temp_max },
	{ "temperatura", "factor_metodico", &PesosCerebro::temp_factor_metodico },
	{ "presion", "radio", &PesosCerebro::presion_radio },
	{ "presion", "factor_frente", &PesosCerebro::presion_factor_frente },
	{ "presion", "normalizador", &PesosCerebro::presion_normalizador },
	{ "sesgos_personalidad", "creador_pase", &PesosCerebro::creador_pase },
	{ "sesgos_personalidad", "pie_preferido_penalizacion", &PesosCerebro::pie_preferido_penalizacion },
	{ "sesgos_personalidad", "egoista_tiro", &PesosCerebro::egoista_tiro },
	{ "asociacion_colectiva", "descarga_util", &PesosCerebro::descarga_util },
	{ "fisica", "vel_min", &PesosCerebro::vel_min },
	{ "fisica", "vel_max", &PesosCerebro::vel_max },
	{ "fisica", "vel_pase_min", &PesosCerebro::vel_pase_min },
	{ "fisica", "vel_pase_max", &PesosCerebro::vel_pase_max },
	{ "fisica", "hueco_min", &PesosCerebro::hueco_min },
	{ "fisica", "hueco_max", &PesosCerebro::hueco_max },
	{ "fisica", "vision_minima_hueco", &PesosCerebro::vision_minima_hueco },
	{ "fisica", "hueco_por_vision", &PesosCerebro::hueco_por_vision },
	{ "fisica", "pases_minimo_pared", &PesosCerebro::pases_minimo_pared },
	{ "fisica", "centros_minimo", &PesosCerebro::centros_minimo },
	{ "fisica", "banda_para_centrar", &PesosCerebro::banda_para_centrar },
	{ "fisica", "apego_a_la_banda", &PesosCerebro::apego_a_la_banda },
	{ "fisica", "avance_para_centrar", &PesosCerebro::avance_para_centrar },
	{ "fisica", "offside_margen_torpe", &PesosCerebro::offside_margen_torpe },
	{ "fisica", "avance_para_jugar_en_el_hombro", &PesosCerebro::avance_para_jugar_en_el_hombro },
	{ "fisica", "apoyo_del_delantero", &PesosCerebro::apoyo_del_delantero },
	{ "fisica", "apoyo_del_nueve", &PesosCerebro::apoyo_del_nueve },
	{ "fisica", "avance_para_acompanar", &PesosCerebro::avance_para_acompanar },
	{ "fisica", "avance_acompanamiento_pleno", &PesosCerebro::avance_acompanamiento_pleno },
	{ "fisica", "desplazamiento_por_estilo", &PesosCerebro::desplazamiento_por_estilo },
	{ "fisica", "angulo_minimo_tiro_libre", &PesosCerebro::angulo_minimo_tiro_libre },
	{ "fisica", "zona_despeje", &PesosCerebro::zona_despeje },
	{ "fisica", "presion_despeje", &PesosCerebro::presion_despeje },
	{ "fisica", "despeje_corto", &PesosCerebro::despeje_corto },
	{ "fisica", "despeje_largo", &PesosCerebro::despeje_largo },
	{ "fisica", "pared_muro_cerca", &PesosCerebro::pared_muro_cerca },
	{ "fisica", "pared_muro_lejos", &PesosCerebro::pared_muro_lejos },
	{ "fisica", "pared_avance_min", &PesosCerebro::pared_avance_min },
	{ "fisica", "pared_avance_max", &PesosCerebro::pared_avance_max },
	{ "fisica", "max_dist_pase_malo", &PesosCerebro::max_dist_pase_malo },
	{ "fisica", "max_dist_pase_bueno", &PesosCerebro::max_dist_pase_bueno },
	{ "fisica", "max_pelotazo_debil", &PesosCerebro::max_pelotazo_debil },
	{ "fisica", "max_pelotazo_fuerte", &PesosCerebro::max_pelotazo_fuerte },
	{ "fisica", "corredor_conduccion", &PesosCerebro::corredor_conduccion },
	{ "fisica", "ticks_control_malo", &PesosCerebro::ticks_control_malo },
	{ "fisica", "ticks_control_bueno", &PesosCerebro::ticks_control_bueno },
	{ "fisica", "rango_tiro_medio", &PesosCerebro::rango_tiro_medio },
	{ "fisica", "tercio_propio_arquero", &PesosCerebro::tercio_propio_arquero },
	{ "fisica", "dist_saque_largo", &PesosCerebro::dist_saque_largo },
	{ "fisica", "radio_tackle", &PesosCerebro::radio_tackle },
	{ "fisica", "gambeta_cono_frontal", &PesosCerebro::gambeta_cono_frontal },
	{ "fisica", "rango_tiro_malo", &PesosCerebro::rango_tiro_malo },
	{ "fisica", "rango_tiro_bueno", &PesosCerebro::rango_tiro_bueno },
	{ "fisica", "mezcla_fisica_rango_tiro", &PesosCerebro::mezcla_fisica_rango_tiro },
	{ "fisica", "geometria_minima_tiro", &PesosCerebro::geometria_minima_tiro },
	{ "ritmo", "umbral_transicion", &PesosCerebro::ritmo_umbral_transicion },
	{ "ritmo", "frente", &PesosCerebro::ritmo_frente },
	{ "ritmo", "espacio_para_acelerar", &PesosCerebro::ritmo_espacio_para_acelerar },
	{ "ritmo", "apoyo_libre", &PesosCerebro::ritmo_apoyo_libre },
	{ "ritmo", "apoyo_adelante", &PesosCerebro::ritmo_apoyo_adelante },
	{ "ritmo", "apoyo_alcance", &PesosCerebro::ritmo_apoyo_alcance },
	{ "ritmo", "carril_libre", &PesosCerebro::ritmo_carril_libre },
	{ "ritmo", "circulacion_apoyo", &PesosCerebro::ritmo_circulacion_apoyo },
	{ "ritmo", "circulacion_cambio", &PesosCerebro::ritmo_circulacion_cambio },
	{ "ritmo", "circulacion_dist", &PesosCerebro::ritmo_circulacion_dist },
	{ "ritmo", "aceleracion_progreso", &PesosCerebro::ritmo_aceleracion_progreso },
	{ "ritmo", "aceleracion_conducir", &PesosCerebro::ritmo_aceleracion_conducir },
	{ "ritmo", "tope", &PesosCerebro::ritmo_tope },
	{ "ritmo", "estancada_ticks", &PesosCerebro::ritmo_estancada_ticks },
	{ "ritmo", "estancada_avance", &PesosCerebro::ritmo_estancada_avance },
	{ "ritmo", "estancada_presion", &PesosCerebro::ritmo_estancada_presion },
	{ "ritmo", "devolucion_castigo", &PesosCerebro::ritmo_devolucion_castigo },
	{ "ritmo", "devolucion_max", &PesosCerebro::ritmo_devolucion_max },
	{ "marcador", "exponente", &PesosCerebro::marc_exponente },
	{ "marcador", "empate", &PesosCerebro::marc_empate },
	{ "marcador", "dif_extra", &PesosCerebro::marc_dif_extra },
	{ "marcador", "dif_tope", &PesosCerebro::marc_dif_tope },
	{ "marcador", "dt_loco", &PesosCerebro::marc_dt_loco },
	{ "marcador", "dt_conservador", &PesosCerebro::marc_dt_conservador },
	{ "marcador", "altura_bloque", &PesosCerebro::marc_altura_bloque },
	{ "marcador", "tope", &PesosCerebro::marc_tope },
	{ "marcador", "riesgo", &PesosCerebro::marc_riesgo },
	{ "marcador", "seguridad", &PesosCerebro::marc_seguridad },
	{ "marcador", "seguridad_dist", &PesosCerebro::marc_seguridad_dist },
	{ "marcador", "urgencia_para_romper", &PesosCerebro::marc_urgencia_para_romper },
	{ "marcador", "urgencia_para_guardar", &PesosCerebro::marc_urgencia_para_guardar },
	{ "marcador", "cierre", &PesosCerebro::marc_cierre },
	{ "marcador", "cobertura_extra", &PesosCerebro::marc_cobertura_extra },
	{ "perfil", "reparto", &PesosCerebro::perfil_reparto },
	{ "perfil", "tope", &PesosCerebro::perfil_tope },
	{ "perfil", "asociacion", &PesosCerebro::perfil_asociacion },
	{ "perfil", "regate", &PesosCerebro::perfil_regate },
	{ "perfil", "descarga", &PesosCerebro::perfil_descarga },
	{ "perfil", "corto_dist", &PesosCerebro::perfil_corto_dist },
	{ "perfil", "desmarque", &PesosCerebro::perfil_desmarque },
	{ "sin_pelota", "linea", &PesosCerebro::sp_linea },
	{ "sin_pelota", "espacio", &PesosCerebro::sp_espacio },
	{ "sin_pelota", "progreso", &PesosCerebro::sp_progreso },
	{ "sin_pelota", "distancia_util", &PesosCerebro::sp_distancia_util },
	{ "sin_pelota", "viaje", &PesosCerebro::sp_viaje },
	{ "sin_pelota", "dist_ideal", &PesosCerebro::sp_dist_ideal },
	{ "sin_pelota", "dist_tolerancia", &PesosCerebro::sp_dist_tolerancia },
	{ "sin_pelota", "conflicto", &PesosCerebro::sp_conflicto },
	{ "sin_pelota", "minimo", &PesosCerebro::sp_minimo },
	{ "sin_pelota", "sesgo_apoyo", &PesosCerebro::sp_sesgo_apoyo },
	{ "sin_pelota", "sesgo_ruptura", &PesosCerebro::sp_sesgo_ruptura },
	{ "sin_pelota", "sesgo_arrastre", &PesosCerebro::sp_sesgo_arrastre },
	{ "sin_pelota", "sesgo_llegada", &PesosCerebro::sp_sesgo_llegada },
	{ "sin_pelota", "pared_riesgo_max", &PesosCerebro::sp_pared_riesgo_max },
	{ "defensa", "zona", &PesosCerebro::def_zona },
	{ "defensa", "cansancio", &PesosCerebro::def_cansancio },
	{ "defensa", "mejora_presionante", &PesosCerebro::def_mejora_presionante },
	{ "defensa", "cobertura_atras", &PesosCerebro::def_cobertura_atras },
	{ "defensa", "cobertura_cerca", &PesosCerebro::def_cobertura_cerca },
	{ "defensa", "cobertura_bloque", &PesosCerebro::def_cobertura_bloque },
	{ "defensa", "enganche", &PesosCerebro::def_enganche },
	{ "defensa", "cierre_cerca", &PesosCerebro::def_cierre_cerca },
	{ "defensa", "cierre_lejos", &PesosCerebro::def_cierre_lejos },
	{ "defensa", "cierre_carril", &PesosCerebro::def_cierre_carril },
	{ "defensa", "banda_disparador", &PesosCerebro::def_banda_disparador },
	{ "defensa", "intensidad_para_cierre", &PesosCerebro::def_intensidad_para_cierre },
	{ "defensa", "radio_defensa", &PesosCerebro::def_radio_defensa },
	{ "defensa", "radio_medio", &PesosCerebro::def_radio_medio },
	{ "defensa", "radio_ataque", &PesosCerebro::def_radio_ataque },
};

// Los nuevos de data/fisica_v2.json, "cerebro".
const Entrada NUEVOS[] = {
	{ "cerebro", "grilla_rapidez_pase", &PesosCerebro::grilla_rapidez_pase },
	{ "cerebro", "grilla_peso_pase", &PesosCerebro::grilla_peso_pase },
	{ "cerebro", "grilla_peso_tiro", &PesosCerebro::grilla_peso_tiro },
	{ "cerebro", "grilla_peso_distancia", &PesosCerebro::grilla_peso_distancia },
	{ "cerebro", "grilla_candidatos", &PesosCerebro::grilla_candidatos },
	{ "cerebro", "grilla_bono", &PesosCerebro::grilla_bono },
	{ "cerebro", "linea_mezcla", &PesosCerebro::linea_mezcla },
	{ "cerebro", "decision_vigencia_seg", &PesosCerebro::decision_vigencia_seg },
	{ "cerebro", "riesgo_por_tiempos", &PesosCerebro::riesgo_por_tiempos },
	{ "cerebro", "riesgo_rapidez_pase", &PesosCerebro::riesgo_rapidez_pase },
	{ "cerebro", "riesgo_margen_seguro", &PesosCerebro::riesgo_margen_seguro },
	{ "cerebro", "entrada_ventaja_seg", &PesosCerebro::entrada_ventaja_seg },
	{ "cerebro", "castigo_corte", &PesosCerebro::castigo_corte },
	{ "cerebro", "castigo_centro", &PesosCerebro::castigo_centro },
	{ "cerebro", "remate_temperatura", &PesosCerebro::remate_temperatura },
	{ "cerebro", "tiro_factor", &PesosCerebro::tiro_factor },
	{ "cerebro", "riesgo_maximo", &PesosCerebro::riesgo_maximo },
	{ "cerebro", "pase_seguro_extra", &PesosCerebro::pase_seguro_extra },
	{ "cerebro", "conducir_libre_extra", &PesosCerebro::conducir_libre_extra },
	{ "cerebro", "conduce_espera", &PesosCerebro::conduce_espera },
	{ "cerebro", "estilo_fuerza", &PesosCerebro::estilo_fuerza },
	{ "cerebro", "estilo_pase_seguro", &PesosCerebro::estilo_pase_seguro },
	{ "cerebro", "estilo_riesgo", &PesosCerebro::estilo_riesgo },
	{ "cerebro", "estilo_hueco", &PesosCerebro::estilo_hueco },
	{ "cerebro", "estilo_atras", &PesosCerebro::estilo_atras },
	{ "cerebro", "estilo_precision", &PesosCerebro::estilo_precision },
	{ "cerebro", "tiro_de_cerca", &PesosCerebro::tiro_de_cerca },
	{ "cerebro", "tiro_desde", &PesosCerebro::tiro_desde },
	{ "cerebro", "conduce_decide_seg", &PesosCerebro::conduce_decide_seg },
	{ "cerebro", "via_libre_m", &PesosCerebro::via_libre_m },
	{ "cerebro", "castigo_espaldas", &PesosCerebro::castigo_espaldas },
	{ "cerebro", "contrapresion_seg", &PesosCerebro::contrapresion_seg },
	{ "cerebro", "presion_alta_segundo", &PesosCerebro::presion_alta_segundo },
	{ "cerebro", "trampa_m", &PesosCerebro::trampa_m },
	{ "cerebro", "presion_alta_cierres", &PesosCerebro::presion_alta_cierres },
	{ "cerebro", "pique_m", &PesosCerebro::pique_m },
	{ "cerebro", "pique_bono", &PesosCerebro::pique_bono },
	{ "cerebro", "pique_espera_seg", &PesosCerebro::pique_espera_seg },
	{ "cerebro", "pique_riesgo", &PesosCerebro::pique_riesgo },
	{ "cerebro", "llegada_area_extra", &PesosCerebro::llegada_area_extra },
	{ "cerebro", "centro_alto_m", &PesosCerebro::centro_alto_m },
	{ "cerebro", "centro_elevacion_rad", &PesosCerebro::centro_elevacion_rad },
	{ "cerebro", "centro_al_que_llega", &PesosCerebro::centro_al_que_llega },
};

// Los atributos de Player, en el orden de motor_v2::Atributo.
const char *ATRIBUTOS[motor_v2::ATRIBUTOS] = { "pases", "vision", "inteligencia", "control", "centros", "fuerza",
	"golpe", "velocidad", "aceleracion", "energia", "agilidad", "cabezazo", "tiro", "pies", "reflejos", "estirada",
	"agarre", "achique" };

const char *ROLES[motor_v2::ROLES] = { "ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC" };

void leer(const Dictionary &d, const char *clave, double &destino) {
	if (d.has(clave)) {
		destino = double(d[clave]);
	}
}

void leer(const Dictionary &d, const char *clave, bool &destino) {
	if (d.has(clave)) {
		destino = bool(d[clave]);
	}
}
} // namespace

void godot::leer_pesos_cerebro(const Dictionary &utility, const Dictionary &nuevos, PesosCerebro &p) {
	for (const Entrada &e : ENTRADAS) {
		if (utility.has(e.seccion)) {
			Dictionary s = utility[e.seccion];
			leer(s, e.clave, p.*(e.campo));
		}
	}
	for (const Entrada &e : NUEVOS) {
		leer(nuevos, e.clave, p.*(e.campo));
	}
	if (nuevos.has("grilla_columnas")) {
		p.grilla_columnas = int(nuevos["grilla_columnas"]);
	}
	if (nuevos.has("grilla_filas")) {
		p.grilla_filas = int(nuevos["grilla_filas"]);
	}
}

Dictionary godot::pesos_cerebro_a_diccionario(const PesosCerebro &p) {
	Dictionary r;
	for (const Entrada &e : ENTRADAS) {
		if (!r.has(e.seccion)) {
			r[e.seccion] = Dictionary();
		}
		Dictionary s = r[e.seccion];
		s[e.clave] = p.*(e.campo);
	}
	Dictionary c;
	for (const Entrada &e : NUEVOS) {
		c[e.clave] = p.*(e.campo);
	}
	c["grilla_columnas"] = p.grilla_columnas;
	c["grilla_filas"] = p.grilla_filas;
	r["cerebro"] = c;
	return r;
}

void godot::leer_plan_equipo(const Dictionary &d, motor_v2::PlanEquipo &p) {
	leer(d, "asociacion", p.asociacion);
	leer(d, "verticalidad", p.verticalidad);
	leer(d, "amplitud", p.amplitud);
	leer(d, "transicion", p.transicion);
	leer(d, "retroceso", p.retroceso);
	leer(d, "acompanamiento", p.acompanamiento);
	leer(d, "intencion_centro", p.intencion_centro);
	leer(d, "contragolpe", p.contragolpe);
	leer(d, "presion_alta", p.presion_alta);
	leer(d, "pique", p.pique);
	leer(d, "defensivo", p.defensivo);
	leer(d, "extra_pared", p.extra_pared);
	leer(d, "extra_contragolpe", p.extra_contragolpe);
	leer(d, "paso_defensa", p.paso_defensa);
	leer(d, "contrapresion", p.contrapresion);
	leer(d, "corner_corto", p.corner_corto);
	leer(d, "corner_bloque", p.corner_bloque);
	leer(d, "amague", p.amague);
	if (d.has("rasgo_dt")) {
		String r = d["rasgo_dt"];
		p.rasgo_dt = r == "Loco" ? 1 : (r == "Conservador" ? 2 : 0);
	}
}

void godot::leer_ficha_cerebro(int equipo, const Dictionary &d, motor_v2::FichaCerebro &f) {
	f.equipo = equipo;
	String rol = d.get("rol", "MC");
	f.rol = motor_v2::MC;
	for (int k = 0; k < motor_v2::ROLES; k++) {
		if (rol == ROLES[k]) {
			f.rol = k;
		}
	}
	Vector2 base = d.get("base", Vector2());
	f.base_x = base.x;
	f.base_z = base.y;
	Dictionary brutos = d.get("atributos", Dictionary());
	Dictionary relativos = d.get("relativos", Dictionary());
	for (int k = 0; k < motor_v2::ATRIBUTOS; k++) {
		f.bruto[k] = 50.0;
		leer(brutos, ATRIBUTOS[k], f.bruto[k]);
		f.relativo[k] = f.bruto[k];
		leer(relativos, ATRIBUTOS[k], f.relativo[k]);
	}
	leer(d, "creador", f.creador);
	leer(d, "metodico", f.metodico);
	leer(d, "egoista", f.egoista);
	f.pie_malo_lado = int(d.get("pie_malo_lado", 0));
	leer(d, "margen_offside", f.margen_offside);
}
