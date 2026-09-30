#include "mundo_v2_nativo.h"
#include "cuerpos_v2_nativos.h"
#include "matematica_fija.h"
#include "pelota_v2_nativa.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>

using namespace godot;

// Los mismos números que motor_v2/mundo.gd y motor_v2/cerebro_falso.gd
// (ahí está el porqué de cada uno); los de la pelota, desde la etapa 1, en
// data/fisica_v2.json. Seno, coseno y arcotangente salen de
// matematica_fija.h: las del sistema daban otro partido en Android.
namespace {
constexpr double PI_ = 3.14159265358979323846;
constexpr double PASO_SEG = 1.0 / 60.0;
constexpr double MEDIO_LARGO = 52.5;
constexpr double MEDIO_ANCHO = 34.0;
constexpr double RESTITUCION_CUERPO = 0.3;
constexpr double RADIO_CUERPO = 0.35;
constexpr double ALTO_CUERPO = 1.7;
// Físico de los jugadores de prueba de la etapa 0 (el de verdad lo pasa
// GDScript desde los atributos cuando haya partido).
constexpr double ACELERACION = 4.5;
constexpr double GIRO = 9.0;

constexpr int PASOS_POR_TURNO = 6;
constexpr double DISPERSION_M = 7.0;
constexpr double PATEA_DISTANCIA_M = 0.75;
constexpr double PATEA_ALTURA_M = 0.6;
constexpr int ESPERA_ENTRE_PATADAS = 36;
constexpr double PUESTOS[11][2] = {
	{ -50.0, 0.0 },
	{ -35.0, -24.0 }, { -38.0, -8.0 }, { -38.0, 8.0 }, { -35.0, 24.0 },
	{ -18.0, -22.0 }, { -20.0, -7.0 }, { -20.0, 7.0 }, { -18.0, 22.0 },
	{ -5.0, -8.0 }, { -5.0, 8.0 },
};

double signo(double x) {
	return x > 0.0 ? 1.0 : (x < 0.0 ? -1.0 : 0.0);
}
} // namespace

uint32_t MundoV2Nativo::_rng() {
	uint64_t viejo = _estado_rng;
	_estado_rng = viejo * 6364136223846793005ULL + 1442695040888963407ULL;
	uint32_t mezcla = uint32_t(((viejo >> 18u) ^ viejo) >> 27u);
	uint32_t giro = uint32_t(viejo >> 59u);
	return (mezcla >> giro) | (mezcla << ((-int32_t(giro)) & 31));
}

double MundoV2Nativo::_al_azar(double desde, double hasta) {
	return desde + (hasta - desde) * (double(_rng()) / 4294967296.0);
}

void MundoV2Nativo::configurar_pelota(const Dictionary &parametros) {
	_param_pelota = motor_v2::ParametrosPelota();
	leer_parametros_pelota(parametros, _param_pelota);
}

void MundoV2Nativo::configurar_cuerpos(const Dictionary &parametros) {
	_param_cuerpo = motor_v2::ParametrosCuerpo();
	leer_parametros_cuerpo(parametros, _param_cuerpo);
}

void MundoV2Nativo::iniciar(int64_t semilla) {
	_estado_rng = uint64_t(semilla) * 2u + 1u;
	_rng();
	_paso = 0;
	for (int i = 0; i < JUGADORES; i++) {
		_velocidad_max[i] = _al_azar(6.8, 8.6);
		_masa[i] = _al_azar(65.0, 85.0);
		_rumbo[i] = i < 11 ? 0.0 : PI_;
		_rapidez[i] = 0.0;
		V2 p = _puesto(i);
		_pos[i] = { p.x * 0.9, p.y };
		_pos_previa[i] = _pos[i];
		motor_v2::Cuerpo c;
		c.vel_max = _velocidad_max[i];
		c.aceleracion = ACELERACION;
		c.giro = GIRO;
		c.x = c.previa_x = _pos[i].x;
		c.z = c.previa_z = _pos[i].y;
		c.rumbo = _rumbo[i];
		_cuerpos[i] = c;
		_objetivo[i] = _pos[i];
		_puede_patear[i] = 0;
	}
	_pelota = motor_v2::Pelota();
	_pelota.configurar(_param_pelota);
	_poner_pelota(0.0, 0.0);
	_choques_cuerpos = _choques_pelota = 0;
	_patadas = _goles = _salidas = 0;
}

