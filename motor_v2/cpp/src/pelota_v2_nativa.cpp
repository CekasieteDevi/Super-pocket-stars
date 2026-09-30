#include "pelota_v2_nativa.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

namespace {
void leer(const Dictionary &d, const char *clave, double &destino) {
	if (d.has(clave)) {
		destino = double(d[clave]);
	}
}

Vector3 a_godot(motor_v2::V3 v) {
	return Vector3(real_t(v.x), real_t(v.y), real_t(v.z));
}

motor_v2::V3 a_motor(const Vector3 &v) {
	return { double(v.x), double(v.y), double(v.z) };
}
} // namespace

void godot::leer_parametros_pelota(const Dictionary &d, motor_v2::ParametrosPelota &p) {
	leer(d, "gravedad", p.gravedad);
	leer(d, "radio", p.radio);
	leer(d, "masa", p.masa);
	leer(d, "densidad_aire", p.densidad_aire);
	leer(d, "cd_lenta", p.cd_lenta);
	leer(d, "cd_rapida", p.cd_rapida);
	leer(d, "crisis_desde", p.crisis_desde);
	leer(d, "crisis_hasta", p.crisis_hasta);
	leer(d, "cl_por_giro", p.cl_por_giro);
	leer(d, "cl_tope", p.cl_tope);
	leer(d, "giro_decae_aire", p.giro_decae_aire);
	leer(d, "restitucion_piso", p.restitucion_piso);
	leer(d, "rozamiento_pique", p.rozamiento_pique);
	leer(d, "vertical_rueda", p.vertical_rueda);
	leer(d, "rozamiento_deslizar", p.rozamiento_deslizar);
	leer(d, "frenado_rodando", p.frenado_rodando);
	leer(d, "giro_vertical_decae_piso", p.giro_vertical_decae_piso);
	leer(d, "quieta", p.quieta);
	leer(d, "medio_largo", p.medio_largo);
	leer(d, "arco_medio_ancho", p.arco_medio_ancho);
	leer(d, "arco_alto", p.arco_alto);
	leer(d, "radio_palo", p.radio_palo);
	leer(d, "restitucion_palo", p.restitucion_palo);
	leer(d, "rozamiento_palo", p.rozamiento_palo);
	leer(d, "profundidad_red", p.profundidad_red);
	leer(d, "restitucion_red", p.restitucion_red);
	leer(d, "rozamiento_red", p.rozamiento_red);
	leer(d, "subpaso_max_m", p.subpaso_max_m);
	leer(d, "viento_x", p.viento.x);
	leer(d, "viento_z", p.viento.z);
}

void PelotaV2Nativa::configurar(const Dictionary &parametros) {
	motor_v2::ParametrosPelota p;
	leer_parametros_pelota(parametros, p);
	// Pelota nueva: los contadores arrancan de cero en cada disparo.
	_pelota = motor_v2::Pelota();
	_pelota.configurar(p);
}

void PelotaV2Nativa::poner(const Vector3 &pos, const Vector3 &vel, const Vector3 &giro) {
	_pelota.poner(a_motor(pos), a_motor(vel), a_motor(giro));
}

int64_t PelotaV2Nativa::avanzar() {
	return int64_t(_pelota.avanzar());
}

void PelotaV2Nativa::simular(int64_t pasos) {
	for (int64_t k = 0; k < pasos; k++) {
		_pelota.avanzar();
	}
}

Vector3 PelotaV2Nativa::get_pos() const {
	return a_godot(_pelota.pos);
}

Vector3 PelotaV2Nativa::get_previa() const {
	return a_godot(_pelota.previa);
}

Vector3 PelotaV2Nativa::get_vel() const {
	return a_godot(_pelota.vel);
}

Vector3 PelotaV2Nativa::get_giro() const {
	return a_godot(_pelota.giro);
}

bool PelotaV2Nativa::get_en_piso() const {
	return _pelota.en_piso;
}

Dictionary PelotaV2Nativa::contadores() const {
	Dictionary d;
	d["piques"] = _pelota.piques;
	d["palos"] = _pelota.palos;
	d["travesanos"] = _pelota.travesanos;
	d["redes"] = _pelota.redes;
	d["saltos"] = _pelota.saltos;
	d["peor_exceso_m"] = _pelota.peor_exceso_m;
	return d;
}

// FNV-1a sobre los bytes del estado, como MundoV2Nativo::huella.
int64_t PelotaV2Nativa::huella() const {
	uint64_t h = 1469598103934665603ULL;
	auto mezclar = [&h](const void *datos, size_t n) {
		const unsigned char *b = static_cast<const unsigned char *>(datos);
		for (size_t i = 0; i < n; i++) {
			h = (h ^ b[i]) * 1099511628211ULL;
		}
	};
	mezclar(&_pelota.pos, sizeof(_pelota.pos));
	mezclar(&_pelota.vel, sizeof(_pelota.vel));
	mezclar(&_pelota.giro, sizeof(_pelota.giro));
	return int64_t(h & 0x7fffffffffffffffULL);
}

void PelotaV2Nativa::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurar", "parametros"), &PelotaV2Nativa::configurar);
	ClassDB::bind_method(D_METHOD("poner", "pos", "vel", "giro"), &PelotaV2Nativa::poner);
	ClassDB::bind_method(D_METHOD("avanzar"), &PelotaV2Nativa::avanzar);
	ClassDB::bind_method(D_METHOD("simular", "pasos"), &PelotaV2Nativa::simular);
	ClassDB::bind_method(D_METHOD("get_pos"), &PelotaV2Nativa::get_pos);
	ClassDB::bind_method(D_METHOD("get_previa"), &PelotaV2Nativa::get_previa);
	ClassDB::bind_method(D_METHOD("get_vel"), &PelotaV2Nativa::get_vel);
	ClassDB::bind_method(D_METHOD("get_giro"), &PelotaV2Nativa::get_giro);
	ClassDB::bind_method(D_METHOD("get_en_piso"), &PelotaV2Nativa::get_en_piso);
	ClassDB::bind_method(D_METHOD("contadores"), &PelotaV2Nativa::contadores);
	ClassDB::bind_method(D_METHOD("huella"), &PelotaV2Nativa::huella);
	const StringName clase = get_class_static();
	ClassDB::bind_integer_constant(clase, "", "PIQUE", motor_v2::PIQUE);
	ClassDB::bind_integer_constant(clase, "", "PALO", motor_v2::PALO);
	ClassDB::bind_integer_constant(clase, "", "TRAVESANO", motor_v2::TRAVESANO);
	ClassDB::bind_integer_constant(clase, "", "RED", motor_v2::RED);
	ClassDB::bind_integer_constant(clase, "", "EMPIEZA_A_RODAR", motor_v2::EMPIEZA_A_RODAR);
	ClassDB::bind_integer_constant(clase, "", "SE_DETIENE", motor_v2::SE_DETIENE);
}
