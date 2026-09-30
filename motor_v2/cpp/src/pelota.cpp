#include "pelota.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

namespace {
V3 operator+(V3 a, V3 b) {
	return { a.x + b.x, a.y + b.y, a.z + b.z };
}
V3 operator-(V3 a, V3 b) {
	return { a.x - b.x, a.y - b.y, a.z - b.z };
}
V3 operator*(V3 a, double k) {
	return { a.x * k, a.y * k, a.z * k };
}
double punto(V3 a, V3 b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}
V3 cruz(V3 a, V3 b) {
	return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x };
}
double largo(V3 a) {
	return std::sqrt(punto(a, a));
}
// Techo sin std::ceil: cualquier función del sistema salvo sqrt queda fuera
// del motor (docs/motor_v2.md, "Cómo se escribe el C++").
int techo(double x) {
	int t = int(x);
	return double(t) < x ? t + 1 : t;
}

constexpr double NADA = 1e300;

// Cuándo una esfera que va a velocidad `vd` por un eje, a distancia `d0` de un
// plano, queda a distancia `r` de él. Sirve desde los dos lados: la red se
// puede tocar de adentro o de afuera. Si ya está encimada no choca, así no
// queda pegada.
double tiempo_plano(double d0, double vd, double r) {
	if (std::abs(d0) < r - 1e-9 || d0 * vd >= 0.0) {
		return NADA;
	}
	return std::max(0.0, (std::abs(d0) - r) / std::abs(vd));
}

// Cuándo el punto (ax, ay) + (vx, vy)·t queda a distancia `s` del origen,
// viniendo de afuera: un cilindro visto de punta.
double tiempo_circulo(double ax, double ay, double vx, double vy, double s) {
	double a = vx * vx + vy * vy;
	double b = ax * vx + ay * vy;
	double c = ax * ax + ay * ay - s * s;
	if (b >= 0.0 || a < 1e-18) {
		return NADA;
	}
	if (c <= 0.0) {
		return 0.0;
	}
	double disc = b * b - a * c;
	if (disc < 0.0) {
		return NADA;
	}
	return (-b - std::sqrt(disc)) / a;
}
} // namespace

void Pelota::configurar(const ParametrosPelota &p) {
	param = p;
	constexpr double PI = 3.14159265358979323846;
	_k_aire = 0.5 * p.densidad_aire * PI * p.radio * p.radio / p.masa;
}

void Pelota::poner(V3 p, V3 v, V3 w) {
	if (_k_aire == 0.0) {
		configurar(param);
	}
	pos = p;
	previa = p;
	vel = v;
	giro = w;
	en_piso = p.y <= param.radio + 1e-9 && v.y <= 0.0;
	if (en_piso) {
		pos.y = param.radio;
		vel.y = 0.0;
	}
}

uint32_t Pelota::avanzar() {
	_eventos = 0;
	_recorrido = 0.0;
	previa = pos;
	bool movia = largo(vel) > 0.0;
	// Subpasos para que la pelota rápida no atraviese un palo: un remate a
	// 30 m/s avanza 0,5 m por paso y el palo mide 0,12 m.
	int subpasos = std::max(1, techo(largo(vel) * PASO_SEG / param.subpaso_max_m));
	double dt = PASO_SEG / double(subpasos);
	for (int s = 0; s < subpasos; s++) {
		_subpaso(dt);
	}
	if (movia && largo(vel) == 0.0) {
		_eventos |= SE_DETIENE;
	}
	double d = largo(pos - previa);
	if (d > _recorrido + 1e-9) {
		saltos++;
		peor_exceso_m = std::max(peor_exceso_m, d - _recorrido);
	}
	return _eventos;
}

void Pelota::_subpaso(double dt) {
	if (en_piso) {
		_rozamiento_piso(dt);
	} else {
		_fuerzas_aire(dt);
	}
	_mover_con_choques(dt);
}

