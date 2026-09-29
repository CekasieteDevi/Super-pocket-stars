#include "mundo_v2_nativo.h"
#include "matematica_fija.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>

using namespace godot;

// Los mismos números que motor_v2/mundo.gd y motor_v2/cerebro_falso.gd
// (ahí está el porqué de cada uno). Seno, coseno y arcotangente salen de
// matematica_fija.h: las del sistema daban otro partido en Android.
namespace {
constexpr double PI_ = 3.14159265358979323846;
constexpr double PASO_SEG = 1.0 / 60.0;
constexpr double GRAVEDAD = 9.81;
constexpr double MEDIO_LARGO = 52.5;
constexpr double MEDIO_ANCHO = 34.0;
constexpr double ARCO_MEDIO_ANCHO = 3.66;
constexpr double ARCO_ALTO = 2.44;
constexpr double RADIO_PALO = 0.06;
constexpr double RADIO_PELOTA = 0.11;
constexpr double MASA_PELOTA = 0.43;
constexpr double K_AIRE = 0.5 * 1.2 * PI_ * RADIO_PELOTA * RADIO_PELOTA / MASA_PELOTA;
constexpr double CD_RAPIDA = 0.25;
constexpr double CD_LENTA = 0.45;
constexpr double VELOCIDAD_CRISIS = 12.0;
constexpr double CL_TOPE = 0.35;
constexpr double GIRO_DECAE = 0.12;
constexpr double RESTITUCION_PISO = 0.62;
constexpr double ROCE_PIQUE = 0.35;
constexpr double VERTICAL_RUEDA = 0.6;
constexpr double FRENADO_RODANDO = 1.1;
constexpr double RESTITUCION_PALO = 0.7;
constexpr double RESTITUCION_CUERPO = 0.3;
constexpr double SUBPASO_MAX_M = 0.1;
constexpr double RADIO_CUERPO = 0.35;
constexpr double ALTO_CUERPO = 1.7;
constexpr double ACELERACION = 4.5;
constexpr double FRENADA = 7.0;
constexpr double GIRO_PARADO = 12.0;
constexpr double GIRO_A_TOPE = 3.0;

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
		_objetivo[i] = _pos[i];
		_puede_patear[i] = 0;
	}
	_poner_pelota({ 0.0, RADIO_PELOTA, 0.0 });
	_piques = _golpes_palo = _choques_cuerpos = _choques_pelota = 0;
	_patadas = _goles = _salidas = 0;
}

void MundoV2Nativo::avanzar() {
	_pensar();
	std::copy(std::begin(_pos), std::end(_pos), std::begin(_pos_previa));
	_pelota_previa = _pelota;
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
	V2 pelota = { _pelota.x, _pelota.z };
	if (turno == 0) {
		_elegir_perseguidores(pelota);
	}
	V2 adelante = { pelota.x + _pelota_vel.x * 0.3, pelota.y + _pelota_vel.z * 0.3 };
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
	if (_paso < _puede_patear[i] || _pelota.y > PATEA_ALTURA_M) {
		return;
	}
	double dx = _pelota.x - _pos[i].x, dy = _pelota.z - _pos[i].y;
	if (std::sqrt(dx * dx + dy * dy) > PATEA_DISTANCIA_M) {
		return;
	}
	double hacia = i < 11 ? 1.0 : -1.0;
	double angulo = _al_azar(-1.2, 1.2);
	double rapidez = _al_azar(6.0, 27.0);
	double alto = _al_azar(0.0, 1.0) < 0.5 ? 0.0 : _al_azar(0.1, 0.45) * rapidez;
	double giro = _al_azar(-12.0, 12.0);
	_pelota_vel = { mate::coseno(angulo) * hacia * rapidez, alto, mate::seno(angulo) * rapidez };
	_pelota_giro = { 0.0, giro, 0.0 };
	_puede_patear[i] = _paso + ESPERA_ENTRE_PATADAS;
	_patadas++;
}

void MundoV2Nativo::_reglas() {
	V3 p = _pelota;
	if (std::abs(p.x) > MEDIO_LARGO + RADIO_PELOTA) {
		if (std::abs(p.z) < ARCO_MEDIO_ANCHO && p.y < ARCO_ALTO) {
			_goles++;
			_poner_pelota({ 0.0, RADIO_PELOTA, 0.0 });
		} else {
			_salidas++;
			_poner_pelota({ signo(p.x) * (MEDIO_LARGO - 5.5), RADIO_PELOTA, signo(p.z) * 9.0 });
		}
	} else if (std::abs(p.z) > MEDIO_ANCHO + RADIO_PELOTA) {
		_salidas++;
		_poner_pelota({ p.x, RADIO_PELOTA, signo(p.z) * (MEDIO_ANCHO - 0.5) });
	}
}

