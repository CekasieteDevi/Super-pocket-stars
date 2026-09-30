#include "cuerpos_v2_nativos.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

namespace {
void leer(const Dictionary &d, const char *clave, double &destino) {
	if (d.has(clave)) {
		destino = double(d[clave]);
	}
}

constexpr double PASO_SEG = 1.0 / 60.0;
} // namespace

void godot::leer_parametros_cuerpo(const Dictionary &d, motor_v2::ParametrosCuerpo &p) {
	leer(d, "frenada", p.frenada);
	leer(d, "giro_acel", p.giro_acel);
	leer(d, "arranque_extra", p.arranque_extra);
	leer(d, "rapidez_para_girar", p.rapidez_para_girar);
	leer(d, "peso_aceleracion", p.peso_aceleracion);
	leer(d, "umbral_sprint", p.umbral_sprint);
	leer(d, "consumo_sprint", p.consumo_sprint);
	leer(d, "recuperacion_reserva", p.recuperacion_reserva);
	leer(d, "reserva_para_frenar", p.reserva_para_frenar);
	leer(d, "piso_sprint", p.piso_sprint);
	leer(d, "ventana_contacto_seg", p.ventana_contacto_seg);
}

// Las claves de un Dictionary de Godot salen en el orden en que se cargaron;
// el JSON viene ordenado por nombre, así el índice de cada clip es el mismo en
// la PC y en Android.
void godot::leer_clips(const Dictionary &d, std::vector<motor_v2::Clip> &clips, std::vector<String> &nombres) {
	clips.clear();
	nombres.clear();
	Array claves = d.keys();
	for (int64_t k = 0; k < claves.size(); k++) {
		String nombre = claves[k];
		Dictionary c = d[nombre];
		motor_v2::Clip clip;
		clip.duracion = double(c.get("duracion", 0.0));
		Variant contacto = c.get("contacto", Variant());
		if (contacto.get_type() == Variant::FLOAT || contacto.get_type() == Variant::INT) {
			clip.contacto_seg = double(contacto) * clip.duracion;
		}
		clip.mueve = bool(c.get("mueve", false));
		Array punto = c.get("punto_contacto", Array());
		if (punto.size() == 3) {
			clip.punto_x = double(punto[0]);
			clip.punto_y = double(punto[1]);
			clip.punto_z = double(punto[2]);
		}
		clips.push_back(clip);
		nombres.push_back(nombre);
	}
}

void CuerposV2Nativos::configurar(const Dictionary &parametros, const Dictionary &clips) {
	_param = motor_v2::ParametrosCuerpo();
	leer_parametros_cuerpo(parametros, _param);
	leer_clips(clips, _clips, _nombres);
	_cuerpos.clear();
}

int64_t CuerposV2Nativos::agregar(const Vector2 &pos, double rumbo, const Dictionary &fisico) {
	motor_v2::Cuerpo c;
	c.x = c.previa_x = pos.x;
	c.z = c.previa_z = pos.y;
	c.rumbo = rumbo;
	leer(fisico, "vel_max", c.vel_max);
	leer(fisico, "aceleracion", c.aceleracion);
	leer(fisico, "giro", c.giro);
	leer(fisico, "cansancio", c.cansancio);
	_cuerpos.push_back(c);
	return int64_t(_cuerpos.size()) - 1;
}

bool CuerposV2Nativos::_valido(int64_t i) const {
	return i >= 0 && i < int64_t(_cuerpos.size());
}

int CuerposV2Nativos::_indice(const String &nombre) const {
	for (size_t k = 0; k < _nombres.size(); k++) {
		if (_nombres[k] == nombre) {
			return int(k);
		}
	}
	return -1;
}

void CuerposV2Nativos::ir_a(int64_t i, const Vector2 &punto, double factor, bool frenar) {
	if (_valido(i)) {
		_cuerpos[size_t(i)].ir_a(punto.x, punto.y, factor, frenar);
	}
}

void CuerposV2Nativos::parar(int64_t i) {
	if (_valido(i)) {
		_cuerpos[size_t(i)].tiene_objetivo = false;
	}
}

void CuerposV2Nativos::mirar_a(int64_t i, const Vector2 &punto) {
	if (_valido(i)) {
		motor_v2::Cuerpo &c = _cuerpos[size_t(i)];
		c.mira = true;
		c.mira_x = punto.x;
		c.mira_z = punto.y;
	}
}

