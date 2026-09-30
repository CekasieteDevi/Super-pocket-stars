#include "toque.h"
#include "matematica_fija.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

Parte motor_v2::parte_para(const ParametrosToque &p, double alto) {
	if (alto <= p.pie_hasta) {
		return PIE;
	}
	if (alto <= p.muslo_hasta) {
		return MUSLO;
	}
	if (alto <= p.pecho_hasta) {
		return PECHO;
	}
	if (alto <= p.cabeza_hasta) {
		return CABEZA;
	}
	return NINGUNA;
}

// Como Node3D.rotation.y = rumbo: el +z del modelo va a (sen, cos) y su +x
// (su izquierda) a (cos, -sen).
V3 motor_v2::punto_de_contacto(const Cuerpo &c, const Clip &k, double rumbo) {
	double s, co;
	mate::seno_coseno(rumbo, s, co);
	return { c.x + k.punto_x * co + k.punto_z * s, k.punto_y, c.z - k.punto_x * s + k.punto_z * co };
}

double motor_v2::distancia_al_tramo(double qx, double qz, V3 a, V3 b) {
	double ex = b.x - a.x, ez = b.z - a.z;
	double largo2 = ex * ex + ez * ez;
	double t = largo2 > 1e-12 ? std::clamp(((qx - a.x) * ex + (qz - a.z) * ez) / largo2, 0.0, 1.0) : 0.0;
	double dx = qx - (a.x + ex * t), dz = qz - (a.z + ez * t);
	return std::sqrt(dx * dx + dz * dz);
}

double motor_v2::tiempo_de_llegada(const Cuerpo &c, double x, double z, double alcance, double factor) {
	double dx = x - c.x, dz = z - c.z;
	double total = std::sqrt(dx * dx + dz * dz);
	double d = total - alcance;
	if (d <= 0.0) {
		return 0.0;
	}
	double punta = std::max(0.1, c.vel_max * c.cansancio * factor);
	double a = std::max(0.1, c.aceleracion * c.cansancio);
	// Lo que ya corre hacia allá cuenta; si se aleja, primero frena.
	double hacia = std::clamp((c.vx * dx + c.vz * dz) / total, -punta, punta);
	double t1 = (punta - hacia) / a;
	double d1 = hacia * t1 + 0.5 * a * t1 * t1;
	if (d1 >= d) {
		return (-hacia + std::sqrt(hacia * hacia + 2.0 * a * d)) / a;
	}
	return t1 + (d - d1) / punta;
}

void Trayectoria::predecir(const Pelota &p, int pasos) {
	Pelota copia = p;
	pos.resize(size_t(pasos));
	vel.resize(size_t(pasos));
	for (int k = 0; k < pasos; k++) {
		copia.avanzar();
		pos[size_t(k)] = copia.pos;
		vel[size_t(k)] = copia.vel;
	}
}

int Perfil::paso_a(double d) const {
	// dist no baja: búsqueda binaria.
	if (dist.empty() || dist.back() < d) {
		return -1;
	}
	int a = 0, b = int(dist.size()) - 1;
	while (a < b) {
		int m = (a + b) / 2;
		if (dist[size_t(m)] >= d) {
			b = m;
		} else {
			a = m + 1;
		}
	}
	return a;
}

void Perfiles::configurar(const ParametrosPelota &p, double elevacion_globo, int pasos) {
	_param = p;
	_param.viento = V3{};
	_elevacion_globo = elevacion_globo;
	_pasos = pasos;
	_raso.clear();
	_globo.clear();
	_hecho_raso.clear();
	_hecho_globo.clear();
}

double Perfiles::rapidez_de(int indice) {
	return PASO_RAPIDEZ * double(indice);
}

const Perfil &Perfiles::de(double rapidez, bool globo) {
	int i = std::max(1, int(rapidez / PASO_RAPIDEZ + 0.5));
	std::vector<Perfil> &lista = globo ? _globo : _raso;
	std::vector<bool> &hecho = globo ? _hecho_globo : _hecho_raso;
	if (int(lista.size()) <= i) {
		lista.resize(size_t(i) + 1);
		hecho.resize(size_t(i) + 1, false);
	}
	if (!hecho[size_t(i)]) {
		_armar(lista[size_t(i)], rapidez_de(i), globo ? _elevacion_globo : 0.0);
		hecho[size_t(i)] = true;
	}
	return lista[size_t(i)];
}

void Perfiles::_armar(Perfil &perfil, double rapidez, double elevacion) {
	Pelota q;
	q.configurar(_param);
	double s, c;
	mate::seno_coseno(elevacion, s, c);
	q.poner({ 0.0, _param.radio, 0.0 }, { rapidez * c, rapidez * s, 0.0 }, {});
	perfil.dist.clear();
	perfil.alto.clear();
	perfil.rapidez.clear();
	for (int k = 0; k < _pasos; k++) {
		q.avanzar();
		perfil.dist.push_back(q.pos.x);
		perfil.alto.push_back(q.pos.y);
		perfil.rapidez.push_back(std::sqrt(q.vel.x * q.vel.x + q.vel.z * q.vel.z));
		if (q.en_piso && q.vel.x == 0.0) {
			break;
		}
	}
}