// Gravedad, arrastre y Magnus contra el aire (con viento). El coeficiente de
// arrastre baja de cd_lenta a cd_rapida entre crisis_desde y crisis_hasta:
// la "crisis de arrastre" que hace que un tiro fuerte llegue y un pase flotado
// se frene. En rampa y no en escalón, para que la velocidad no pegue un salto
// al cruzar el umbral.
void Pelota::_fuerzas_aire(double dt) {
	V3 a = { 0.0, -param.gravedad, 0.0 };
	V3 relativa = vel - param.viento;
	double rapida = largo(relativa);
	if (rapida > 0.01) {
		double t = std::clamp((rapida - param.crisis_desde) / (param.crisis_hasta - param.crisis_desde), 0.0, 1.0);
		double cd = param.cd_lenta + (param.cd_rapida - param.cd_lenta) * t;
		a = a - relativa * (_k_aire * cd * rapida);
		double w = largo(giro);
		if (w > 0.1) {
			double cl = std::min(param.cl_por_giro * param.radio * w / rapida, param.cl_tope);
			a = a + cruz(giro, relativa) * (_k_aire * cl * rapida / w);
		}
	}
	vel = vel + a * dt;
	giro = giro * (1.0 - param.giro_decae_aire * dt);
}

// En el piso la pelota puede deslizar (el punto que toca el pasto se mueve)
// o rodar (no se mueve). Deslizando, el rozamiento frena la pelota y le da
// giro hasta que rueda: así un pique rasante "agarra" y un pase con efecto
// hacia atrás se frena. Rodando, solo la frena el pasto y el aire.
void Pelota::_rozamiento_piso(double dt) {
	double r = param.radio;
	V3 desliza = { vel.x + r * giro.z, 0.0, vel.z - r * giro.x };
	double s = largo(desliza);
	// Fracción del deslizamiento que se lleva un impulso para dejarla rodando:
	// k/(1+k) con la inercia de una esfera hueca (k = 2/3).
	double fraccion = _k_inercia / (1.0 + _k_inercia);
	double j = std::min(fraccion * s, param.rozamiento_deslizar * param.gravedad * dt);
	if (s > 1e-9) {
		V3 impulso = desliza * (-j / s);
		vel = vel + impulso;
		giro = giro + V3{ -impulso.z, 0.0, impulso.x } * (1.0 / (_k_inercia * r));
	}
	double h = std::sqrt(vel.x * vel.x + vel.z * vel.z);
	if (j >= fraccion * s - 1e-12) {
		// Ya rueda: el pasto y el aire la frenan.
		double frena = (param.frenado_rodando + _k_aire * param.cd_lenta * h * h) * dt;
		double f = h > frena ? (h - frena) / h : 0.0;
		vel = { vel.x * f, 0.0, vel.z * f };
		_sincronizar_rodada();
	}
	giro.y *= std::max(0.0, 1.0 - param.giro_vertical_decae_piso * dt);
	h = std::sqrt(vel.x * vel.x + vel.z * vel.z);
	if (h < param.quieta && std::abs(giro.y) < 1.0) {
		vel = {};
		giro = {};
	}
}

void Pelota::_sincronizar_rodada() {
	giro.x = vel.z / param.radio;
	giro.z = -vel.x / param.radio;
}

