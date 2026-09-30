#include "remate.h"
#include "matematica_fija.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

namespace {
// Hasta cuándo sigue una pelota que se prueba: ningún remate tarda más.
constexpr double MAX_VUELO_SEG = 3.0;
// `apuntar` para cuando erra por menos que esto (m) en el plano del arco: es
// menos que el radio de la pelota.
constexpr double PRECISION_M = 0.02;
// Y acepta la mejor patada si erra por menos que esto: un pique o el roce
// del pasto hacen la cuenta escalonada y a veces no se afina más.
constexpr double ACEPTABLE_M = 0.25;
constexpr int VUELTAS = 8;
// El arco de las pruebas se corre hasta acá: ninguna llega.
constexpr double SIN_ARCO_M = 1e6;
// Barrido de la elevación de la patada tensa (rad): de un poco hacia abajo
// (le pega a la pelota que viene alta) hasta 60°.
constexpr double BARRIDO_DESDE = -0.1;
constexpr double BARRIDO_PASO = 0.04;
constexpr int BARRIDO_PASOS = 28;
// Pasos de las derivadas numéricas.
constexpr double PASO_ANGULO = 1e-3;
constexpr double PASO_RAPIDEZ = 0.05;

struct Prueba {
	bool llega = false;
	// Picó antes de cruzar: en esa rama la cuenta no es pareja (subir la
	// patada puede bajar el cruce) y no sirve para apuntar en el aire.
	bool pico = false;
	double dz = 0.0, dy = 0.0;
};

Prueba probar(const ParametrosPelota &param, V3 desde, V3 meta, double rumbo, double elevacion, double rapidez,
		double giro_lateral) {
	double sr, cr, se, ce;
	mate::seno_coseno(rumbo, sr, cr);
	mate::seno_coseno(elevacion, se, ce);
	Pelota p;
	p.configurar(param);
	p.poner(desde, { sr * ce * rapidez, se * rapidez, cr * ce * rapidez }, { 0.0, giro_lateral, 0.0 });
	V3 donde;
	double t;
	Prueba r;
	r.llega = cruce_con_plano(p, meta.x, MAX_VUELO_SEG, donde, t, &r.pico);
	r.dz = donde.z - meta.z;
	r.dy = donde.y - meta.y;
	return r;
}
} // namespace

double motor_v2::segun_atributo(double atributo, double en_0, double en_100) {
	return en_0 + std::clamp(atributo / 100.0, 0.0, 1.0) * (en_100 - en_0);
}

bool motor_v2::cruce_con_plano(const Pelota &p, double plano_x, double max_seg, V3 &donde, double &segundos,
		bool *pico) {
	Pelota copia = p;
	int64_t piques = copia.piques;
	double lado = plano_x >= copia.pos.x ? 1.0 : -1.0;
	int pasos = int(max_seg / Pelota::PASO_SEG);
	donde = copia.pos;
	segundos = 0.0;
	for (int k = 0; k < pasos; k++) {
		copia.avanzar();
		double antes = (copia.previa.x - plano_x) * lado;
		double ahora = (copia.pos.x - plano_x) * lado;
		if (ahora >= 0.0) {
			// Entre la foto anterior y esta, en línea recta: un paso de 1/60 s.
			double f = antes < 0.0 ? -antes / (ahora - antes) : 0.0;
			donde.x = plano_x;
			donde.y = copia.previa.y + (copia.pos.y - copia.previa.y) * f;
			donde.z = copia.previa.z + (copia.pos.z - copia.previa.z) * f;
			segundos = (double(k) + f) * Pelota::PASO_SEG;
			if (pico != nullptr) {
				*pico = copia.piques > piques;
			}
			return true;
		}
		if (copia.vel.x * lado <= 0.0 && copia.en_piso) {
			// Rodando para atrás o quieta: no llega nunca.
			break;
		}
	}
	donde = copia.pos;
	segundos = max_seg;
	return false;
}