void CuerposV2Nativos::poner_reserva(int64_t i, double reserva) {
	if (_valido(i)) {
		_cuerpos[size_t(i)].reserva = reserva;
	}
}

void CuerposV2Nativos::poner_cansancio(int64_t i, double cansancio) {
	if (_valido(i)) {
		_cuerpos[size_t(i)].cansancio = cansancio;
	}
}

bool CuerposV2Nativos::empezar_accion(int64_t i, const String &nombre) {
	return _valido(i) && _cuerpos[size_t(i)].empezar(_indice(nombre));
}

void CuerposV2Nativos::avanzar() {
	for (motor_v2::Cuerpo &c : _cuerpos) {
		c.paso(_param, _clips, PASO_SEG);
	}
}

int64_t CuerposV2Nativos::cantidad() const {
	return int64_t(_cuerpos.size());
}

PackedVector2Array CuerposV2Nativos::get_pos() const {
	PackedVector2Array r;
	for (const motor_v2::Cuerpo &c : _cuerpos) {
		r.push_back(Vector2(real_t(c.x), real_t(c.z)));
	}
	return r;
}

PackedVector2Array CuerposV2Nativos::get_pos_previa() const {
	PackedVector2Array r;
	for (const motor_v2::Cuerpo &c : _cuerpos) {
		r.push_back(Vector2(real_t(c.previa_x), real_t(c.previa_z)));
	}
	return r;
}

PackedFloat32Array CuerposV2Nativos::get_rumbo() const {
	PackedFloat32Array r;
	for (const motor_v2::Cuerpo &c : _cuerpos) {
		r.push_back(float(c.rumbo));
	}
	return r;
}

PackedFloat32Array CuerposV2Nativos::get_rapidez() const {
	PackedFloat32Array r;
	for (const motor_v2::Cuerpo &c : _cuerpos) {
		r.push_back(float(c.rapidez()));
	}
	return r;
}

Vector2 CuerposV2Nativos::get_vel(int64_t i) const {
	return _valido(i) ? Vector2(real_t(_cuerpos[size_t(i)].vx), real_t(_cuerpos[size_t(i)].vz)) : Vector2();
}

double CuerposV2Nativos::get_reserva(int64_t i) const {
	return _valido(i) ? _cuerpos[size_t(i)].reserva : 0.0;
}

double CuerposV2Nativos::get_rapidez_buscada(int64_t i) const {
	return _valido(i) ? _cuerpos[size_t(i)].rapidez_buscada(_param) : 0.0;
}

double CuerposV2Nativos::get_metros_para_parar(int64_t i) const {
	return _valido(i) ? _cuerpos[size_t(i)].metros_para_parar(_param) : -1.0;
}

double CuerposV2Nativos::get_giro_pendiente(int64_t i) const {
	return _valido(i) ? _cuerpos[size_t(i)].giro_pendiente(_param) : 0.0;
}

double CuerposV2Nativos::get_rumbo_buscado(int64_t i) const {
	return _valido(i) ? _cuerpos[size_t(i)].rumbo_buscado() : 0.0;
}

String CuerposV2Nativos::get_accion(int64_t i) const {
	if (!_valido(i) || _cuerpos[size_t(i)].clip < 0) {
		return String();
	}
	return _nombres[size_t(_cuerpos[size_t(i)].clip)];
}

int64_t CuerposV2Nativos::get_fase(int64_t i) const {
	return _valido(i) ? int64_t(_cuerpos[size_t(i)].fase) : 0;
}

double CuerposV2Nativos::get_tiempo_accion(int64_t i) const {
	return _valido(i) ? _cuerpos[size_t(i)].tiempo_accion : 0.0;
}

int64_t CuerposV2Nativos::get_eventos(int64_t i) const {
	return _valido(i) ? int64_t(_cuerpos[size_t(i)].eventos) : 0;
}

double CuerposV2Nativos::duracion(const String &nombre) const {
	int k = _indice(nombre);
	return k < 0 ? 0.0 : _clips[size_t(k)].duracion;
}

// FNV-1a sobre posición, velocidad, rumbo y reserva de todos.
int64_t CuerposV2Nativos::huella() const {
	uint64_t h = 1469598103934665603ULL;
	auto mezclar = [&h](const double &v) {
		const unsigned char *b = reinterpret_cast<const unsigned char *>(&v);
		for (size_t i = 0; i < sizeof(double); i++) {
			h = (h ^ b[i]) * 1099511628211ULL;
		}
	};
	for (const motor_v2::Cuerpo &c : _cuerpos) {
		mezclar(c.x);
		mezclar(c.z);
		mezclar(c.vx);
		mezclar(c.vz);
		mezclar(c.rumbo);
		mezclar(c.reserva);
	}
	return int64_t(h & 0x7fffffffffffffffULL);
}