// Avanza `dt` frenando en el primer choque, lo resuelve y sigue con lo que
// queda. La pelota nunca se corrige de lugar: llega al punto de contacto y
// sale con la velocidad nueva, así cada paso recorre a lo sumo lo que da su
// velocidad (SALTO_PELOTA = 0 por construcción).
void Pelota::_mover_con_choques(double dt) {
	const double r = param.radio;
	const double L = param.medio_largo;
	const double W = param.arco_medio_ancho;
	const double H = param.arco_alto;
	const double fondo = L + param.profundidad_red;
	const double s = r + param.radio_palo;
	double resta = dt;
	for (int vuelta = 0; vuelta < 6 && resta > 0.0; vuelta++) {
		double t = NADA;
		V3 n;
		int tipo = 0; // 1 piso, 2 palo, 3 travesaño, 4 red
		auto candidato = [&](double tc, V3 nc, int tipoc, bool vale) {
			if (vale && tc < t && tc <= resta) {
				t = tc;
				n = nc;
				tipo = tipoc;
			}
		};
		if (!en_piso && vel.y < 0.0) {
			double tc = std::max(0.0, (pos.y - r) / -vel.y);
			candidato(tc, { 0.0, 1.0, 0.0 }, 1, true);
		}
		for (double lado : { -1.0, 1.0 }) {
			double linea = lado * L;
			// Palos: cilindros verticales hasta el travesaño.
			for (double palo : { -W, W }) {
				double tc = tiempo_circulo(pos.x - linea, pos.z - palo, vel.x, vel.z, s);
				if (tc < NADA) {
					V3 c = pos + vel * tc;
					V3 nc = { (c.x - linea) / s, 0.0, (c.z - palo) / s };
					candidato(tc, nc, 2, c.y <= H);
				}
			}
			// Travesaño: cilindro a lo ancho del arco.
			{
				double tc = tiempo_circulo(pos.x - linea, pos.y - H, vel.x, vel.y, s);
				if (tc < NADA) {
					V3 c = pos + vel * tc;
					V3 nc = { (c.x - linea) / s, (c.y - H) / s, 0.0 };
					candidato(tc, nc, 3, std::abs(c.z) <= W);
				}
			}
			// Red: fondo, costados y techo, tocables de los dos lados.
			{
				double d0 = pos.x - lado * fondo;
				double tc = tiempo_plano(d0, vel.x, r);
				if (tc < NADA) {
					V3 c = pos + vel * tc;
					candidato(tc, { d0 > 0.0 ? 1.0 : -1.0, 0.0, 0.0 }, 4, std::abs(c.z) <= W && c.y <= H);
				}
			}
			for (double costado : { -W, W }) {
				double d0 = pos.z - costado;
				double tc = tiempo_plano(d0, vel.z, r);
				if (tc < NADA) {
					V3 c = pos + vel * tc;
					double adentro = lado * c.x;
					candidato(tc, { 0.0, 0.0, d0 > 0.0 ? 1.0 : -1.0 }, 4, adentro >= L && adentro <= fondo && c.y <= H);
				}
			}
			{
				double d0 = pos.y - H;
				double tc = tiempo_plano(d0, vel.y, r);
				if (tc < NADA) {
					V3 c = pos + vel * tc;
					double adentro = lado * c.x;
					candidato(tc, { 0.0, d0 > 0.0 ? 1.0 : -1.0, 0.0 }, 4, adentro >= L && adentro <= fondo && std::abs(c.z) <= W);
				}
			}
		}
		double avanza = tipo == 0 ? resta : t;
		pos = pos + vel * avanza;
		_recorrido += largo(vel) * avanza;
		resta -= avanza;
		switch (tipo) {
			case 1:
				pos.y = r;
				_pique();
				break;
			case 2:
				_chocar(n, param.restitucion_palo, param.rozamiento_palo);
				palos++;
				_eventos |= PALO;
				break;
			case 3:
				_chocar(n, param.restitucion_palo, param.rozamiento_palo);
				travesanos++;
				_eventos |= TRAVESANO;
				break;
			case 4:
				_chocar(n, param.restitucion_red, param.rozamiento_red);
				redes++;
				_eventos |= RED;
				break;
			default:
				break;
		}
	}
}

// Pique: la vertical vuelve con restitución y el rozamiento del pasto cambia
// deslizamiento por giro, hasta dejarla rodando si alcanza (Coulomb: el
// impulso de rozamiento no pasa de rozamiento_pique × el impulso normal).
// Si llega casi sin vertical, no pica más: se apoya y rueda.
void Pelota::_pique() {
	double cae = -vel.y;
	double e = param.restitucion_piso;
	bool apoya = cae < param.vertical_rueda;
	double normal = apoya ? cae : (1.0 + e) * cae;
	double r = param.radio;
	V3 desliza = { vel.x + r * giro.z, 0.0, vel.z - r * giro.x };
	double s = largo(desliza);
	double fraccion = _k_inercia / (1.0 + _k_inercia);
	double j = std::min(fraccion * s, param.rozamiento_pique * normal);
	if (s > 1e-9) {
		V3 impulso = desliza * (-j / s);
		vel = vel + impulso;
		giro = giro + V3{ -impulso.z, 0.0, impulso.x } * (1.0 / (_k_inercia * r));
	}
	if (apoya) {
		vel.y = 0.0;
		en_piso = true;
		_eventos |= EMPIEZA_A_RODAR;
	} else {
		vel.y = cae * e;
		piques++;
		_eventos |= PIQUE;
	}
}

// Choque contra un palo o la red: la componente normal vuelve con
// restitución y la tangencial pierde `rozamiento`. El giro pierde lo mismo.
void Pelota::_chocar(V3 n, double restitucion, double rozamiento) {
	double vn = punto(vel, n);
	if (vn >= 0.0) {
		return;
	}
	V3 tangente = vel - n * vn;
	vel = tangente * (1.0 - rozamiento) - n * (restitucion * vn);
	giro = giro * (1.0 - rozamiento);
	if (en_piso && vel.y > 0.0) {
		en_piso = false;
	}
}
