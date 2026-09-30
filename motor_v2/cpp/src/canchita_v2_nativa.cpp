#include "canchita_v2_nativa.h"
#include "cuerpos_v2_nativos.h"
#include "pelota_v2_nativa.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <chrono>

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
	leer(d, "sin_rebote_seg", p.sin_rebote_seg);
	leer(d, "margen_seguro_seg", p.margen_seguro_seg);
	leer(d, "giro_alcance_rad", p.giro_alcance_rad);
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
	motor_v2::Cuerpo c;
	leer(fisico, "vel_max", c.vel_max);
	leer(fisico, "aceleracion", c.aceleracion);
	leer(fisico, "giro", c.giro);
	leer(fisico, "cansancio", c.cansancio);
	double pases = 50.0, control = 50.0;
	leer(fisico, "pases", pases);
	leer(fisico, "control", control);
	_c.agregar(int(equipo), c, pases, control);
	return int64_t(_c.jugadores.size()) - 1;
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
	return d;
}

int64_t CanchitaV2Nativa::huella() const {
	return int64_t(_c.huella() & 0x7fffffffffffffffULL);
}

void CanchitaV2Nativa::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurar", "pelota", "cuerpo", "clips", "toque"), &CanchitaV2Nativa::configurar);
	ClassDB::bind_method(D_METHOD("agregar", "equipo", "fisico"), &CanchitaV2Nativa::agregar);
	ClassDB::bind_method(D_METHOD("empezar", "modo", "semilla"), &CanchitaV2Nativa::empezar);
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
	ClassDB::bind_method(D_METHOD("huella"), &CanchitaV2Nativa::huella);
	const StringName clase = get_class_static();
	ClassDB::bind_integer_constant(clase, "", "RONDO", motor_v2::RONDO);
	ClassDB::bind_integer_constant(clase, "", "PARTIDITO", motor_v2::PARTIDITO);
	ClassDB::bind_integer_constant(clase, "", "PRUEBA", motor_v2::PRUEBA);
}