bool motor_v2::apuntar(const ParametrosPelota &param, V3 desde, V3 meta, double rapidez, double elevacion_fija,
		double giro_lateral, V3 &vel, V3 &giro) {
	// Sin viento (el que patea no lo sabe) y sin arco: solo importa por dónde
	// cruza el plano. Con el arco, la prueba que pegaba en el travesaño no
	// llegaba y la cuenta subía la pelota en vez de bajarla.
	ParametrosPelota sin_viento = param;
	sin_viento.viento = {};
	sin_viento.medio_largo = SIN_ARCO_M;
	double dx = meta.x - desde.x, dz = meta.z - desde.z;
	double d = std::max(std::sqrt(dx * dx + dz * dz), 0.5);
	double dy = meta.y - desde.y;
	double g = param.gravedad;
	double rumbo = mate::arcotangente2(dx, dz);
	bool busca_rapidez = elevacion_fija >= 0.0;
	// Rasante: por el piso. Apuntado a 0,2 m por arriba, la patada salía en
	// globo (subía a 1,2 m en 16 m) y caía justo en la línea.
	bool rasante = !busca_rapidez && meta.y <= ALTO_RASANTE_M;
	auto valida = [rasante](const Prueba &p) {
		return p.llega && (rasante || !p.pico);
	};
	// El rasante se mide solo de costado.
	auto error_de = [&](const Prueba &p) {
		if (!valida(p)) {
			return 1e9;
		}
		return rasante ? std::abs(p.dz) : std::sqrt(p.dz * p.dz + p.dy * p.dy);
	};
	double elevacion, v;
	if (rasante) {
		v = rapidez;
		elevacion = 0.0;
	} else if (busca_rapidez) {
		// Tiro parabólico sin aire: v² = g d² / (2 cos²θ (d tanθ - dy)). El aire
		// lo deja corto y Newton sube la rapidez.
		elevacion = elevacion_fija;
		double s, c;
		mate::seno_coseno(elevacion, s, c);
		double abajo = 2.0 * c * c * (d * s / std::max(c, 1e-6) - dy);
		v = abajo > 1e-6 ? std::sqrt(g * d * d / abajo) : 15.0;
	} else {
		// Con la rapidez fija, la elevación más baja que cruza a esa altura sin
		// picar antes (la patada tensa, no el globo): se barre de abajo hacia
		// arriba y se interpola entre las dos que la encierran. Arrancando de la
		// parábola sin aire, a 20 m/s desde 28 m la patada picaba antes del arco
		// y Newton se perdía.
		v = rapidez;
		elevacion = -1.0;
		double anterior = 0.0;
		bool hay_anterior = false;
		for (int k = 0; k <= BARRIDO_PASOS; k++) {
			double e = BARRIDO_DESDE + BARRIDO_PASO * double(k);
			Prueba p = probar(sin_viento, desde, meta, rumbo, e, v, giro_lateral);
			if (valida(p) && p.dy >= 0.0) {
				elevacion = hay_anterior ? e - BARRIDO_PASO * p.dy / (p.dy - anterior) : e;
				break;
			}
			hay_anterior = valida(p);
			anterior = p.dy;
		}
		if (elevacion < -0.5) {
			return false;
		}
	}
	double mejor_error = 1e9;
	double mejor_rumbo = rumbo, mejor_segundo = busca_rapidez ? v : elevacion;
	for (int vuelta = 0; vuelta < VUELTAS; vuelta++) {
		Prueba p = probar(sin_viento, desde, meta, rumbo, elevacion, v, giro_lateral);
		double e = error_de(p);
		if (e < mejor_error) {
			mejor_error = e;
			mejor_rumbo = rumbo;
			mejor_segundo = busca_rapidez ? v : elevacion;
		}
		if (!valida(p)) {
			// Se queda corta o pica antes: el globo más fuerte; la patada tensa,
			// un poco más arriba.
			if (busca_rapidez) {
				v *= 1.1;
			} else {
				elevacion += 0.02;
			}
			continue;
		}
		if (e <= PRECISION_M) {
			break;
		}
		Prueba pr = probar(sin_viento, desde, meta, rumbo + PASO_ANGULO, elevacion, v, giro_lateral);
		if (rasante) {
			// Solo el ángulo horizontal: el alto es el de la pelota rodando.
			double a = (pr.dz - p.dz) / PASO_ANGULO;
			if (!valida(pr) || std::abs(a) < 1e-9) {
				break;
			}
			rumbo -= std::clamp(p.dz / a, -0.2, 0.2);
			continue;
		}
		// Newton con derivadas numéricas: el rumbo mueve z y el segundo
		// parámetro (elevación o rapidez) mueve y.
		double h = busca_rapidez ? PASO_RAPIDEZ : PASO_ANGULO;
		Prueba ps = busca_rapidez ? probar(sin_viento, desde, meta, rumbo, elevacion, v + h, giro_lateral)
								  : probar(sin_viento, desde, meta, rumbo, elevacion + h, v, giro_lateral);
		if (!valida(pr) || !valida(ps)) {
			break;
		}
		double a = (pr.dz - p.dz) / PASO_ANGULO, b = (ps.dz - p.dz) / h;
		double c = (pr.dy - p.dy) / PASO_ANGULO, dd = (ps.dy - p.dy) / h;
		double det = a * dd - b * c;
		if (std::abs(det) < 1e-12) {
			break;
		}
		double d_rumbo = (dd * p.dz - b * p.dy) / det;
		double d_segundo = (a * p.dy - c * p.dz) / det;
		rumbo -= std::clamp(d_rumbo, -0.2, 0.2);
		if (busca_rapidez) {
			v = std::clamp(v - std::clamp(d_segundo, -5.0, 5.0), 3.0, 40.0);
		} else {
			elevacion = std::clamp(elevacion - std::clamp(d_segundo, -0.2, 0.2), -0.3, 1.3);
		}
	}
	if (mejor_error > ACEPTABLE_M) {
		return false;
	}
	rumbo = mejor_rumbo;
	if (busca_rapidez) {
		v = mejor_segundo;
	} else {
		elevacion = mejor_segundo;
	}
	double sr, cr, se, ce;
	mate::seno_coseno(rumbo, sr, cr);
	mate::seno_coseno(elevacion, se, ce);
	vel = { sr * ce * v, se * v, cr * ce * v };
	giro = { 0.0, giro_lateral, 0.0 };
	return true;
}