void MundoV2Nativo::avanzar() {
	_pensar();
	std::copy(std::begin(_pos), std::end(_pos), std::begin(_pos_previa));
	_mover_cuerpos();
	_separar_cuerpos();
	_mover_pelota();
	_paso++;
}

double MundoV2Nativo::simular(int64_t pasos) {
	auto inicio = std::chrono::steady_clock::now();
	for (int64_t k = 0; k < pasos; k++) {
		avanzar();
	}
	std::chrono::duration<double> dura = std::chrono::steady_clock::now() - inicio;
	return dura.count();
}

// --- Cerebro falso ---

MundoV2Nativo::V2 MundoV2Nativo::_puesto(int i) const {
	V2 base = { PUESTOS[i % 11][0], PUESTOS[i % 11][1] };
	return i < 11 ? base : V2{ -base.x, -base.y };
}

void MundoV2Nativo::_pensar() {
	int turno = int(_paso % PASOS_POR_TURNO);
	V2 pelota = { _pelota.pos.x, _pelota.pos.z };
	if (turno == 0) {
		_elegir_perseguidores(pelota);
	}
	V2 adelante = { pelota.x + _pelota.vel.x * 0.3, pelota.y + _pelota.vel.z * 0.3 };
	for (int i = turno; i < JUGADORES; i += PASOS_POR_TURNO) {
		if (i == _perseguidor[0] || i == _perseguidor[1]) {
			_objetivo[i] = adelante;
		} else if (i % 11 == 0) {
			double linea = i < 11 ? -MEDIO_LARGO + 1.0 : MEDIO_LARGO - 1.0;
			_objetivo[i] = { linea, std::clamp(pelota.y * 0.3, -2.5, 2.5) };
		} else {
			V2 p = _puesto(i);
			p.x += pelota.x * 0.5;
			p.y += pelota.y * 0.25;
			p.x += _al_azar(-DISPERSION_M, DISPERSION_M);
			p.y += _al_azar(-DISPERSION_M, DISPERSION_M);
			_objetivo[i] = { std::clamp(p.x, -MEDIO_LARGO, MEDIO_LARGO), std::clamp(p.y, -MEDIO_ANCHO, MEDIO_ANCHO) };
		}
	}
	_intentar_patear(_perseguidor[0]);
	_intentar_patear(_perseguidor[1]);
	_reglas();
}

void MundoV2Nativo::_elegir_perseguidores(V2 pelota) {
	for (int equipo = 0; equipo < 2; equipo++) {
		int mejor = -1;
		double mejor_d = 1e300;
		for (int i = equipo * 11; i < equipo * 11 + 11; i++) {
			double dx = pelota.x - _pos[i].x, dy = pelota.y - _pos[i].y;
			double d = dx * dx + dy * dy;
			if (d < mejor_d) {
				mejor_d = d;
				mejor = i;
			}
		}
		_perseguidor[equipo] = mejor;
	}
}

void MundoV2Nativo::_intentar_patear(int i) {
	if (_paso < _puede_patear[i] || _pelota.pos.y > PATEA_ALTURA_M) {
		return;
	}
	double dx = _pelota.pos.x - _pos[i].x, dy = _pelota.pos.z - _pos[i].y;
	if (std::sqrt(dx * dx + dy * dy) > PATEA_DISTANCIA_M) {
		return;
	}
	double hacia = i < 11 ? 1.0 : -1.0;
	double angulo = _al_azar(-1.2, 1.2);
	double rapidez = _al_azar(6.0, 27.0);
	double alto = _al_azar(0.0, 1.0) < 0.5 ? 0.0 : _al_azar(0.1, 0.45) * rapidez;
	double giro = _al_azar(-12.0, 12.0);
	_pelota.poner(_pelota.pos, { mate::coseno(angulo) * hacia * rapidez, alto, mate::seno(angulo) * rapidez },
			{ 0.0, giro, 0.0 });
	_puede_patear[i] = _paso + ESPERA_ENTRE_PATADAS;
	_patadas++;
}

void MundoV2Nativo::_reglas() {
	const motor_v2::V3 &p = _pelota.pos;
	const double r = _param_pelota.radio;
	if (std::abs(p.x) > MEDIO_LARGO + r) {
		// Adentro del arco la pelota puede quedar en la red; gol cuando cruzó
		// entera la línea entre los palos y bajo el travesaño.
		if (std::abs(p.z) < _param_pelota.arco_medio_ancho && p.y < _param_pelota.arco_alto) {
			_goles++;
			_poner_pelota(0.0, 0.0);
		} else {
			_salidas++;
			_poner_pelota(signo(p.x) * (MEDIO_LARGO - 5.5), signo(p.z) * 9.0);
		}
	} else if (std::abs(p.z) > MEDIO_ANCHO + r) {
		_salidas++;
		_poner_pelota(p.x, signo(p.z) * (MEDIO_ANCHO - 0.5));
	}
}