void MundoV2Nativo::_poner_pelota(V3 p) {
	_pelota = p;
	_pelota_previa = p;
	_pelota_vel = {};
	_pelota_giro = {};
}

// --- Mundo ---

void MundoV2Nativo::_mover_cuerpos() {
	const double dt = PASO_SEG;
	for (int i = 0; i < JUGADORES; i++) {
		double fx = _objetivo[i].x - _pos[i].x, fy = _objetivo[i].y - _pos[i].y;
		double d = std::sqrt(fx * fx + fy * fy);
		double vi = _rapidez[i];
		double ri = _rumbo[i];
		double deseada = 0.0;
		if (d > 0.05) {
			deseada = std::min(_velocidad_max[i], std::sqrt(2.0 * FRENADA * d));
			double angulo = mate::arcotangente2(fx, fy);
			double giro_max = (GIRO_PARADO + (GIRO_A_TOPE - GIRO_PARADO) * (vi / 9.0)) * dt;
			double dif = mate::envolver(angulo - ri);
			ri += std::clamp(dif, -giro_max, giro_max);
			deseada *= std::max(0.0, mate::coseno(dif));
		}
		if (deseada > vi) {
			vi = std::min(deseada, vi + ACELERACION * dt);
		} else {
			vi = std::max(deseada, vi - FRENADA * dt);
		}
		_rapidez[i] = vi;
		_rumbo[i] = ri;
		_pos[i].x += mate::seno(ri) * vi * dt;
		_pos[i].y += mate::coseno(ri) * vi * dt;
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
}

void MundoV2Nativo::_mover_pelota() {
	double rapida = std::sqrt(_pelota_vel.x * _pelota_vel.x + _pelota_vel.y * _pelota_vel.y + _pelota_vel.z * _pelota_vel.z);
	int subpasos = std::max(1, int(std::ceil(rapida * PASO_SEG / SUBPASO_MAX_M)));
	double dt = PASO_SEG / double(subpasos);
	for (int s = 0; s < subpasos; s++) {
		_subpaso_pelota(dt);
	}
	double decae = 1.0 - GIRO_DECAE * PASO_SEG;
	_pelota_giro = { _pelota_giro.x * decae, _pelota_giro.y * decae, _pelota_giro.z * decae };
	_chocar_cuerpos();
}

void MundoV2Nativo::_subpaso_pelota(double dt) {
	V3 v = _pelota_vel;
	V3 p = _pelota;
	bool en_piso = p.y <= RADIO_PELOTA + 0.001 && std::abs(v.y) < 0.001;
	double rapida = std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
	if (en_piso) {
		double h = std::sqrt(v.x * v.x + v.z * v.z);
		double frena = (FRENADO_RODANDO + K_AIRE * CD_LENTA * h * h) * dt;
		if (h <= frena) {
			v = {};
		} else {
			double f = (h - frena) / h;
			v = { v.x * f, 0.0, v.z * f };
		}
		p = { p.x + v.x * dt, p.y + v.y * dt, p.z + v.z * dt };
	} else {
		V3 a = { 0.0, -GRAVEDAD, 0.0 };
		if (rapida > 0.01) {
			double cd = rapida > VELOCIDAD_CRISIS ? CD_RAPIDA : CD_LENTA;
			double k = K_AIRE * cd * rapida;
			a.x -= v.x * k;
			a.y -= v.y * k;
			a.z -= v.z * k;
			const V3 &g = _pelota_giro;
			double w = std::sqrt(g.x * g.x + g.y * g.y + g.z * g.z);
			if (w > 0.1) {
				double cl = std::min(RADIO_PELOTA * w / rapida, CL_TOPE);
				double m = K_AIRE * cl * rapida / w;
				a.x += (g.y * v.z - g.z * v.y) * m;
				a.y += (g.z * v.x - g.x * v.z) * m;
				a.z += (g.x * v.y - g.y * v.x) * m;
			}
		}
		v = { v.x + a.x * dt, v.y + a.y * dt, v.z + a.z * dt };
		p = { p.x + v.x * dt, p.y + v.y * dt, p.z + v.z * dt };
		if (p.y < RADIO_PELOTA) {
			p.y = RADIO_PELOTA;
			if (-v.y < VERTICAL_RUEDA) {
				v.y = 0.0;
			} else {
				v.y = -v.y * RESTITUCION_PISO;
				v.x *= 1.0 - ROCE_PIQUE * 0.3;
				v.z *= 1.0 - ROCE_PIQUE * 0.3;
				_pelota_giro = { _pelota_giro.x * (1.0 - ROCE_PIQUE), _pelota_giro.y * (1.0 - ROCE_PIQUE),
					_pelota_giro.z * (1.0 - ROCE_PIQUE) };
				_piques++;
			}
		}
	}
	if (std::abs(p.x) > MEDIO_LARGO - 0.5 && std::abs(p.x) < MEDIO_LARGO + 0.5) {
		double linea = signo(p.x) * MEDIO_LARGO;
		if (p.y < ARCO_ALTO + RADIO_PALO) {
			for (double lado : { -1.0, 1.0 }) {
				_rebote_en_eje(p.x, p.z, v.x, v.z, linea, lado * ARCO_MEDIO_ANCHO);
			}
		}
		if (std::abs(p.z) < ARCO_MEDIO_ANCHO) {
			_rebote_en_eje(p.x, p.y, v.x, v.y, linea, ARCO_ALTO);
		}
	}
	_pelota_vel = v;
	_pelota = p;
}

bool MundoV2Nativo::_rebote_en_eje(double &px, double &py, double &vx, double &vy, double ex, double ey) {
	double dx = px - ex, dy = py - ey;
	double d = std::sqrt(dx * dx + dy * dy);
	double minimo = RADIO_PELOTA + RADIO_PALO;
	if (d >= minimo || d < 0.0001) {
		return false;
	}
	double nx = dx / d, ny = dy / d;
	double vn = vx * nx + vy * ny;
	if (vn < 0.0) {
		vx -= nx * (1.0 + RESTITUCION_PALO) * vn;
		vy -= ny * (1.0 + RESTITUCION_PALO) * vn;
		_golpes_palo++;
	}
	px = ex + nx * minimo;
	py = ey + ny * minimo;
	return true;
}

void MundoV2Nativo::_chocar_cuerpos() {
	if (_pelota.y > ALTO_CUERPO + RADIO_PELOTA) {
		return;
	}
	double px = _pelota.x, py = _pelota.z;
	const double minimo = RADIO_CUERPO + RADIO_PELOTA;
	for (int j = 0; j < JUGADORES; j++) {
		double ex = px - _pos[j].x, ey = py - _pos[j].y;
		if (std::abs(ex) >= minimo || std::abs(ey) >= minimo) {
			continue;
		}
		double d = std::sqrt(ex * ex + ey * ey);
		if (d < minimo && d > 0.0001) {
			double nx = ex / d, ny = ey / d;
			double cx = mate::seno(_rumbo[j]) * _rapidez[j], cy = mate::coseno(_rumbo[j]) * _rapidez[j];
			double rx = _pelota_vel.x - cx, ry = _pelota_vel.z - cy;
			double vn = rx * nx + ry * ny;
			px = _pos[j].x + nx * minimo;
			py = _pos[j].y + ny * minimo;
			if (vn < 0.0) {
				rx -= nx * (1.0 + RESTITUCION_CUERPO) * vn;
				ry -= ny * (1.0 + RESTITUCION_CUERPO) * vn;
				_pelota_vel.x = rx + cx;
				_pelota_vel.z = ry + cy;
				_choques_pelota++;
			}
		}
	}
	_pelota.x = px;
	_pelota.z = py;
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
	return Vector3(real_t(_pelota.x), real_t(_pelota.y), real_t(_pelota.z));
}

Vector3 MundoV2Nativo::get_pelota_previa() const {
	return Vector3(real_t(_pelota_previa.x), real_t(_pelota_previa.y), real_t(_pelota_previa.z));
}

Dictionary MundoV2Nativo::contadores() const {
	Dictionary d;
	d["goles"] = _goles;
	d["patadas"] = _patadas;
	d["salidas"] = _salidas;
	d["piques"] = _piques;
	d["palos"] = _golpes_palo;
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
	mezclar(&_pelota, sizeof(_pelota));
	mezclar(&_pelota_vel, sizeof(_pelota_vel));
	mezclar(&_pelota_giro, sizeof(_pelota_giro));
	return int64_t(h & 0x7fffffffffffffffULL);
}

void MundoV2Nativo::_bind_methods() {
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