void CuerposV2Nativos::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurar", "parametros", "clips"), &CuerposV2Nativos::configurar);
	ClassDB::bind_method(D_METHOD("agregar", "pos", "rumbo", "fisico"), &CuerposV2Nativos::agregar);
	ClassDB::bind_method(D_METHOD("ir_a", "i", "punto", "factor", "frenar"), &CuerposV2Nativos::ir_a);
	ClassDB::bind_method(D_METHOD("parar", "i"), &CuerposV2Nativos::parar);
	ClassDB::bind_method(D_METHOD("mirar_a", "i", "punto"), &CuerposV2Nativos::mirar_a);
	ClassDB::bind_method(D_METHOD("poner_reserva", "i", "reserva"), &CuerposV2Nativos::poner_reserva);
	ClassDB::bind_method(D_METHOD("poner_cansancio", "i", "cansancio"), &CuerposV2Nativos::poner_cansancio);
	ClassDB::bind_method(D_METHOD("empezar_accion", "i", "nombre"), &CuerposV2Nativos::empezar_accion);
	ClassDB::bind_method(D_METHOD("avanzar"), &CuerposV2Nativos::avanzar);
	ClassDB::bind_method(D_METHOD("cantidad"), &CuerposV2Nativos::cantidad);
	ClassDB::bind_method(D_METHOD("get_pos"), &CuerposV2Nativos::get_pos);
	ClassDB::bind_method(D_METHOD("get_pos_previa"), &CuerposV2Nativos::get_pos_previa);
	ClassDB::bind_method(D_METHOD("get_rumbo"), &CuerposV2Nativos::get_rumbo);
	ClassDB::bind_method(D_METHOD("get_rapidez"), &CuerposV2Nativos::get_rapidez);
	ClassDB::bind_method(D_METHOD("get_vel", "i"), &CuerposV2Nativos::get_vel);
	ClassDB::bind_method(D_METHOD("get_reserva", "i"), &CuerposV2Nativos::get_reserva);
	ClassDB::bind_method(D_METHOD("get_rapidez_buscada", "i"), &CuerposV2Nativos::get_rapidez_buscada);
	ClassDB::bind_method(D_METHOD("get_metros_para_parar", "i"), &CuerposV2Nativos::get_metros_para_parar);
	ClassDB::bind_method(D_METHOD("get_giro_pendiente", "i"), &CuerposV2Nativos::get_giro_pendiente);
	ClassDB::bind_method(D_METHOD("get_rumbo_buscado", "i"), &CuerposV2Nativos::get_rumbo_buscado);
	ClassDB::bind_method(D_METHOD("get_accion", "i"), &CuerposV2Nativos::get_accion);
	ClassDB::bind_method(D_METHOD("get_fase", "i"), &CuerposV2Nativos::get_fase);
	ClassDB::bind_method(D_METHOD("get_tiempo_accion", "i"), &CuerposV2Nativos::get_tiempo_accion);
	ClassDB::bind_method(D_METHOD("get_eventos", "i"), &CuerposV2Nativos::get_eventos);
	ClassDB::bind_method(D_METHOD("duracion", "nombre"), &CuerposV2Nativos::duracion);
	ClassDB::bind_method(D_METHOD("huella"), &CuerposV2Nativos::huella);
	const StringName clase = get_class_static();
	ClassDB::bind_integer_constant(clase, "", "SIN_ACCION", motor_v2::SIN_ACCION);
	ClassDB::bind_integer_constant(clase, "", "PREPARACION", motor_v2::PREPARACION);
	ClassDB::bind_integer_constant(clase, "", "CONTACTO", motor_v2::CONTACTO);
	ClassDB::bind_integer_constant(clase, "", "RECUPERACION", motor_v2::RECUPERACION);
	ClassDB::bind_integer_constant(clase, "", "ABRE_CONTACTO", motor_v2::ABRE_CONTACTO);
	ClassDB::bind_integer_constant(clase, "", "CIERRA_CONTACTO", motor_v2::CIERRA_CONTACTO);
	ClassDB::bind_integer_constant(clase, "", "TERMINA_ACCION", motor_v2::TERMINA_ACCION);
	ClassDB::bind_integer_constant(clase, "", "LLEGO", motor_v2::LLEGO);
}