void MundoV2Nativo::_poner_pelota(double x, double z) {
	_pelota.poner({ x, _param_pelota.radio, z }, {}, {});
}

// --- Mundo ---

// Desde la etapa 2 cada jugador es un motor_v2::Cuerpo (cuerpo.h): la misma
// locomoción del banco del cuerpo. El cerebro falso llega siempre frenando.
void MundoV2Nativo::_mover_cuerpos() {
	static const std::vector<motor_v2::Clip> sin_clips;
	for (int i = 0; i < JUGADORES; i++) {
		motor_v2::Cuerpo &c = _cuerpos[i];
		c.ir_a(_objetivo[i].x, _objetivo[i].y, 1.0, true);
		c.paso(_param_cuerpo, sin_clips, PASO_SEG);
		_pos[i] = { c.x, c.z };
		_rumbo[i] = c.rumbo;
		_rapidez[i] = c.rapidez();
	}
}

void MundoV2Nativo::_separar_cuerpos() {
	const double minimo = RADIO_CUERPO * 2.0;
	const double minimo2 = minimo * minimo;
	for (int i = 0; i < JUGADORES - 1; i++) {
		for (int j = i + 1; j < JUGADORES; j++) {
			double ex = _pos[j].x - _pos[i].x, ey = _pos[j].y - _pos[i].y;
			if (std::abs(ex) >= minimo || std::abs(ey) >= minimo) {
				continue;
			}
			double d2 = ex * ex + ey * ey;
			if (d2 < minimo2 && d2 > 0.000001) {
				double d = std::sqrt(d2);
				double nx = ex / d, ny = ey / d;
				double suma = _masa[i] + _masa[j];
				double hunde = minimo - d;
				_pos[i].x -= nx * hunde * _masa[j] / suma;
				_pos[i].y -= ny * hunde * _masa[j] / suma;
				_pos[j].x += nx * hunde * _masa[i] / suma;
				_pos[j].y += ny * hunde * _masa[i] / suma;
				_choques_cuerpos++;
			}
		}
	}
	for (int i = 0; i < JUGADORES; i++) {
		_cuerpos[i].x = _pos[i].x;
		_cuerpos[i].z = _pos[i].y;
	}
}

void MundoV2Nativo::_mover_pelota() {
	_pelota.avanzar();
	_chocar_cuerpos();
}

// Choque de la pelota con los cuerpos, todavía el de la etapa 0: empuja la
// pelota afuera de la cápsula. Tocar la pelota de verdad llega en la etapa 3.
void MundoV2Nativo::_chocar_cuerpos() {
	if (_pelota.pos.y > ALTO_CUERPO + _param_pelota.radio) {
		return;
	}
	double px = _pelota.pos.x, py = _pelota.pos.z;
	const double minimo = RADIO_CUERPO + _param_pelota.radio;
	for (int j = 0; j < JUGADORES; j++) {
		double ex = px - _pos[j].x, ey = py - _pos[j].y;
		if (std::abs(ex) >= minimo || std::abs(ey) >= minimo) {
			continue;
		}
		double d = std::sqrt(ex * ex + ey * ey);
		if (d < minimo && d > 0.0001) {
			double nx = ex / d, ny = ey / d;
			double cx = _cuerpos[j].vx, cy = _cuerpos[j].vz;
			double rx = _pelota.vel.x - cx, ry = _pelota.vel.z - cy;
			double vn = rx * nx + ry * ny;
			px = _pos[j].x + nx * minimo;
			py = _pos[j].y + ny * minimo;
			if (vn < 0.0) {
				rx -= nx * (1.0 + RESTITUCION_CUERPO) * vn;
				ry -= ny * (1.0 + RESTITUCION_CUERPO) * vn;
				_pelota.vel.x = rx + cx;
				_pelota.vel.z = ry + cy;
				_choques_pelota++;
			}
		}
	}
	_pelota.pos.x = px;
	_pelota.pos.z = py;
}

// --- Lectura desde GDScript ---

PackedVector2Array MundoV2Nativo::get_pos() const {
	PackedVector2Array r;
	r.resize(JUGADORES);
	for (int i = 0; i < JUGADORES; i++) {
		r.set(i, Vector2(real_t(_pos[i].x), real_t(_pos[i].y)));
	}
	return r;
}

PackedVector2Array MundoV2Nativo::get_pos_previa() const {
	PackedVector2Array r;
	r.resize(JUGADORES);
	for (int i = 0; i < JUGADORES; i++) {
		r.set(i, Vector2(real_t(_pos_previa[i].x), real_t(_pos_previa[i].y)));
	}
	return r;
}

PackedFloat32Array MundoV2Nativo::get_rumbo() const {
	PackedFloat32Array r;
	r.resize(JUGADORES);
	for (int i = 0; i < JUGADORES; i++) {
		r.set(i, float(_rumbo[i]));
	}
	return r;
}

PackedFloat32Array MundoV2Nativo::get_rapidez() const {
	PackedFloat32Array r;
	r.resize(JUGADORES);
	for (int i = 0; i < JUGADORES; i++) {
		r.set(i, float(_rapidez[i]));
	}
	return r;
}

Vector3 MundoV2Nativo::get_pelota_pos() const {
	return Vector3(real_t(_pelota.pos.x), real_t(_pelota.pos.y), real_t(_pelota.pos.z));
}

Vector3 MundoV2Nativo::get_pelota_previa() const {
	return Vector3(real_t(_pelota.previa.x), real_t(_pelota.previa.y), real_t(_pelota.previa.z));
}

Dictionary MundoV2Nativo::contadores() const {
	Dictionary d;
	d["goles"] = _goles;
	d["patadas"] = _patadas;
	d["salidas"] = _salidas;
	d["piques"] = _pelota.piques;
	d["palos"] = _pelota.palos + _pelota.travesanos;
	d["choques"] = _choques_cuerpos;
	d["choques_pelota"] = _choques_pelota;
	return d;
}

// FNV-1a sobre los bytes del estado: igual en PC y Android si cada cuenta dio
// el mismo double.
int64_t MundoV2Nativo::huella() const {
	uint64_t h = 1469598103934665603ULL;
	auto mezclar = [&h](const void *datos, size_t n) {
		const unsigned char *b = static_cast<const unsigned char *>(datos);
		for (size_t i = 0; i < n; i++) {
			h = (h ^ b[i]) * 1099511628211ULL;
		}
	};
	mezclar(_pos, sizeof(_pos));
	mezclar(_rumbo, sizeof(_rumbo));
	mezclar(_rapidez, sizeof(_rapidez));
	mezclar(&_pelota.pos, sizeof(_pelota.pos));
	mezclar(&_pelota.vel, sizeof(_pelota.vel));
	mezclar(&_pelota.giro, sizeof(_pelota.giro));
	return int64_t(h & 0x7fffffffffffffffULL);
}

void MundoV2Nativo::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurar_pelota", "parametros"), &MundoV2Nativo::configurar_pelota);
	ClassDB::bind_method(D_METHOD("configurar_cuerpos", "parametros"), &MundoV2Nativo::configurar_cuerpos);
	ClassDB::bind_method(D_METHOD("iniciar", "semilla"), &MundoV2Nativo::iniciar);
	ClassDB::bind_method(D_METHOD("avanzar"), &MundoV2Nativo::avanzar);
	ClassDB::bind_method(D_METHOD("simular", "pasos"), &MundoV2Nativo::simular);
	ClassDB::bind_method(D_METHOD("get_pos"), &MundoV2Nativo::get_pos);
	ClassDB::bind_method(D_METHOD("get_pos_previa"), &MundoV2Nativo::get_pos_previa);
	ClassDB::bind_method(D_METHOD("get_rumbo"), &MundoV2Nativo::get_rumbo);
	ClassDB::bind_method(D_METHOD("get_rapidez"), &MundoV2Nativo::get_rapidez);
	ClassDB::bind_method(D_METHOD("get_pelota_pos"), &MundoV2Nativo::get_pelota_pos);
	ClassDB::bind_method(D_METHOD("get_pelota_previa"), &MundoV2Nativo::get_pelota_previa);
	ClassDB::bind_method(D_METHOD("contadores"), &MundoV2Nativo::contadores);
	ClassDB::bind_method(D_METHOD("huella"), &MundoV2Nativo::huella);
}
