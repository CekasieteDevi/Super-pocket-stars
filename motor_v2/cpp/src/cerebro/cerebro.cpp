#include "cerebro/cerebro.h"
#include "matematica_fija.h"
#include "remate.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

namespace {
// Segundos de una transición (MotorEspacial.SEGUNDOS_TRANSICION).
constexpr double SEGUNDOS_TRANSICION = 6.0;
// Cuánto se sostiene un plan antes de volver a pensarlo (TICKS_PLAN = 4).
constexpr double PLAN_SEG = 1.0;
// Cuánto se sostiene una fase de ritmo (TICKS_RITMO = 6).
constexpr double RITMO_SEG = 1.5;
// Duración de un desmarque (TICKS_DESMARQUE_MIN y MAX).
constexpr double DESMARQUE_MIN_SEG = 1.0;
constexpr double DESMARQUE_MAX_SEG = 3.0;
constexpr double SEPARACION_DESMARQUE = 4.0;
constexpr int MAX_RUPTURAS = 2;
constexpr double PRESION_DESTINO_INVIABLE = 0.85;
constexpr double PRESION_SIN_PERSECUCION = 0.35;
constexpr double CONO_SOLO_M = 15.0;
constexpr double ULTIMO_TERCIO = Cerebro::LARGO / 3.0;
constexpr double ULTIMO_TRAMO_BANDA = 24.0;
constexpr double PROFUNDIDAD_DEL_NUEVE_AL_CENTRO = 8.0;
constexpr double ARQUERO_X_MIN = 51.8;
constexpr double ARQUERO_X_MAX = 36.0;
constexpr double ARCO_MEDIO_ANCHO = 3.66;
// El defensor llega con la pierna estirada (Canchita: ALCANCE_RIVAL_M).
constexpr double ALCANCE_RIVAL_M = 0.45;
// La pared queda armada a lo sumo esto: si el muro no la devolvió, ya no es pared.
constexpr double PARED_SEG = 4.0;

// MotorEspacial.ATRACCION_X y ATRACCION_Y, por rol.
constexpr double ATRACCION_X[ROLES] = { 0.15, 0.35, 0.35, 0.45, 0.50, 0.50, 0.50 };
constexpr double ATRACCION_Y[ROLES] = { 0.10, 0.30, 0.25, 0.35, 0.40, 0.30, 0.35 };
// SUBIDA_POR_ROL (0 = el rol no acompaña).
constexpr double SUBIDA_POR_ROL[ROLES] = { 0.0, 0.30, 0.55, 0.75, 0.95, 0.0, 0.0 };
// ZONA_POR_ROL: 0 defensa, 1 medio, 2 ataque.
constexpr int ZONA_POR_ROL[ROLES] = { 1, 0, 0, 1, 1, 2, 2 };

// MEZCLA_PERFIL_RASGO: tres atributos y su peso por rasgo.
struct Mezcla {
	int atributo[3];
	double peso[3];
};
constexpr Mezcla MEZCLA_PERFIL[RASGOS] = {
	{ { AT_PASES, AT_VISION, AT_INTELIGENCIA }, { 0.45, 0.35, 0.20 } },
	{ { AT_VELOCIDAD, AT_ACELERACION, AT_ENERGIA }, { 0.45, 0.35, 0.20 } },
	{ { AT_CONTROL, AT_AGILIDAD, AT_ACELERACION }, { 0.45, 0.35, 0.20 } },
	{ { AT_FUERZA, AT_CONTROL, AT_CABEZAZO }, { 0.40, 0.35, 0.25 } },
	{ { AT_ENERGIA, AT_INTELIGENCIA, AT_TIRO }, { 0.40, 0.35, 0.25 } },
};
// SESGO_ROL_PERFIL (el arquero tiene perfil neutro).
constexpr double SESGO_ROL_PERFIL[ROLES][RASGOS] = {
	{ 0.0, 0.0, 0.0, 0.0, 0.0 },
	{ 0.05, -0.15, -0.20, 0.05, -0.15 },
	{ 0.0, 0.10, 0.0, -0.10, 0.10 },
	{ 0.15, -0.05, -0.05, -0.05, 0.05 },
	{ 0.15, 0.0, 0.10, 0.0, 0.10 },
	{ -0.10, 0.15, 0.20, -0.10, 0.0 },
	{ -0.10, 0.10, 0.0, 0.20, -0.05 },
};

enum FaseRitmo : int {
	CIRCULACION = 0,
	ACELERACION = 1,
	TRANSICION = 2,
	SIN_FASE = -1,
};

double hipot(double x, double z) {
	return std::sqrt(x * x + z * z);
}

double dist(double ax, double az, double bx, double bz) {
	return hipot(bx - ax, bz - az);
}

double lerp(double a, double b, double t) {
	return a + (b - a) * t;
}

double clamp01(double x) {
	return std::clamp(x, 0.0, 1.0);
}

double signo_de(double x) {
	return x > 0.0 ? 1.0 : (x < 0.0 ? -1.0 : 0.0);
}

// Godot smoothstep(desde, hasta, x).
double suave(double desde, double hasta, double x) {
	if (desde == hasta) {
		return x < desde ? 0.0 : 1.0;
	}
	double t = clamp01((x - desde) / (hasta - desde));
	return t * t * (3.0 - 2.0 * t);
}

// Vector2.normalized() de Godot: el cero queda en cero.
void normalizar(double &x, double &z) {
	double l = hipot(x, z);
	if (l > 0.0) {
		x /= l;
		z /= l;
	}
}

// Vector2.rotated(angulo).
void rotar(double x, double z, double angulo, double &rx, double &rz) {
	double s, c;
	mate::seno_coseno(angulo, s, c);
	rx = x * c - z * s;
	rz = x * s + z * c;
}

// Vector2.move_toward(hacia, delta).
void acercar(double x, double z, double hx, double hz, double delta, double &rx, double &rz) {
	double dx = hx - x, dz = hz - z;
	double l = hipot(dx, dz);
	if (l <= delta || l < 1e-9) {
		rx = hx;
		rz = hz;
		return;
	}
	rx = x + dx / l * delta;
	rz = z + dz / l * delta;
}

double potencia(double base, double exponente) {
	if (base <= 0.0) {
		return 0.0;
	}
	return mate::exponencial(exponente * mate::logaritmo(base));
}

bool es_pase(int tipo) {
	return tipo == DEC_PASE || tipo == DEC_PASE_HUECO || tipo == DEC_PASE_LARGO;
}
} // namespace

// --- Armado ---

void Cerebro::agregar(const FichaCerebro &f) {
	fichas.push_back(f);
}

void Cerebro::empezar() {
	size_t n = fichas.size();
	for (FichaCerebro &f : fichas) {
		// _construir_perfil: cada rasgo es una mezcla de atributos relativos al
		// nivel del partido más un sesgo del rol, y después se reparte alrededor
		// de 0,5 (lo que cuenta es en qué se destaca, no cuán bueno es).
		if (f.rol == ARQ) {
			for (double &p : f.perfil) {
				p = 0.5;
			}
			continue;
		}
		double crudo[RASGOS];
		double suma = 0.0;
		for (int r = 0; r < RASGOS; r++) {
			double v = 0.0;
			for (int k = 0; k < 3; k++) {
				v += MEZCLA_PERFIL[r].peso[k] * clamp01(f.relativo[MEZCLA_PERFIL[r].atributo[k]] / 100.0);
			}
			v += SESGO_ROL_PERFIL[std::clamp(f.rol, 0, ROLES - 1)][r];
			crudo[r] = v;
			suma += v;
		}
		double media = suma / double(RASGOS);
		for (int r = 0; r < RASGOS; r++) {
			f.perfil[r] = clamp01(0.5 + (crudo[r] - media) * pesos.perfil_reparto);
		}
	}
	_desmarques.assign(n, PlanDesmarque());
	_corredores.assign(n, Corredor());
	_apoyos.assign(n, Apoyo());
	_defensa[0] = _defensa[1] = Defensa();
	_ritmo = Ritmo();
	_ritmo.pares.assign(n * n, 0);
	_grilla.clear();
	_mejores_casillas.clear();
	_pared = Pared();
	_desmarques_hasta = -1.0;
	_desmarques_equipo = -1;
	_transicion_equipo = -1;
	_transicion_hasta = -1.0;
	_ultimo_equipo = -1;
	_ultimo_de = _ultimo_a = -1;
	_urgencia[0] = _urgencia[1] = 0.0;
	cuenta = ContadoresCerebro();
}

void Cerebro::quitar(int i) {
	if (i < 0 || i >= int(fichas.size())) {
		return;
	}
	fichas.erase(fichas.begin() + i);
	ultimo_decisor = -1;
	ContadoresCerebro c = cuenta;
	empezar();
	cuenta = c;
}

void Cerebro::cambiar(int i, const FichaCerebro &f) {
	if (i < 0 || i >= int(fichas.size())) {
		return;
	}
	fichas[size_t(i)] = f;
	ContadoresCerebro c = cuenta;
	empezar();
	cuenta = c;
}

// --- Geometría (MotorEspacial) ---

double Cerebro::valor_posicion(double x, double z, int equipo) {
	double ax = MEDIO_LARGO * signo(equipo);
	return clamp01(1.0 - dist(x, z, ax, 0.0) / LARGO);
}

double Cerebro::factor_angulo(double x, double z, int equipo) {
	double ax = MEDIO_LARGO * signo(equipo);
	double dx = std::max(std::abs(ax - x), 1.0);
	return clamp01(1.0 - (std::abs(z) / dx) / 1.5);
}

double Cerebro::factor_geometria(double x, double z, int equipo) const {
	double ax = MEDIO_LARGO * signo(equipo);
	double d = dist(x, z, ax, 0.0);
	double f_dist = clamp01(1.0 - (d - 5.0) / pesos.rango_tiro_medio);
	return f_dist * factor_angulo(x, z, equipo);
}

double Cerebro::dist_a_segmento(double px, double pz, double ax, double az, double bx, double bz) {
	double abx = bx - ax, abz = bz - az;
	double l2 = abx * abx + abz * abz;
	if (l2 < 0.001) {
		return dist(px, pz, ax, az);
	}
	double t = clamp01(((px - ax) * abx + (pz - az) * abz) / l2);
	return dist(px, pz, ax + abx * t, az + abz * t);
}

double Cerebro::_radio_zona(int rol) const {
	switch (ZONA_POR_ROL[std::clamp(rol, 0, ROLES - 1)]) {
		case 0:
			return pesos.def_radio_defensa;
		case 2:
			return pesos.def_radio_ataque;
		default:
			return pesos.def_radio_medio;
	}
}

double Cerebro::_por_atributo(int i, int atributo, double en_0, double en_100, double mezcla_absoluta) const {
	const FichaCerebro &f = fichas[size_t(i)];
	double valor = lerp(f.relativo[atributo], f.bruto[atributo], clamp01(mezcla_absoluta));
	return en_0 + clamp01(valor / 100.0) * (en_100 - en_0);
}

double Cerebro::_presion_sobre(const Mundo &m, double x, double z, int equipo, int excluir) const {
	double ax = MEDIO_LARGO * signo(equipo);
	double dx = ax - x, dz = -z;
	normalizar(dx, dz);
	double total = 0.0;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo || int(o) == excluir) {
			continue;
		}
		const JugadorVisto &e = m.jugadores[o];
		double d = dist(x, z, e.x, e.z);
		if (d >= pesos.presion_radio) {
			continue;
		}
		double cercania = 1.0 - d / pesos.presion_radio;
		double ex = e.x - x, ez = e.z - z;
		normalizar(ex, ez);
		double de_frente = std::max(0.0, dx * ex + dz * ez);
		total += cercania * (1.0 + de_frente * (pesos.presion_factor_frente - 1.0));
	}
	return total;
}

double Cerebro::presion_normalizada(const Mundo &m, double x, double z, int equipo, int excluir) const {
	return clamp01(_presion_sobre(m, x, z, equipo, excluir) / pesos.presion_normalizador);
}

double Cerebro::riesgo_linea(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const {
	double peor = 0.0;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo) {
			continue;
		}
		double d = dist_a_segmento(m.jugadores[o].x, m.jugadores[o].z, ax, az, bx, bz);
		if (d < 6.0) {
			peor = std::max(peor, 1.0 - d / 6.0);
		}
	}
	return peor;
}

// Pase seguro por tiempos (Simple Soccer, docs/motor_v2.md): cada rival
// contra el punto de la línea más cercano a él y contra el destino; el
// margen es cuánto después que la pelota llega el que mejor corta. Es lo que
// el mundo de la etapa 3 hace de verdad (corta el que llega primero), así que
// el cerebro decide con la misma cuenta con que después se resuelve. Con
// riesgo_linea solo, que mira la distancia y no los tiempos, se cortaba el 47%
// de los pases (tests/_diag_cerebro_v2.gd).
double Cerebro::_riesgo_pase(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const {
	double linea = riesgo_linea(m, ax, az, bx, bz, equipo);
	double mezcla = clamp01(pesos.riesgo_por_tiempos);
	if (mezcla <= 0.0) {
		return linea;
	}
	double largo = dist(ax, az, bx, bz);
	if (largo < 0.5) {
		return linea;
	}
	double ux = (bx - ax) / largo, uz = (bz - az) / largo;
	double rapidez = std::max(pesos.riesgo_rapidez_pase, 1.0);
	double margen = 1e9;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo) {
			continue;
		}
		const JugadorVisto &r = m.jugadores[o];
		double v = std::max(r.vel_max, 0.5);
		double a = std::clamp((r.x - ax) * ux + (r.z - az) * uz, 0.0, largo);
		double px = ax + ux * a, pz = az + uz * a;
		double t_rival = std::max(0.0, dist(r.x, r.z, px, pz) - ALCANCE_RIVAL_M) / v + pesos.reaccion_seg;
		margen = std::min(margen, t_rival - a / rapidez);
	}
	double tiempos = clamp01(1.0 - margen / std::max(pesos.riesgo_margen_seguro, 0.01));
	return lerp(linea, tiempos, mezcla);
}

double Cerebro::_riesgo_de_margen(double margen) const {
	return clamp01(1.0 - margen / std::max(pesos.riesgo_margen_seguro, 0.01));
}

// Un rival a espaldas de la salida presiona, pero no tapa ese carril.
double Cerebro::_riesgo_de_salida(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const {
	double peor = 0.0;
	double dx = bx - ax, dz = bz - az;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo) {
			continue;
		}
		const JugadorVisto &e = m.jugadores[o];
		double rx = e.x - ax, rz = e.z - az;
		if (rx * dx + rz * dz < 0.0 && hipot(rx, rz) > 2.0) {
			continue;
		}
		peor = std::max(peor, clamp01(1.0 - dist_a_segmento(e.x, e.z, ax, az, bx, bz) / 6.0));
	}
	return peor;
}

// CARRIL DE BANDA: el que viene abierto va al vértice del área, no al arco.
void Cerebro::_destino_de_conduccion(double x, double z, int equipo, double &dx, double &dz) const {
	double ax = MEDIO_LARGO * signo(equipo);
	dx = ax;
	dz = 0.0;
	if (std::abs(z) < pesos.banda_para_centrar || std::abs(ax - x) <= AREA_LARGO) {
		return;
	}
	double lado = z >= 0.0 ? 1.0 : -1.0;
	double vx = ax - signo_de(ax) * AREA_LARGO, vz = lado * AREA_MEDIO_ANCHO;
	double t = clamp01(pesos.apego_a_la_banda);
	dx = lerp(ax, vx, t);
	dz = lerp(0.0, vz, t);
}

bool Cerebro::_zona_de_desborde(double x, double z, int equipo) const {
	return std::abs(z) >= pesos.banda_para_centrar && std::abs(MEDIO_LARGO * signo(equipo) - x) < 16.0;
}

bool Cerebro::_en_el_area(double x, double z, int equipo) const {
	return std::abs(MEDIO_LARGO * signo(equipo) - x) <= AREA_LARGO && std::abs(z) <= AREA_MEDIO_ANCHO;
}

bool Cerebro::_corredor_de_desborde(const Mundo &m, int i, double &cx, double &cz) const {
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int equipo = fichas[size_t(i)].equipo;
	if (!_zona_de_desborde(p.x, p.z, equipo)) {
		return false;
	}
	double s = signo(equipo);
	for (size_t k = 0; k < _desmarques.size(); k++) {
		const PlanDesmarque &plan = _desmarques[k];
		if (!plan.vivo || !plan.pase_atras || plan.companero != i || plan.hasta <= m.segundos) {
			continue;
		}
		// Ganar fondo sin cerrar la banda antes de que llegue el rematador.
		double dx = std::clamp(p.x + 6.0 * s, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0);
		if ((dx - p.x) * s < 2.0 || riesgo_linea(m, p.x, p.z, dx, p.z, equipo) >= 0.45) {
			continue;
		}
		cx = dx;
		cz = p.z;
		return true;
	}
	return false;
}

// Compara tres carriles y se queda con el más libre un segundo, para que la
// evasión no oscile.
void Cerebro::_corredor_elegido(const Mundo &m, int i, double &cx, double &cz) const {
	Corredor &c = _corredores[size_t(i)];
	if (m.segundos < c.hasta) {
		cx = c.x;
		cz = c.z;
		return;
	}
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int equipo = fichas[size_t(i)].equipo;
	double s = signo(equipo);
	double dx, dz;
	_destino_de_conduccion(p.x, p.z, equipo, dx, dz);
	double fx = dx - p.x, fz = dz - p.z;
	normalizar(fx, fz);
	double largo = pesos.corredor_conduccion;
	if (std::abs(p.z) >= pesos.banda_para_centrar && std::abs(MEDIO_LARGO * s - p.x) > AREA_LARGO) {
		fx = s;
		fz = 0.0;
	}
	double mx = p.x + fx * largo, mz = p.z + fz * largo;
	double valor_mejor = -1e18;
	double bx, bz;
	if (_corredor_de_desborde(m, i, bx, bz)) {
		mx = bx;
		mz = bz;
		valor_mejor = 1.55 - riesgo_linea(m, p.x, p.z, mx, mz, equipo);
	}
	double vx = p.vx, vz = p.vz;
	bool corre = vx * vx + vz * vz > 0.01;
	normalizar(vx, vz);
	const double giros[3] = { 0.0, -0.55, 0.55 };
	for (double giro : giros) {
		double rx, rz;
		rotar(fx, fz, giro, rx, rz);
		double qx = std::clamp(p.x + rx * largo, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0);
		double qz = std::clamp(p.z + rz * largo, -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0);
		double libre = 1.0 - riesgo_linea(m, p.x, p.z, qx, qz, equipo);
		double valor = libre + 0.35 * (rx * fx + rz * fz);
		if (corre) {
			valor += 0.2 * (rx * vx + rz * vz);
		}
		if (valor > valor_mejor) {
			valor_mejor = valor;
			mx = qx;
			mz = qz;
		}
	}
	c.x = mx;
	c.z = mz;
	c.hasta = m.segundos + PLAN_SEG;
	cx = mx;
	cz = mz;
}

double Cerebro::_transicion(const Mundo &m, int equipo) const {
	if (_transicion_equipo != equipo) {
		return 0.0;
	}
	return clamp01((_transicion_hasta - m.segundos) / SEGUNDOS_TRANSICION);
}

// §4.2: visión e inteligencia la bajan, la presión la sube.
double Cerebro::_temperatura(int i, double presion) const {
	const FichaCerebro &f = fichas[size_t(i)];
	double valor = pesos.temp_base - pesos.temp_k_vision * (f.bruto[AT_VISION] / 100.0)
			- pesos.temp_k_inteligencia * (f.bruto[AT_INTELIGENCIA] / 100.0) + pesos.temp_k_presion * presion;
	if (f.metodico) {
		valor *= pesos.temp_factor_metodico;
	}
	return std::clamp(valor, pesos.temp_min, pesos.temp_max);
}

bool Cerebro::_solo_frente_al_arco(const Mundo &m, int i) const {
	const FichaCerebro &f = fichas[size_t(i)];
	if (f.rol == ARQ) {
		return false;
	}
	const JugadorVisto &p = m.jugadores[size_t(i)];
	if (_zona_de_desborde(p.x, p.z, f.equipo)) {
		return false;
	}
	double s = signo(f.equipo);
	double ox = p.mira_x, oz = p.mira_z;
	normalizar(ox, oz);
	if (ox * s < 0.5) {
		return false;
	}
	if (presion_normalizada(m, p.x, p.z, f.equipo) >= PRESION_SIN_PERSECUCION) {
		return false;
	}
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == f.equipo || fichas[o].rol == ARQ) {
			continue;
		}
		double dx = (m.jugadores[o].x - p.x) * s;
		if (dx > 0.0 && dx < CONO_SOLO_M && std::abs(m.jugadores[o].z - p.z) < 3.0 + dx * 0.5) {
			return false;
		}
	}
	return true;
}

// Con un rival de campo en su tercio, el arquero no sale jugando corto.
bool Cerebro::_arquero_encerrado(const Mundo &m, int equipo) const {
	double arco_x = -MEDIO_LARGO * signo(equipo);
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo != equipo && fichas[o].rol != ARQ
				&& std::abs(arco_x - m.jugadores[o].x) <= pesos.tercio_propio_arquero) {
			return true;
		}
	}
	return false;
}

int Cerebro::_rival_a_encarar(const Mundo &m, int i) const {
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int equipo = fichas[size_t(i)].equipo;
	double ax = MEDIO_LARGO * signo(equipo);
	double dx = ax - p.x, dz = -p.z;
	normalizar(dx, dz);
	int mejor = -1;
	double mejor_d = pesos.radio_tackle;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo || fichas[o].rol == ARQ) {
			continue;
		}
		double hx = m.jugadores[o].x - p.x, hz = m.jugadores[o].z - p.z;
		double d = hipot(hx, hz);
		if (d >= mejor_d || d < 0.05) {
			continue;
		}
		if (dx * hx / d + dz * hz / d < pesos.gambeta_cono_frontal) {
			continue;
		}
		mejor_d = d;
		mejor = int(o);
	}
	return mejor;
}

// Cambio de frente desde el último tercio: vale si del lado de la pelota hay
// bastantes más rivales que del otro y el destino está libre.
double Cerebro::_ventaja_cambio_frente(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const {
	if (std::abs(az) < 10.0 || az * bz >= 0.0 || std::abs(bz) < 16.0) {
		return 0.0;
	}
	if (std::abs(MEDIO_LARGO * signo(equipo) - ax) < ULTIMO_TERCIO) {
		return 0.0;
	}
	if ((bx - ax) * signo(equipo) < -6.0) {
		return 0.0;
	}
	double presion_destino = presion_normalizada(m, bx, bz, equipo);
	if (presion_destino >= 0.25) {
		return 0.0;
	}
	int lado_pelota = 0, lado_libre = 0;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo || fichas[o].rol == ARQ) {
			continue;
		}
		const JugadorVisto &r = m.jugadores[o];
		if (std::abs(r.x - ax) > 25.0) {
			continue;
		}
		if (r.z * signo_de(az) > 5.0) {
			lado_pelota++;
		} else if (r.z * signo_de(az) < -5.0) {
			lado_libre++;
		}
	}
	if (lado_pelota < 3 || lado_pelota - lado_libre < 2) {
		return 0.0;
	}
	return clamp01(double(lado_pelota - lado_libre) / 4.0) * (1.0 - presion_destino);
}

// Por delante del compañero, hacia el arco rival: más largo cuanto más rápido es.
void Cerebro::_punto_al_hueco(const Mundo &m, int r, double &x, double &z) const {
	const JugadorVisto &c = m.jugadores[size_t(r)];
	int equipo = fichas[size_t(r)].equipo;
	double dx = MEDIO_LARGO * signo(equipo) - c.x, dz = -c.z;
	normalizar(dx, dz);
	double t = clamp01((c.vel_max - pesos.vel_min) / std::max(pesos.vel_max - pesos.vel_min, 0.01));
	double largo = pesos.hueco_min + (pesos.hueco_max - pesos.hueco_min) * t;
	x = std::clamp(c.x + dx * largo, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0);
	z = std::clamp(c.z + dz * largo, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0);
}

void Cerebro::_punto_retorno_pared(double x, double z, int equipo, double avance, double &rx, double &rz) const {
	double dx = MEDIO_LARGO * signo(equipo) - x, dz = -z;
	normalizar(dx, dz);
	rx = std::clamp(x + dx * avance, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0);
	rz = std::clamp(z + dz * avance, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0);
}

// Ajusta el punto del pase atrás a la carrera real del que llega.
bool Cerebro::_encuentro_pase_atras(const Mundo &m, int pasador, int receptor, double px, double pz, double alcance,
		double &ex, double &ez) const {
	const JugadorVisto &d = m.jugadores[size_t(pasador)];
	const JugadorVisto &r = m.jugadores[size_t(receptor)];
	int equipo = fichas[size_t(pasador)].equipo;
	double s = signo(equipo);
	double ax = MEDIO_LARGO * s;
	auto atributo = [&](double distancia) {
		return fichas[size_t(pasador)].rol != ARQ ? AT_PASES : (distancia > pesos.dist_saque_largo ? AT_GOLPE : AT_PIES);
	};
	double velocidad = _por_atributo(pasador, atributo(dist(d.x, d.z, px, pz)), pesos.vel_pase_min, pesos.vel_pase_max);
	double tiempo = dist(d.x, d.z, r.x, r.z) / std::max(velocidad, 1.0);
	double antx, antz;
	acercar(r.x, r.z, px, pz, r.vel_max * tiempo * 0.65, antx, antz);
	const double puntos[5][2] = { { px, pz }, { antx, antz }, { px - 3.0 * s, pz }, { px, pz - 3.0 }, { px, pz + 3.0 } };
	double mejor = -1e18;
	bool hay = false;
	for (int k = 0; k < 5; k++) {
		double qx = puntos[k][0], qz = puntos[k][1];
		double profundidad = std::abs(ax - qx);
		if (profundidad < 7.0 || profundidad > 22.0 || std::abs(qz) > 11.0 || dist(qx, qz, px, pz) > 8.0
				|| (qx - d.x) * s >= -2.0) {
			continue;
		}
		double distancia = dist(d.x, d.z, qx, qz);
		double vel = _por_atributo(pasador, atributo(distancia), pesos.vel_pase_min, pesos.vel_pase_max);
		if (distancia > alcance || dist(r.x, r.z, qx, qz) > r.vel_max * distancia / std::max(vel, 1.0) * 0.75 + 1.5) {
			continue;
		}
		double riesgo = _riesgo_de_salida(m, d.x, d.z, qx, qz, equipo);
		// Desviar el plan solo si abre un carril claro; no regalarla para variar.
		if (riesgo >= (k == 0 ? 0.85 : 0.65)) {
			continue;
		}
		double libertad = 1.0 - presion_normalizada(m, qx, qz, equipo);
		double valor = 1.0 - riesgo + 0.6 * libertad - dist(qx, qz, px, pz) * 0.025;
		if (valor > mejor) {
			mejor = valor;
			ex = qx;
			ez = qz;
			hay = true;
		}
	}
	return hay;
}

// Tercer hombre: se la da al apoyo para que la descargue a uno que ya corre.
bool Cerebro::_buscar_tercer_hombre(const Mundo &m, int pasador, int apoyo, int &clave, double &x, double &z,
		double &riesgo_salida) const {
	const FichaCerebro &fa = fichas[size_t(apoyo)];
	if (fa.rol == ARQ || fa.bruto[AT_PASES] < pesos.pases_minimo_pared) {
		return false;
	}
	int equipo = fa.equipo;
	double s = signo(equipo);
	const JugadorVisto &jp = m.jugadores[size_t(pasador)];
	const JugadorVisto &ja = m.jugadores[size_t(apoyo)];
	double alcance = _por_atributo(apoyo, AT_PASES, pesos.max_dist_pase_malo, pesos.max_dist_pase_bueno, 1.0);
	double riesgo_inicial = riesgo_linea(m, jp.x, jp.z, ja.x, ja.z, equipo);
	double limite = pesos.sp_pared_riesgo_max;
	if (riesgo_inicial > limite) {
		return false;
	}
	double valor_mejor = -1e18;
	bool hay = false;
	for (size_t k = 0; k < _desmarques.size(); k++) {
		const PlanDesmarque &plan = _desmarques[k];
		if (!plan.vivo || int(k) == pasador || int(k) == apoyo || fichas[k].equipo != equipo || fichas[k].rol == ARQ
				|| (plan.tipo != DES_RUPTURA && plan.tipo != DES_LLEGADA)) {
			continue;
		}
		if ((plan.x - m.jugadores[k].x) * s <= 2.0 || dist(ja.x, ja.z, plan.x, plan.z) > alcance) {
			continue;
		}
		double progreso = valor_posicion(plan.x, plan.z, equipo) - valor_posicion(jp.x, jp.z, equipo);
		double riesgo = riesgo_linea(m, ja.x, ja.z, plan.x, plan.z, equipo);
		double valor = progreso + (1.0 - riesgo) * 0.3;
		if (progreso > 0.03 && riesgo <= limite && valor > valor_mejor) {
			valor_mejor = valor;
			clave = int(k);
			x = plan.x;
			z = plan.z;
			riesgo_salida = std::max(riesgo, riesgo_inicial);
			hay = true;
		}
	}
	return hay;
}

int Cerebro::_fallback_centro(const Mundo &m, int equipo, int excluir) const {
	int mejor = -1;
	double mejor_valor = -1e18;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo != equipo || int(o) == excluir || fichas[o].rol == ARQ) {
			continue;
		}
		double v = valor_posicion(m.jugadores[o].x, m.jugadores[o].z, equipo);
		if (v > mejor_valor) {
			mejor_valor = v;
			mejor = int(o);
		}
	}
	return mejor;
}

// Pie preferido (§6): cuánto de su lado malo tiene jugar hacia el destino.
double Cerebro::_cruce_al_pie_malo(int i, double ax, double az, double bx, double bz) const {
	const FichaCerebro &f = fichas[size_t(i)];
	if (f.pie_malo_lado == 0) {
		return 0.0;
	}
	double dx = bx - ax, dz = bz - az;
	if (dx * dx + dz * dz < 0.01) {
		return 0.0;
	}
	normalizar(dx, dz);
	double lateral = dz * signo(f.equipo);
	if (lateral * double(f.pie_malo_lado) >= 0.0) {
		return 0.0;
	}
	return std::abs(lateral);
}

double Cerebro::cadencia_seg(int i) const {
	double ticks = mate::redondear(_por_atributo(i, AT_CONTROL, pesos.ticks_control_malo, pesos.ticks_control_bueno));
	double asociacion = planes[fichas[size_t(i)].equipo & 1].asociacion;
	ticks = mate::redondear(ticks * lerp(1.0, 0.75, asociacion));
	return std::max(ticks, 1.0) * TICK_ESPACIAL_SEG;
}

// --- Decisión del poseedor (evaluar_opciones) ---

void Cerebro::_evaluar(const Mundo &m, int i, std::vector<Opcion> &op) const {
	const FichaCerebro &f = fichas[size_t(i)];
	const JugadorVisto &p = m.jugadores[size_t(i)];
	const PlanEquipo &plan = planes[f.equipo & 1];
	int equipo = f.equipo;
	double s = signo(equipo);
	double ax = MEDIO_LARGO * s;
	bool es_arquero = f.rol == ARQ;
	double x = p.x, z = p.z;
	double presion = presion_normalizada(m, x, z, equipo);
	double mi_valor = valor_posicion(x, z, equipo);
	bool acorralado = mi_valor <= pesos.zona_despeje && presion >= pesos.presion_despeje;
	bool arquero_encerrado = es_arquero && _arquero_encerrado(m, equipo);

	double cx, cz;
	_corredor_elegido(m, i, cx, cz);
	double camino_libre = 1.0 - riesgo_linea(m, x, z, cx, cz, equipo);
	if (!es_arquero) {
		Opcion o;
		o.tipo = DEC_CONDUCIR;
		o.utilidad = pesos.conducir_base + pesos.conducir_espacio * (1.0 - presion)
				+ pesos.conducir_progreso * (1.0 - mi_valor) + pesos.conducir_camino * camino_libre;
		op.push_back(o);
	}
	// Tirar (etapa 5): el alcance según su tiro solo habilita el intento; la
	// utilidad mira la misma geometría para todos, así tener más pierna no
	// vuelve mejor jugada un tiro de lejos (BUG-007 del motor espacial).
	if (!es_arquero && alcanza_para_tirar(i, x, z)) {
		Opcion o;
		o.tipo = DEC_REMATE;
		o.utilidad = pesos.tiro_base + pesos.tiro_geometria * factor_geometria(x, z, equipo);
		if (f.egoista) {
			o.utilidad *= pesos.egoista_tiro;
		}
		o.tiene_punto = true;
		o.x = ax;
		o.z = 0.0;
		op.push_back(o);
	}
	if (acorralado || arquero_encerrado) {
		Opcion o;
		o.tipo = DEC_DESPEJE;
		o.utilidad = pesos.despeje_base + pesos.despeje_presion * presion + pesos.despeje_zona * (1.0 - mi_valor);
		op.push_back(o);
	}
	// La gambeta espera sus clips de regate; el rival que tapa el camino lo
	// sigue necesitando la pared.
	int rival_delante = _rival_a_encarar(m, i);

	double max_dist = _por_atributo(i, es_arquero ? AT_GOLPE : AT_PASES, pesos.max_dist_pase_malo,
			pesos.max_dist_pase_bueno, 1.0);
	double sesgo_pase = f.creador ? pesos.creador_pase : 1.0;
	double max_largo = _por_atributo(i, AT_FUERZA, pesos.max_pelotazo_debil, pesos.max_pelotazo_fuerte, 1.0);
	bool frente_al_arco = _en_el_area(x, z, equipo) && factor_angulo(x, z, equipo) >= pesos.angulo_minimo_tiro_libre;
	bool puede_centrar = f.bruto[AT_CENTROS] >= pesos.centros_minimo && std::abs(z) >= pesos.banda_para_centrar
			&& mi_valor >= pesos.avance_para_centrar && std::abs(ax - x) <= ULTIMO_TRAMO_BANDA && !frente_al_arco;
	int fallback_centro = _fallback_centro(m, equipo, i);
	bool sabe_pared = f.bruto[AT_PASES] >= pesos.pases_minimo_pared;
	double dist_max_muro = _por_atributo(i, AT_PASES, pesos.pared_muro_cerca, pesos.pared_muro_lejos);
	double avance_pared = _por_atributo(i, AT_PASES, pesos.pared_avance_min, pesos.pared_avance_max);
	double vision = f.bruto[AT_VISION];
	bool ve_el_hueco = vision >= pesos.vision_minima_hueco;
	double factor_vision = 1.0 + pesos.hueco_por_vision
			* clamp01((vision - pesos.vision_minima_hueco) / std::max(100.0 - pesos.vision_minima_hueco, 1.0));
	auto atributo_pase = [&](double distancia) {
		return !es_arquero ? AT_PASES : (distancia > pesos.dist_saque_largo ? AT_GOLPE : AT_PIES);
	};

	for (size_t rr = 0; rr < fichas.size(); rr++) {
		int r = int(rr);
		if (fichas[rr].equipo != equipo || r == i) {
			continue;
		}
		const JugadorVisto &c = m.jugadores[rr];
		double d = dist(x, z, c.x, c.z);
		if (d < 2.0) {
			continue;
		}
		const PlanDesmarque &corrida = _desmarques[rr];
		bool corre_al_frente = corrida.vivo && (corrida.tipo == DES_RUPTURA || corrida.tipo == DES_LLEGADA);
		bool llegada_central = corre_al_frente && std::abs(corrida.z) <= 11.0 && std::abs(ax - corrida.x) <= 22.0;
		if (corrida.vivo && (corrida.pase_atras || llegada_central) && _zona_de_desborde(x, z, equipo)) {
			double ex = corrida.x, ez = corrida.z;
			double qx, qz;
			if (_encuentro_pase_atras(m, i, r, ex, ez, max_dist, qx, qz)) {
				ex = qx;
				ez = qz;
			}
			double de = dist(x, z, ex, ez);
			double riesgo = _riesgo_de_salida(m, x, z, ex, ez, equipo);
			double vel = _por_atributo(i, atributo_pase(de), pesos.vel_pase_min, pesos.vel_pase_max);
			double tiempo = de / std::max(vel, 1.0);
			bool llega = dist(c.x, c.z, ex, ez) <= c.vel_max * tiempo * 0.75 + 1.5;
			if (de <= max_dist && llega && riesgo < 0.85 && (ex - x) * s < -2.0) {
				Opcion o;
				o.tipo = DEC_PASE;
				o.receptor = r;
				o.tiene_punto = true;
				o.x = ex;
				o.z = ez;
				o.pase_atras_al_area = true;
				o.utilidad = pesos.pase_base + pesos.pase_seguridad * (1.0 - riesgo)
						+ 1.1 * (1.0 - presion_normalizada(m, ex, ez, equipo));
				op.push_back(o);
			}
		}
		if (ve_el_hueco && !es_arquero && corre_al_frente) {
			double de = dist(x, z, corrida.x, corrida.z);
			double avance = (corrida.x - c.x) * s;
			double riesgo = planeador ? _riesgo_de_margen(planeador->margen_al_punto(i, r, corrida.x, corrida.z))
									  : _riesgo_pase(m, x, z, corrida.x, corrida.z, equipo);
			bool listo = true;
			if (corrida.doblamiento) {
				listo = dist(c.x, c.z, corrida.x, corrida.z)
						<= c.vel_max * de / std::max(pesos.vel_pase_max, 1.0) * 0.75 + 1.5;
			}
			if (avance > 2.0 && de <= max_largo && riesgo < 0.55 && listo) {
				double u = pesos.hueco_base + pesos.hueco_progreso * (valor_posicion(corrida.x, corrida.z, equipo) - mi_valor)
						+ pesos.hueco_seguridad * (1.0 - riesgo) - pesos.hueco_distancia * de / max_largo;
				Opcion o;
				o.tipo = de > max_dist ? DEC_PASE_LARGO : DEC_PASE_HUECO;
				o.receptor = r;
				o.tiene_punto = true;
				o.x = corrida.x;
				o.z = corrida.z;
				o.corrida_preparada = true;
				o.utilidad = u * sesgo_pase * factor_vision + 0.35 * (1.0 - riesgo);
				op.push_back(o);
			}
		}
		// Centro: al que está en el área, al punto del área adonde corre, o al
		// más adelantado aunque no esté perfecto.
		bool hay_centro = false;
		double px = 0.0, pz = 0.0;
		if (puede_centrar && _en_el_area(c.x, c.z, equipo)) {
			hay_centro = true;
			px = c.x;
			pz = c.z;
		} else if (puede_centrar && corre_al_frente && _en_el_area(corrida.x, corrida.z, equipo)) {
			double dc = dist(x, z, corrida.x, corrida.z);
			double vel = _por_atributo(i, atributo_pase(dc), pesos.vel_pase_min, pesos.vel_pase_max);
			if (dist(c.x, c.z, corrida.x, corrida.z) <= c.vel_max * dc / std::max(vel, 1.0) * 0.75 + 1.5) {
				hay_centro = true;
				px = corrida.x;
				pz = corrida.z;
			}
		} else if (puede_centrar && r == fallback_centro) {
			hay_centro = true;
			px = ax - s * 10.0;
			pz = std::clamp(c.z, -AREA_MEDIO_ANCHO, AREA_MEDIO_ANCHO);
		}
		double alcance_centro = r == fallback_centro ? std::max(max_largo, 45.0) : max_largo;
		if (hay_centro && dist(x, z, px, pz) <= alcance_centro) {
			Opcion o;
			o.tipo = DEC_CENTRO;
			o.receptor = r;
			o.tiene_punto = true;
			o.x = px;
			o.z = pz;
			o.utilidad = pesos.centro_base + pesos.centro_punteria * (f.bruto[AT_CENTROS] / 100.0)
					+ pesos.centro_progreso * (valor_posicion(px, pz, equipo) - mi_valor) + 5.5 * plan.intencion_centro;
			op.push_back(o);
		}

		double ventaja_cambio = _ventaja_cambio_frente(m, x, z, c.x, c.z, equipo);
		double progreso_r = valor_posicion(c.x, c.z, equipo) - mi_valor;
		if (d > max_dist) {
			// Pelotazo: para los que están más lejos de lo que llega un pase.
			bool cambia_banda = z * c.z < 0.0 && std::abs(z - c.z) >= AREA_MEDIO_ANCHO && progreso_r >= -0.06
					&& (presion > 0.2 || camino_libre < 0.5) && presion_normalizada(m, c.x, c.z, equipo) < 0.25
					&& std::abs(ax - x) >= ULTIMO_TERCIO;
			cambia_banda = cambia_banda || ventaja_cambio > 0.0;
			if (d > max_largo || (progreso_r <= 0.0 && !cambia_banda)) {
				continue;
			}
			if (z * c.z < 0.0 && std::abs(c.z) >= pesos.banda_para_centrar && std::abs(ax - x) < ULTIMO_TERCIO) {
				continue;
			}
			Opcion o;
			o.tipo = DEC_PASE_LARGO;
			o.receptor = r;
			o.utilidad = pesos.largo_base + pesos.largo_progreso * progreso_r + pesos.largo_presion * presion
					+ pesos.largo_salida * (1.0 - mi_valor) + ventaja_cambio * 0.9;
			op.push_back(o);
			continue;
		}
		double riesgo = planeador ? _riesgo_de_margen(planeador->margen_pase(i, r)) : _riesgo_pase(m, x, z, c.x, c.z, equipo);
		double u = pesos.pase_base + pesos.pase_progreso * progreso_r + pesos.pase_seguridad * (1.0 - riesgo)
				- pesos.pase_distancia * (d / max_dist);
		u += ventaja_cambio * 0.9 * (1.0 - riesgo);
		if (progreso_r < 0.0) {
			u -= pesos.pase_retroceso_libre * (-progreso_r) * camino_libre * (1.0 - presion);
		}
		bool atras_al_area = std::abs(z) >= pesos.banda_para_centrar && mi_valor > 0.8
				&& std::abs(c.z) < pesos.banda_para_centrar && (c.x - x) * s < 0.0 && std::abs(c.x - x) < 14.0 && d < 24.0;
		if (atras_al_area) {
			u += 1.1 * (1.0 - riesgo);
		}
		if (std::abs(c.z) >= pesos.banda_para_centrar && std::abs(z) < pesos.banda_para_centrar && progreso_r > -0.03
				&& mi_valor > 0.45) {
			u += 0.5 * (1.0 - riesgo) * (1.0 - presion_normalizada(m, c.x, c.z, equipo));
		}
		{
			Opcion o;
			o.tipo = DEC_PASE;
			o.receptor = r;
			o.pase_atras_al_area = atras_al_area;
			o.utilidad = u;
			op.push_back(o);
		}

		if (sabe_pared && !es_arquero && d <= dist_max_muro) {
			int tercero;
			double tx, tz, riesgo_t;
			if (_buscar_tercer_hombre(m, i, r, tercero, tx, tz, riesgo_t)) {
				Opcion o;
				o.tipo = DEC_PARED;
				o.receptor = r;
				o.corredor = tercero;
				o.tiene_punto = true;
				o.x = tx;
				o.z = tz;
				o.utilidad = pesos.pared_base + plan.extra_pared
						+ pesos.pared_progreso * (valor_posicion(tx, tz, equipo) - mi_valor)
						+ pesos.pared_seguridad * (1.0 - riesgo_t) + 0.25;
				op.push_back(o);
			}
		}
		if (sabe_pared && !es_arquero && d <= dist_max_muro && rival_delante != -1) {
			double rx, rz;
			_punto_retorno_pared(x, z, equipo, avance_pared, rx, rz);
			Opcion o;
			o.tipo = DEC_PARED;
			o.receptor = r;
			o.corredor = i;
			o.tiene_punto = true;
			o.x = rx;
			o.z = rz;
			o.utilidad = pesos.pared_base + plan.extra_pared
					+ pesos.pared_progreso * (valor_posicion(rx, rz, equipo) - mi_valor)
					+ pesos.pared_seguridad * (1.0 - riesgo);
			op.push_back(o);
		}

		// Pase al hueco: al espacio por delante del compañero.
		if (!ve_el_hueco || es_arquero) {
			continue;
		}
		double hx, hz;
		_punto_al_hueco(m, r, hx, hz);
		double dh = dist(x, z, hx, hz);
		if (dh > max_dist) {
			continue;
		}
		double riesgo_h = planeador ? _riesgo_de_margen(planeador->margen_al_punto(i, r, hx, hz))
									: _riesgo_pase(m, x, z, hx, hz, equipo);
		double uh = pesos.hueco_base + pesos.hueco_progreso * (valor_posicion(hx, hz, equipo) - mi_valor)
				+ pesos.hueco_seguridad * (1.0 - riesgo_h) - pesos.hueco_distancia * (dh / max_dist);
		Opcion o;
		o.tipo = DEC_PASE_HUECO;
		o.receptor = r;
		o.tiene_punto = true;
		o.x = hx;
		o.z = hz;
		o.utilidad = uh * sesgo_pase * factor_vision;
		op.push_back(o);
	}
	// Nuevo en el V2: el globo paga lo que la física le dice que se va a
	// cortar. El pase raso ya lo paga en `seguridad` (su riesgo sale del
	// mismo margen), pero el pelotazo y el centro del motor espacial no
	// tenían término de seguridad: allá la intercepción era un sorteo aparte
	// (lectura_pase_largo). Sin esto se cortaba el 50% de los globos y eran
	// la mitad de los pases (tests/_diag_cerebro_v2.gd).
	if (planeador && pesos.castigo_corte > 0.0) {
		for (Opcion &o : op) {
			if (o.tipo != DEC_PASE_LARGO && o.tipo != DEC_CENTRO) {
				continue;
			}
			const JugadorVisto &r = m.jugadores[size_t(o.receptor)];
			double margen = planeador->margen_globo(i, o.tiene_punto ? o.x : r.x, o.tiene_punto ? o.z : r.z);
			o.utilidad -= pesos.castigo_corte * _riesgo_de_margen(margen);
		}
	}
}

double Cerebro::_gusto(int i, int rasgo) const {
	if (i < 0) {
		return 0.0;
	}
	return std::clamp((fichas[size_t(i)].perfil[rasgo] - 0.5) * 2.0, -1.0, 1.0);
}

int Cerebro::_veces_de_la_pareja(int a, int b) const {
	size_t n = fichas.size();
	int lo = std::min(a, b), hi = std::max(a, b);
	if (lo < 0 || size_t(hi) >= n) {
		return 0;
	}
	return _ritmo.pares[size_t(lo) * n + size_t(hi)];
}

bool Cerebro::_posesion_estancada(const Mundo &m, double presion) const {
	if (!_ritmo.hay || presion > pesos.ritmo_estancada_presion) {
		return false;
	}
	return m.segundos - _ritmo.t_avance >= pesos.ritmo_estancada_ticks * TICK_ESPACIAL_SEG;
}

int Cerebro::_ventana_tras_circular(const Mundo &m, int i, const std::vector<Opcion> &op) const {
	int equipo = fichas[size_t(i)].equipo;
	if (!_ritmo.hay || _ritmo.equipo != equipo || _ritmo.toques_circulacion < 2 || _ritmo.participantes.size() < 3) {
		return -1;
	}
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int mejor = -1;
	double valor_mejor = -1e18;
	for (size_t k = 0; k < op.size(); k++) {
		const Opcion &o = op[k];
		if (!es_pase(o.tipo) || o.receptor < 0) {
			continue;
		}
		double dx = o.tiene_punto ? o.x : m.jugadores[size_t(o.receptor)].x;
		double dz = o.tiene_punto ? o.z : m.jugadores[size_t(o.receptor)].z;
		double avance = (dx - p.x) * signo(equipo);
		if (avance < 8.0 || riesgo_linea(m, p.x, p.z, dx, dz, equipo) >= 0.35
				|| presion_normalizada(m, dx, dz, equipo) >= 0.3) {
			continue;
		}
		if (o.utilidad > valor_mejor) {
			valor_mejor = o.utilidad;
			mejor = int(k);
		}
	}
	return mejor;
}

double Cerebro::_ajuste_de_ritmo(int fase, int tipo, double adelante, double distancia, double libertad, bool cambio,
		double camino) const {
	if (fase != CIRCULACION && fase != ACELERACION) {
		return 0.0;
	}
	double a = 0.0;
	if (fase == CIRCULACION) {
		double cerrado = 1.0 - camino;
		if (tipo == DEC_PASE && libertad >= pesos.ritmo_apoyo_libre && distancia <= pesos.ritmo_circulacion_dist) {
			a += pesos.ritmo_circulacion_apoyo * libertad * cerrado;
		}
		if (cambio && (tipo == DEC_PASE || tipo == DEC_PASE_LARGO)) {
			a += pesos.ritmo_circulacion_cambio * libertad * cerrado;
		}
	} else {
		double gana = clamp01(adelante / 15.0);
		if (tipo == DEC_CONDUCIR) {
			a += pesos.ritmo_aceleracion_conducir * camino;
		} else if (tipo == DEC_PASE_HUECO) {
			a += pesos.ritmo_aceleracion_progreso * gana;
		} else if (tipo == DEC_PASE || tipo == DEC_PASE_LARGO) {
			a += pesos.ritmo_aceleracion_progreso * 0.6 * gana * libertad;
		}
	}
	return std::clamp(a, -pesos.ritmo_tope, pesos.ritmo_tope);
}

double Cerebro::_ajuste_de_marcador(double urg, int tipo, double adelante, double distancia, double libertad) const {
	if (std::abs(urg) < 0.01) {
		return 0.0;
	}
	double a = 0.0;
	double gana = clamp01(adelante / 15.0);
	bool atras = adelante < -2.0;
	if (urg > 0.0) {
		switch (tipo) {
			case DEC_PASE_HUECO:
				a += pesos.marc_riesgo * urg * gana;
				break;
			case DEC_CENTRO:
				a += pesos.marc_riesgo * urg * 0.5;
				break;
			case DEC_PASE:
			case DEC_PASE_LARGO:
				a += atras ? -pesos.marc_riesgo * urg : pesos.marc_riesgo * urg * 0.6 * gana;
				break;
			default:
				break;
		}
	} else {
		double p = -urg;
		switch (tipo) {
			case DEC_PASE:
				if (atras || distancia <= pesos.marc_seguridad_dist) {
					a += pesos.marc_seguridad * p * libertad;
				}
				break;
			case DEC_PASE_LARGO:
				a -= pesos.marc_seguridad * p * 0.4;
				break;
			case DEC_PASE_HUECO:
				a -= pesos.marc_seguridad * p * 0.6;
				break;
			default:
				break;
		}
	}
	return std::clamp(a, -pesos.marc_tope, pesos.marc_tope);
}

double Cerebro::_ajuste_de_perfil(int i, int receptor, int tipo, double adelante, double distancia, double libertad,
		double presion, double camino) const {
	double a = 0.0;
	switch (tipo) {
		case DEC_CONDUCIR:
			a += pesos.perfil_regate * _gusto(i, REGATE) * camino * (1.0 - presion);
			break;
		case DEC_PARED:
			a += pesos.perfil_asociacion * _gusto(i, ASOCIACION) * 0.8;
			break;
		case DEC_PASE: {
			double cerca = clamp01(1.0 - distancia / std::max(pesos.perfil_corto_dist, 1.0));
			a += pesos.perfil_asociacion * _gusto(i, ASOCIACION) * cerca * libertad;
			if (receptor >= 0 && adelante > 0.0) {
				a += pesos.perfil_descarga * _gusto(receptor, DESCARGA) * clamp01(1.0 - libertad) * clamp01(adelante / 12.0);
			}
			break;
		}
		case DEC_PASE_HUECO:
			a += pesos.perfil_asociacion * _gusto(i, ASOCIACION) * 0.5 * clamp01(adelante / 15.0);
			break;
		default:
			break;
	}
	return std::clamp(a, -pesos.perfil_tope, pesos.perfil_tope);
}

// _ponderar_plan: el mismo abanico de opciones pesa distinto según el plan
// del estilo, la transición, el ritmo, el marcador y el perfil del jugador.
void Cerebro::_ponderar(const Mundo &m, int i, std::vector<Opcion> &op, double presion, double camino) {
	const FichaCerebro &f = fichas[size_t(i)];
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int equipo = f.equipo;
	double s = signo(equipo);
	const PlanEquipo &plan = planes[equipo & 1];
	const PlanEquipo &rival = planes[(equipo + 1) & 1];
	double transicion = _transicion(m, equipo) * plan.transicion;
	bool contra_presion = plan.contragolpe && rival.presion_alta && transicion > 0.0;
	int grupos[DECISIONES] = {};
	for (const Opcion &o : op) {
		grupos[o.tipo]++;
	}
	double temp = _temperatura(i, presion);
	int fase = (_ritmo.hay && _ritmo.equipo == equipo) ? _ritmo.fase : SIN_FASE;
	int ventana = _ventana_tras_circular(m, i, op);
	if (ventana != -1 && fase != TRANSICION) {
		fase = ACELERACION;
		_ritmo.fase = fase;
		_ritmo.hasta = m.segundos + RITMO_SEG;
		op[size_t(ventana)].utilidad += 0.45;
	}
	double urg = _urgencia[equipo & 1];
	int devolver_a = -1;
	if (_posesion_estancada(m, presion) && _ultimo_a == i && _ultimo_de >= 0 && fichas[size_t(_ultimo_de)].equipo == equipo) {
		devolver_a = _ultimo_de;
	}
	for (Opcion &o : op) {
		double ajuste = -0.35 * temp * mate::logaritmo(double(grupos[o.tipo]));
		if (o.tipo == DEC_CONDUCIR) {
			ajuste += 0.45 * camino * (1.0 - presion) * (1.0 - plan.asociacion);
			ajuste += transicion * camino * 0.6;
			if (contra_presion) {
				ajuste += 0.50 * transicion * camino;
			}
			ajuste -= plan.asociacion * 0.2;
			ajuste += _ajuste_de_ritmo(fase, o.tipo, 0.0, 0.0, 0.0, false, camino);
			ajuste += _ajuste_de_perfil(i, -1, o.tipo, 0.0, 0.0, 0.0, presion, camino);
		} else if (o.tipo == DEC_PARED) {
			ajuste += plan.asociacion * 0.55;
			ajuste += _ajuste_de_perfil(i, -1, o.tipo, 0.0, 0.0, 0.0, presion, camino);
		} else if (es_pase(o.tipo)) {
			const JugadorVisto &r = m.jugadores[size_t(o.receptor)];
			double dx = o.tiene_punto ? o.x : r.x, dz = o.tiene_punto ? o.z : r.z;
			double adelante = (dx - p.x) * s;
			double d = dist(p.x, p.z, dx, dz);
			double libertad = 1.0 - presion_normalizada(m, dx, dz, equipo);
			bool cambio = p.z * dz < 0.0 && std::abs(p.z - dz) >= AREA_MEDIO_ANCHO;
			if (o.tipo == DEC_PASE) {
				ajuste += plan.asociacion * 1.15 * libertad * clamp01(1.0 - d / 35.0);
				ajuste -= (1.0 - libertad) * 0.55;
				if (adelante < -2.0 && !o.pase_atras_al_area) {
					ajuste -= camino * (1.0 - presion) * (0.45 + transicion);
				}
			} else if (o.tipo == DEC_PASE_HUECO) {
				ajuste += (plan.verticalidad * 0.35 + transicion * 0.8) * libertad * clamp01(adelante / 15.0);
				if (contra_presion) {
					ajuste += 0.65 * transicion * libertad * clamp01(adelante / 15.0);
				}
			} else {
				ajuste += plan.verticalidad * 0.3 + transicion * 0.45;
				ajuste -= plan.asociacion * 0.6;
				if (contra_presion) {
					ajuste += 0.40 * transicion * libertad;
				}
				if (adelante < -2.0) {
					ajuste -= 0.6 + camino * (1.0 - presion);
				}
				if (cambio) {
					ajuste += libertad * (0.5 + presion * 0.6);
				}
			}
			ajuste += _ajuste_de_ritmo(fase, o.tipo, adelante, d, libertad, cambio, camino);
			ajuste += _ajuste_de_marcador(urg, o.tipo, adelante, d, libertad);
			ajuste += _ajuste_de_perfil(i, o.receptor, o.tipo, adelante, d, libertad, presion, camino);
			if (devolver_a != -1 && o.receptor == devolver_a) {
				ajuste -= pesos.ritmo_devolucion_castigo
						* std::min(double(_veces_de_la_pareja(i, devolver_a)), pesos.ritmo_devolucion_max);
			}
		} else if (o.tipo == DEC_CENTRO) {
			ajuste += _ajuste_de_marcador(urg, o.tipo, 0.0, 0.0, 0.0);
			ajuste += _ajuste_de_perfil(i, -1, o.tipo, 0.0, 0.0, 0.0, presion, camino);
		}
		o.utilidad += ajuste;
	}
}

// Si aguanta y no pasa nada, el pase útil (adelante o abriendo) pesa más.
void Cerebro::_premiar_descarga(const Mundo &m, int i, std::vector<Opcion> &op) const {
	if (fichas[size_t(i)].rol == ARQ || _solo_frente_al_arco(m, i)) {
		return;
	}
	// (ticks_con_pelota - 3) / 6 del motor espacial, en segundos.
	double espera = clamp01((m.con_pelota_seg - 3.0 * TICK_ESPACIAL_SEG) / (6.0 * TICK_ESPACIAL_SEG));
	double peso = pesos.descarga_util;
	if (espera <= 0.0 || peso <= 0.0) {
		return;
	}
	int equipo = fichas[size_t(i)].equipo;
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int mejor = -1;
	double valor_mejor = -1e18;
	for (size_t k = 0; k < op.size(); k++) {
		const Opcion &o = op[k];
		if (!es_pase(o.tipo) || o.receptor < 0 || fichas[size_t(o.receptor)].rol == ARQ) {
			continue;
		}
		double dx = o.tiene_punto ? o.x : m.jugadores[size_t(o.receptor)].x;
		double dz = o.tiene_punto ? o.z : m.jugadores[size_t(o.receptor)].z;
		double avance = (dx - p.x) * signo(equipo);
		bool apertura = std::abs(dz) - std::abs(p.z) > 8.0 && avance >= -1.0;
		if (avance < 3.0 && !apertura) {
			continue;
		}
		if (_riesgo_de_salida(m, p.x, p.z, dx, dz, equipo) >= 0.45
				|| presion_normalizada(m, dx, dz, equipo) >= PRESION_SIN_PERSECUCION) {
			continue;
		}
		if (o.utilidad > valor_mejor) {
			mejor = int(k);
			valor_mejor = o.utilidad;
		}
	}
	if (mejor == -1) {
		return;
	}
	double bono = peso * espera;
	op[size_t(mejor)].utilidad += bono;
	for (Opcion &o : op) {
		if (o.tipo == DEC_CONDUCIR) {
			o.utilidad -= bono * 0.5;
		}
	}
}

Decision Cerebro::decidir(const Mundo &m, int i, bool puede_pasar, Azar &azar) {
	const FichaCerebro &f = fichas[size_t(i)];
	const JugadorVisto &p = m.jugadores[size_t(i)];
	int equipo = f.equipo;
	double s = signo(equipo);
	Decision dec;
	// El muro de una pared la devuelve al que sale a buscarla: son dos pases
	// encadenados y el segundo ya estaba decidido.
	int corredor;
	double rx, rz;
	if (muro_de_pared(m, corredor, rx, rz) == i) {
		dec.tipo = DEC_PASE_HUECO;
		dec.receptor = corredor;
		dec.tiene_punto = true;
		dec.x = rx;
		dec.z = rz;
		cuenta.decisiones[DEC_PASE_HUECO]++;
		return dec;
	}
	std::vector<Opcion> op;
	if (puede_pasar || f.rol == ARQ) {
		_evaluar(m, i, op);
	}
	if (!op.empty()) {
		double presion = presion_normalizada(m, p.x, p.z, equipo);
		double cx, cz;
		_corredor_elegido(m, i, cx, cz);
		double camino = 1.0 - riesgo_linea(m, p.x, p.z, cx, cz, equipo);
		_ponderar(m, i, op, presion, camino);
		// Pie preferido: le cuesta jugar hacia su lado malo.
		if (f.pie_malo_lado != 0) {
			for (Opcion &o : op) {
				if (o.tipo == DEC_CONDUCIR || o.tipo == DEC_DESPEJE || (o.receptor < 0 && o.tipo != DEC_REMATE)) {
					continue;
				}
				bool con_punto = o.tiene_punto && (es_pase(o.tipo) || o.tipo == DEC_REMATE);
				double dx = con_punto ? o.x : m.jugadores[size_t(o.receptor)].x;
				double dz = con_punto ? o.z : m.jugadores[size_t(o.receptor)].z;
				o.utilidad -= pesos.pie_preferido_penalizacion * _cruce_al_pie_malo(i, p.x, p.z, dx, dz);
			}
		}
		// Solo frente al arco no se la toca atrás ni al costado.
		if (_solo_frente_al_arco(m, i)) {
			std::vector<Opcion> sin_retroceso;
			for (const Opcion &o : op) {
				if (es_pase(o.tipo) || o.tipo == DEC_PARED) {
					bool con_punto = o.tiene_punto && o.tipo != DEC_PARED;
					double dx = con_punto ? o.x : m.jugadores[size_t(o.receptor)].x;
					if ((dx - p.x) * s < 3.0) {
						continue;
					}
				}
				sin_retroceso.push_back(o);
			}
			op.swap(sin_retroceso);
		}
		// Acorralado en su zona, o el arquero con un rival en su tercio: solo
		// sacarla de ahí.
		bool acorralado = valor_posicion(p.x, p.z, equipo) <= pesos.zona_despeje && presion >= pesos.presion_despeje;
		if (acorralado || (f.rol == ARQ && _arquero_encerrado(m, equipo))) {
			std::vector<Opcion> salidas;
			for (const Opcion &o : op) {
				if (o.tipo == DEC_DESPEJE || o.tipo == DEC_PASE_LARGO || o.tipo == DEC_REMATE) {
					salidas.push_back(o);
				}
			}
			if (!salidas.empty()) {
				op.swap(salidas);
			}
		}
		_premiar_descarga(m, i, op);
	}
	if (op.empty()) {
		Opcion o;
		o.tipo = f.rol == ARQ ? DEC_DESPEJE : DEC_CONDUCIR;
		op.push_back(o);
	}
	// elegir_softmax: se resta el máximo antes de exponenciar.
	size_t elegida = 0;
	double prob = 1.0;
	if (op.size() > 1) {
		double presion = presion_normalizada(m, p.x, p.z, equipo);
		double temp = _temperatura(i, presion);
		double max_u = -1e300;
		for (const Opcion &o : op) {
			max_u = std::max(max_u, o.utilidad);
		}
		std::vector<double> pesos_exp(op.size());
		double suma = 0.0;
		for (size_t k = 0; k < op.size(); k++) {
			pesos_exp[k] = mate::exponencial((op[k].utilidad - max_u) / temp);
			suma += pesos_exp[k];
		}
		double tirada = azar.uno() * suma;
		double acumulado = 0.0;
		elegida = op.size() - 1;
		for (size_t k = 0; k < op.size(); k++) {
			acumulado += pesos_exp[k];
			if (tirada <= acumulado) {
				elegida = k;
				break;
			}
		}
		prob = pesos_exp[elegida] / suma;
	}
	ultimo_decisor = i;
	ultima_temperatura = _temperatura(i, presion_normalizada(m, p.x, p.z, equipo));
	ultimas_opciones.clear();
	for (const Opcion &q : op) {
		OpcionVista v;
		v.tipo = q.tipo;
		v.receptor = q.receptor;
		v.x = q.x;
		v.z = q.z;
		v.utilidad = q.utilidad;
		ultimas_opciones.push_back(v);
	}
	const Opcion &o = op[elegida];
	dec.tipo = o.tipo;
	dec.receptor = o.receptor;
	dec.tiene_punto = o.tiene_punto;
	dec.x = o.x;
	dec.z = o.z;
	dec.utilidad = o.utilidad;
	dec.probabilidad = prob;
	dec.corrida_preparada = o.corrida_preparada;
	if (o.tipo == DEC_PARED) {
		// La pelota va al muro; el punto es adonde sale a correr el corredor.
		dec.corredor = o.corredor;
		dec.retorno_x = o.x;
		dec.retorno_z = o.z;
		dec.tiene_punto = false;
	} else if (o.tipo == DEC_CONDUCIR) {
		double cx, cz;
		_corredor_elegido(m, i, cx, cz);
		double dx = cx - p.x, dz = cz - p.z;
		normalizar(dx, dz);
		if (dx == 0.0 && dz == 0.0) {
			dx = s;
		}
		dec.dir_x = dx;
		dec.dir_z = dz;
	} else if (o.tipo == DEC_DESPEJE) {
		// Arriba y lejos, sin buscar a nadie: más lejos cuanto más pierna.
		double largo = _por_atributo(i, AT_FUERZA, pesos.despeje_corto, pesos.despeje_largo, 1.0);
		dec.tiene_punto = true;
		dec.x = std::clamp(p.x + s * largo, -MEDIO_LARGO + 3.0, MEDIO_LARGO - 3.0);
		dec.z = std::clamp(p.z * 0.5, -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0);
	}
	if (o.tipo == DEC_REMATE) {
		Decision r = elegir_remate(m, i, false, azar);
		dec.x = r.x;
		dec.z = r.z;
		dec.alto = r.alto;
		dec.golpe = r.golpe;
	}
	cuenta.decisiones[dec.tipo]++;
	if (dec.corrida_preparada) {
		cuenta.corridas_preparadas++;
	}
	return dec;
}

// --- Avisos del mundo ---

void Cerebro::anotar_pase(const Mundo &m, int de, int a) {
	if (de < 0 || a < 0) {
		return;
	}
	_ultimo_de = de;
	_ultimo_a = a;
	if (!_ritmo.hay) {
		return;
	}
	size_t n = fichas.size();
	int lo = std::min(de, a), hi = std::max(de, a);
	_ritmo.pares[size_t(lo) * n + size_t(hi)]++;
	if (fichas[size_t(de)].equipo != fichas[size_t(a)].equipo) {
		return;
	}
	double avance = (m.jugadores[size_t(a)].x - m.jugadores[size_t(de)].x) * signo(fichas[size_t(a)].equipo);
	if (avance >= 8.0) {
		_ritmo.toques_circulacion = 0;
		_ritmo.participantes.clear();
	} else {
		_ritmo.toques_circulacion++;
		for (int k : { de, a }) {
			if (std::find(_ritmo.participantes.begin(), _ritmo.participantes.end(), k) == _ritmo.participantes.end()) {
				_ritmo.participantes.push_back(k);
			}
		}
	}
}

void Cerebro::anotar_pared(const Mundo &m, int muro, int corredor, double x, double z) {
	_pared.vivo = true;
	_pared.muro = muro;
	_pared.corredor = corredor;
	_pared.x = x;
	_pared.z = z;
	_pared.hasta = m.segundos + PARED_SEG;
}

int Cerebro::muro_de_pared(const Mundo &m, int &corredor, double &x, double &z) const {
	if (!_pared.vivo || m.segundos >= _pared.hasta || _pared.corredor < 0) {
		return -1;
	}
	corredor = _pared.corredor;
	x = _pared.x;
	z = _pared.z;
	return _pared.muro;
}

// Offside con la foto del cuadro del pase: en campo rival, delante de la
// pelota y delante del penúltimo rival.
bool Cerebro::en_offside(const Mundo &m, int receptor) const {
	if (receptor < 0) {
		return false;
	}
	int equipo = fichas[size_t(receptor)].equipo;
	double s = signo(equipo);
	double x = m.jugadores[size_t(receptor)].x * s;
	if (x <= 0.0 || x <= m.pelota_x * s) {
		return false;
	}
	double primero = -1e9, segundo = -1e9;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == equipo) {
			continue;
		}
		double r = m.jugadores[o].x * s;
		if (r > primero) {
			segundo = primero;
			primero = r;
		} else if (r > segundo) {
			segundo = r;
		}
	}
	return x > segundo;
}

// --- Planes (cada uno con su reloj) ---

void Cerebro::planificar(const Mundo &m) {
	_actualizar_transicion(m);
	_planificar_ritmo(m);
	_planificar_marcador(m);
	_calcular_lineas(m);
	int ataca = m.equipo_con_pelota & 1;
	_defensa[ataca] = Defensa();
	_planificar_defensa(m, 1 - ataca);
	_planificar_grilla(m);
	_planificar_desmarques(m, ataca);
	if (_pared.vivo && (m.segundos >= _pared.hasta || fichas[size_t(_pared.muro)].equipo != ataca)) {
		_pared.vivo = false;
	}
}

void Cerebro::_actualizar_transicion(const Mundo &m) {
	if (m.detenido) {
		_transicion_hasta = -1.0;
		if (m.poseedor >= 0) {
			_ultimo_equipo = fichas[size_t(m.poseedor)].equipo;
		}
		return;
	}
	if (m.poseedor < 0) {
		return;
	}
	int equipo = fichas[size_t(m.poseedor)].equipo;
	if (_ultimo_equipo >= 0 && _ultimo_equipo != equipo) {
		_transicion_equipo = equipo;
		// Contragolpe ensayado: la salida rápida dura más.
		_transicion_hasta = m.segundos + SEGUNDOS_TRANSICION * (1.0 + planes[equipo & 1].extra_contragolpe);
	}
	_ultimo_equipo = equipo;
}

void Cerebro::_planificar_ritmo(const Mundo &m) {
	if (m.detenido) {
		std::vector<int> pares = std::move(_ritmo.pares);
		_ritmo = Ritmo();
		_ritmo.pares = std::move(pares);
		std::fill(_ritmo.pares.begin(), _ritmo.pares.end(), 0);
		return;
	}
	int ataca = m.equipo_con_pelota & 1;
	double s = signo(ataca);
	double x = m.pelota_x * s;
	if (!_ritmo.hay || _ritmo.equipo != ataca) {
		std::vector<int> pares = std::move(_ritmo.pares);
		_ritmo = Ritmo();
		_ritmo.pares = std::move(pares);
		std::fill(_ritmo.pares.begin(), _ritmo.pares.end(), 0);
		_ritmo.hay = true;
		_ritmo.equipo = ataca;
		_ritmo.fase = TRANSICION;
		_ritmo.x_inicio = x;
		_ritmo.t_avance = m.segundos;
	}
	// _actualizar_progreso: cuánto avanzó la posesión desde que empezó.
	double avance = x - _ritmo.x_inicio;
	if (avance > _ritmo.mejor + 0.5) {
		_ritmo.mejor = avance;
		_ritmo.t_avance = m.segundos;
		if (avance >= _ritmo.mejor_premiado + pesos.ritmo_estancada_avance) {
			_ritmo.mejor_premiado = avance;
			std::fill(_ritmo.pares.begin(), _ritmo.pares.end(), 0);
		}
	}
	if (_transicion(m, ataca) > pesos.ritmo_umbral_transicion) {
		_ritmo.fase = TRANSICION;
		_ritmo.hasta = -1.0;
	} else if (m.segundos >= _ritmo.hasta) {
		_ritmo.hasta = m.segundos + RITMO_SEG;
		if (m.poseedor >= 0 && fichas[size_t(m.poseedor)].equipo == ataca) {
			const JugadorVisto &p = m.jugadores[size_t(m.poseedor)];
			double dx, dz;
			_destino_de_conduccion(p.x, p.z, ataca, dx, dz);
			double fx = dx - p.x, fz = dz - p.z;
			normalizar(fx, fz);
			double frx = p.x + fx * pesos.ritmo_frente, frz = p.z + fz * pesos.ritmo_frente;
			double espacio = 1.0 - riesgo_linea(m, p.x, p.z, frx, frz, ataca);
			int apoyos = 0;
			for (size_t c = 0; c < fichas.size(); c++) {
				if (int(c) == m.poseedor || fichas[c].equipo != ataca || fichas[c].rol == ARQ) {
					continue;
				}
				const JugadorVisto &q = m.jugadores[c];
				if ((q.x - p.x) * s < pesos.ritmo_apoyo_adelante || dist(p.x, p.z, q.x, q.z) > pesos.ritmo_apoyo_alcance) {
					continue;
				}
				if (1.0 - presion_normalizada(m, q.x, q.z, ataca) < pesos.ritmo_apoyo_libre) {
					continue;
				}
				if (riesgo_linea(m, p.x, p.z, q.x, q.z, ataca) > pesos.ritmo_carril_libre) {
					continue;
				}
				apoyos++;
			}
			_ritmo.fase = (espacio >= pesos.ritmo_espacio_para_acelerar || apoyos > 0) ? ACELERACION : CIRCULACION;
		}
	}
	cuenta.fases_ritmo[std::clamp(_ritmo.fase, 0, 2)]++;
}

void Cerebro::_planificar_marcador(const Mundo &m) {
	double avance = clamp01(m.minuto / 90.0);
	for (int e = 0; e < 2; e++) {
		int dif = m.goles[e] - m.goles[1 - e];
		double base;
		if (dif == 0) {
			base = pesos.marc_empate;
		} else {
			double cuanto = std::min(1.0 + double(std::abs(dif) - 1) * pesos.marc_dif_extra, pesos.marc_dif_tope);
			base = -signo_de(double(dif)) * cuanto;
		}
		if (planes[e].rasgo_dt == 1 && base > 0.0) {
			base *= pesos.marc_dt_loco;
		} else if (planes[e].rasgo_dt == 2 && base < 0.0) {
			base *= pesos.marc_dt_conservador;
		}
		_urgencia[e] = std::clamp(base * potencia(avance, pesos.marc_exponente), -1.0, 1.0);
	}
}

// Línea de offside (la del motor espacial: último defensor de campo o la
// pelota) y la línea defensiva nueva.
void Cerebro::_calcular_lineas(const Mundo &m) {
	double tope_0 = -1e18, tope_1 = 1e18;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].rol == ARQ) {
			continue;
		}
		if (fichas[o].equipo == 0) {
			tope_1 = std::min(tope_1, m.jugadores[o].x);
		} else {
			tope_0 = std::max(tope_0, m.jugadores[o].x);
		}
	}
	_linea_offside[0] = std::max(tope_0 > -1e17 ? tope_0 : LIMITE_X, m.pelota_x);
	_linea_offside[1] = std::min(tope_1 < 1e17 ? tope_1 : -LIMITE_X, m.pelota_x);
	// Sin la pelota, centrales y laterales se paran a la misma altura: la media
	// de sus anclas. Cada uno con su ancla suelta, el lateral del lado de la
	// pelota quedaba varios metros por delante del central y habilitaba a
	// cualquiera que picara por ese costado.
	for (int e = 0; e < 2; e++) {
		double suma = 0.0;
		int cuantos = 0;
		for (size_t o = 0; o < fichas.size(); o++) {
			if (fichas[o].equipo != e || (fichas[o].rol != DFC && fichas[o].rol != LAT)) {
				continue;
			}
			double x, z;
			_ancla(m, int(o), m.equipo_con_pelota == e, x, z);
			suma += x;
			cuantos++;
		}
		if (cuantos > 0) {
			_linea_defensiva[e] = suma / double(cuantos);
		}
	}
}

double Cerebro::_tiempo_de_llegada(const Mundo &m, int i, double x, double z) const {
	const FichaCerebro &f = fichas[size_t(i)];
	const JugadorVisto &e = m.jugadores[size_t(i)];
	double vel = std::max(e.vel_max, 0.5);
	double t = dist(e.x, e.z, x, z) / vel;
	double radio = _radio_zona(f.rol);
	double bx = f.base_x * signo(f.equipo), bz = f.base_z;
	t += std::max(0.0, dist(bx, bz, x, z) - radio) * pesos.def_zona;
	t += (1.0 - clamp01(e.resistencia)) * pesos.def_cansancio;
	return t;
}

void Cerebro::_recortar_a_la_zona(int i, double &x, double &z) const {
	const FichaCerebro &f = fichas[size_t(i)];
	double radio = _radio_zona(f.rol);
	double s = signo(f.equipo);
	double bx = f.base_x * s, bz = f.base_z;
	if ((x - bx) * s > radio) {
		x = bx + radio * s;
	}
	z = std::clamp(z, bz - radio, bz + radio);
}

double Cerebro::_intensidad_de_presion(const Mundo &m, int defiende) const {
	double senales = 0.0;
	if (m.poseedor < 0 || m.con_pelota_seg <= TICK_ESPACIAL_SEG) {
		senales += 1.0; // control largo: la pelota todavía no está dominada
	}
	if (m.poseedor >= 0) {
		const JugadorVisto &p = m.jugadores[size_t(m.poseedor)];
		double hx = MEDIO_LARGO * signo(fichas[size_t(m.poseedor)].equipo) - p.x, hz = -p.z;
		normalizar(hx, hz);
		double vx = p.vx, vz = p.vz;
		if (vx * vx + vz * vz > 0.25) {
			normalizar(vx, vz);
			if (vx * hx + vz * hz < 0.0) {
				senales += 1.0; // recibió de espaldas y va hacia atrás
			}
		}
	}
	if (std::abs(m.pelota_z) > MEDIO_ANCHO - pesos.def_banda_disparador) {
		senales += 1.0; // contra la banda
	}
	senales += _transicion(m, 1 - defiende);
	return clamp01(senales / 3.0);
}

void Cerebro::_punto_de_cobertura(const Mundo &m, int pres, double intensidad, double &x, double &z) const {
	const FichaCerebro &f = fichas[size_t(pres)];
	const JugadorVisto &p = m.jugadores[size_t(pres)];
	double ax = -MEDIO_LARGO * signo(f.equipo);
	double dx = ax - p.x, dz = -p.z;
	if (hipot(dx, dz) < 0.5) {
		dx = -signo(f.equipo);
		dz = 0.0;
	}
	normalizar(dx, dz);
	double atras = pesos.def_cobertura_atras * lerp(1.0, pesos.def_cobertura_cerca, intensidad);
	const PlanEquipo &plan = planes[f.equipo & 1];
	if (plan.contragolpe || plan.defensivo) {
		atras *= pesos.def_cobertura_bloque;
	}
	double guarda = std::max(0.0, -_urgencia[f.equipo & 1]);
	atras *= 1.0 + guarda * pesos.marc_cobertura_extra;
	x = p.x + dx * atras;
	z = p.z + dz * atras;
}

bool Cerebro::_punto_de_cierre(const Mundo &m, int defiende, double evitar_x, double evitar_z, double &x, double &z) const {
	struct Salida {
		int clave;
		double d2;
	};
	std::vector<Salida> salidas;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == defiende || fichas[o].rol == ARQ) {
			continue;
		}
		double d = dist(m.pelota_x, m.pelota_z, m.jugadores[o].x, m.jugadores[o].z);
		if (d > pesos.def_cierre_cerca && d < pesos.def_cierre_lejos) {
			salidas.push_back({ int(o), d * d });
		}
	}
	std::sort(salidas.begin(), salidas.end(), [](const Salida &a, const Salida &b) {
		return a.d2 == b.d2 ? a.clave < b.clave : a.d2 < b.d2;
	});
	for (const Salida &s : salidas) {
		const JugadorVisto &c = m.jugadores[size_t(s.clave)];
		double px = lerp(m.pelota_x, c.x, pesos.def_cierre_carril);
		double pz = lerp(m.pelota_z, c.z, pesos.def_cierre_carril);
		if (dist(px, pz, evitar_x, evitar_z) > 4.0) {
			x = px;
			z = pz;
			return true;
		}
	}
	return false;
}

bool Cerebro::_presion_superada(const Mundo &m, int defiende) const {
	const Defensa &d = _defensa[defiende & 1];
	if (!d.enganchado || d.presionante < 0 || m.poseedor < 0) {
		return false;
	}
	double ax = -MEDIO_LARGO * signo(defiende);
	const JugadorVisto &p = m.jugadores[size_t(m.poseedor)];
	const JugadorVisto &q = m.jugadores[size_t(d.presionante)];
	return dist(ax, 0.0, p.x, p.z) < dist(ax, 0.0, q.x, q.z) - 2.0;
}

// Presionante, cobertura y cierre (§ defensa del motor espacial).
void Cerebro::_planificar_defensa(const Mundo &m, int defiende) {
	Defensa &plan = _defensa[defiende & 1];
	double intensidad = _intensidad_de_presion(m, defiende);
	std::vector<int> disponibles;
	for (size_t o = 0; o < fichas.size(); o++) {
		if (fichas[o].equipo == defiende && fichas[o].rol != ARQ) {
			disponibles.push_back(int(o));
		}
	}
	auto disponible = [&](int k) {
		return std::find(disponibles.begin(), disponibles.end(), k) != disponibles.end();
	};
	int mejor = -1;
	double mejor_t = 1e18;
	for (int k : disponibles) {
		double t = _tiempo_de_llegada(m, k, m.pelota_x, m.pelota_z);
		if (t < mejor_t) {
			mejor_t = t;
			mejor = k;
		}
	}
	bool sostiene = plan.presionante != -1 && disponible(plan.presionante) && m.segundos < plan.hasta;
	if (sostiene && mejor != -1 && mejor != plan.presionante) {
		double t_actual = _tiempo_de_llegada(m, plan.presionante, m.pelota_x, m.pelota_z);
		if (mejor_t < t_actual * (1.0 - pesos.def_mejora_presionante)) {
			sostiene = false;
		}
	}
	if (!sostiene) {
		plan.presionante = mejor;
		plan.hasta = m.segundos + PLAN_SEG;
		plan.enganchado = false;
	}
	if (plan.presionante != -1) {
		const JugadorVisto &q = m.jugadores[size_t(plan.presionante)];
		if (dist(q.x, q.z, m.pelota_x, m.pelota_z) <= pesos.def_enganche) {
			plan.enganchado = true;
		}
	}
	double cob_x = 0.0, cob_z = 0.0;
	if (plan.presionante == -1) {
		plan.cobertura = -1;
	} else {
		_punto_de_cobertura(m, plan.presionante, intensidad, cob_x, cob_z);
		if (plan.cobertura == plan.presionante || !disponible(plan.cobertura) || m.segundos >= plan.hasta) {
			plan.cobertura = -1;
			double t_cob = 1e18;
			for (int k : disponibles) {
				if (k == plan.presionante) {
					continue;
				}
				double t = _tiempo_de_llegada(m, k, cob_x, cob_z);
				if (t < t_cob) {
					t_cob = t;
					plan.cobertura = k;
				}
			}
		}
	}
	plan.cierre = -1;
	plan.hay_cierre = false;
	if (plan.presionante != -1 && plan.cobertura != -1) {
		const PlanEquipo &propio = planes[defiende & 1];
		const PlanEquipo &rival = planes[(defiende + 1) & 1];
		double urg = _urgencia[defiende & 1];
		double umbral = pesos.def_intensidad_para_cierre - urg * pesos.marc_cierre;
		bool guardando = urg <= -pesos.marc_urgencia_para_guardar;
		bool permite = !guardando && (propio.presion_alta || intensidad >= umbral);
		if (propio.presion_alta && rival.contragolpe) {
			permite = false;
		}
		if (permite && !_presion_superada(m, defiende)) {
			double px, pz;
			if (_punto_de_cierre(m, defiende, cob_x, cob_z, px, pz)) {
				plan.hay_cierre = true;
				plan.cierre_x = px;
				plan.cierre_z = pz;
				double t_cierre = 1e18;
				for (int k : disponibles) {
					if (k == plan.presionante || k == plan.cobertura) {
						continue;
					}
					double t = _tiempo_de_llegada(m, k, px, pz);
					if (t < t_cierre) {
						t_cierre = t;
						plan.cierre = k;
					}
				}
			}
		}
	}
	plan.intensidad = intensidad;
}

int Cerebro::papel(int i) const {
	const Defensa &d = _defensa[fichas[size_t(i)].equipo & 1];
	if (d.presionante == i) {
		return PRESIONANTE;
	}
	if (d.cobertura == i) {
		return COBERTURA;
	}
	if (d.cierre == i) {
		return CIERRE;
	}
	return SIN_PAPEL;
}

// --- Grilla de apoyo (Simple Soccer) ---

// Cada casilla de la cancha se puntúa desde la pelota: si un pase le llega
// antes que cualquier rival, si se puede tirar desde ahí y si queda a la
// distancia justa. Las mejores entran como candidatas de apoyo.
void Cerebro::_planificar_grilla(const Mundo &m) {
	_mejores_casillas.clear();
	if (m.poseedor < 0 || m.detenido) {
		return;
	}
	int ataca = fichas[size_t(m.poseedor)].equipo;
	double s = signo(ataca);
	int columnas = std::max(1, pesos.grilla_columnas), filas = std::max(1, pesos.grilla_filas);
	_grilla.resize(size_t(columnas * filas));
	double bx = m.pelota_x, bz = m.pelota_z;
	double rapidez = std::max(pesos.grilla_rapidez_pase, 1.0);
	for (int c = 0; c < columnas; c++) {
		for (int f = 0; f < filas; f++) {
			Casilla &q = _grilla[size_t(c * filas + f)];
			q.x = -MEDIO_LARGO + (double(c) + 0.5) * LARGO / double(columnas);
			q.z = -MEDIO_ANCHO + (double(f) + 0.5) * ANCHO / double(filas);
			q.puntaje = -1e9;
			double largo = dist(bx, bz, q.x, q.z);
			if ((q.x - bx) * s < -5.0 || largo < 6.0) {
				continue;
			}
			if ((ataca == 0 && q.x > _linea_offside[0]) || (ataca == 1 && q.x < _linea_offside[1])) {
				continue;
			}
			// Pase seguro por tiempos: cada rival contra el punto de la línea
			// más cercano a él y contra la casilla misma.
			double ux = (q.x - bx) / largo, uz = (q.z - bz) / largo;
			double margen = 1e9;
			for (size_t o = 0; o < fichas.size(); o++) {
				if (fichas[o].equipo == ataca) {
					continue;
				}
				const JugadorVisto &r = m.jugadores[o];
				double v = std::max(r.vel_max, 0.5);
				double a = std::clamp((r.x - bx) * ux + (r.z - bz) * uz, 0.0, largo);
				double px = bx + ux * a, pz = bz + uz * a;
				double t_rival = std::max(0.0, dist(r.x, r.z, px, pz) - 0.45) / v;
				margen = std::min(margen, t_rival - a / rapidez);
			}
			double pase = clamp01((margen + 0.25) / 0.75);
			double tiro = factor_geometria(q.x, q.z, ataca);
			double justa = clamp01(1.0 - std::abs(largo - pesos.sp_dist_ideal) / std::max(pesos.sp_dist_tolerancia, 0.01));
			q.puntaje = pesos.grilla_peso_pase * pase + pesos.grilla_peso_tiro * tiro + pesos.grilla_peso_distancia * justa;
		}
	}
	int k = std::max(0, int(pesos.grilla_candidatos + 0.5));
	std::vector<Casilla> orden = _grilla;
	std::stable_sort(orden.begin(), orden.end(), [](const Casilla &a, const Casilla &b) {
		return a.puntaje > b.puntaje;
	});
	for (const Casilla &q : orden) {
		if (int(_mejores_casillas.size()) >= k || q.puntaje <= -1e8) {
			break;
		}
		_mejores_casillas.push_back(q);
	}
}

// --- Sin pelota ---

bool Cerebro::_ancla(const Mundo &m, int i, bool tiene, double &x, double &z) const {
	const FichaCerebro &f = fichas[size_t(i)];
	const PlanEquipo &plan = planes[f.equipo & 1];
	int equipo = f.equipo;
	double s = signo(equipo);
	int rol = std::clamp(f.rol, 0, ROLES - 1);
	double bx = f.base_x * s, bz = f.base_z;
	double px = m.pelota_x, pz = m.pelota_z;
	x = bx + px * ATRACCION_X[rol];
	z = bz + (pz - bz) * ATRACCION_Y[rol];
	if (!tiene && rol != ARQ) {
		x += -plan.retroceso * pesos.desplazamiento_por_estilo * s;
		x += _urgencia[equipo & 1] * pesos.marc_altura_bloque * s;
	}
	if (rol == ARQ) {
		x = equipo == 0 ? std::clamp(x, -ARQUERO_X_MIN, -ARQUERO_X_MAX) : std::clamp(x, ARQUERO_X_MAX, ARQUERO_X_MIN);
		z = std::clamp(z, -ARCO_MEDIO_ANCHO * 2.2, ARCO_MEDIO_ANCHO * 2.2);
		return true;
	}
	x = std::clamp(x, -LIMITE_X, LIMITE_X);
	if (!tiene && (rol == DFC || rol == LAT || rol == MC)) {
		x = equipo == 0 ? std::min(x, px + 1.0) : std::max(x, px - 1.0);
	}
	if (tiene && SUBIDA_POR_ROL[rol] > 0.0) {
		double avance = valor_posicion(px, pz, equipo);
		double cuanto = clamp01((avance - pesos.avance_para_acompanar)
				/ std::max(pesos.avance_acompanamiento_pleno - pesos.avance_para_acompanar, 0.01));
		double empuje = SUBIDA_POR_ROL[rol] * cuanto * plan.acompanamiento;
		double destino = px;
		if (rol == MCO) {
			double ax = MEDIO_LARGO * s;
			double borde = ax - signo_de(ax) * AREA_LARGO;
			destino = equipo == 0 ? std::max(px, borde) : std::min(px, borde);
		}
		x = lerp(x, destino, clamp01(empuje));
	}
	if (tiene && (rol == EXT || rol == DC)) {
		double avance = valor_posicion(px, pz, equipo);
		double contra = _transicion(m, equipo) * plan.transicion;
		if (avance < pesos.avance_para_jugar_en_el_hombro && contra < 0.5) {
			double apoyo = pesos.apoyo_del_delantero * (rol == DC ? pesos.apoyo_del_nueve : 1.0);
			x = std::clamp(lerp(x, px, apoyo), -LIMITE_X, LIMITE_X);
			z = std::clamp(lerp(z, pz, apoyo * 0.5), -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0);
			return true;
		}
		double intel = clamp01(f.bruto[AT_INTELIGENCIA] / 100.0);
		double offset = lerp(pesos.offside_margen_torpe, -1.5, intel) * f.margen_offside;
		double subida = std::max(contra, suave(pesos.avance_para_jugar_en_el_hombro, pesos.avance_para_centrar, avance));
		if (equipo == 0) {
			x = lerp(x, std::max(x, _linea_offside[0] + offset), subida);
		} else {
			x = lerp(x, std::min(x, _linea_offside[1] - offset), subida);
		}
	}
	if (!tiene) {
		_recortar_a_la_zona(i, x, z);
	}
	return false;
}

void Cerebro::_buscar_apoyo(const Mundo &m, int i, double base_x, double base_z, double &x, double &z) const {
	Apoyo &a = _apoyos[size_t(i)];
	if (m.segundos < a.hasta && a.poseedor == m.poseedor) {
		x = a.x;
		z = a.z;
		return;
	}
	const FichaCerebro &f = fichas[size_t(i)];
	const PlanEquipo &plan = planes[f.equipo & 1];
	int equipo = f.equipo;
	double s = signo(equipo);
	double lado = signo_de(f.base_z);
	if (lado == 0.0) {
		lado = i % 2 == 0 ? -1.0 : 1.0;
	}
	double transicion = _transicion(m, equipo) * plan.transicion;
	int rol = f.rol;
	double px = m.pelota_x, pz = m.pelota_z;
	double ox = base_x, oz = base_z;
	if ((rol == MC || rol == MCO) && transicion < 0.5) {
		double distancia = 10.0 + (1.0 - plan.asociacion) * 8.0;
		double escalon = rol == MC ? -distancia * 0.5 : distancia * 0.6;
		double t = plan.asociacion * 0.7;
		ox = lerp(base_x, px + s * escalon, t);
		oz = lerp(base_z, pz + lado * distancia, t);
	}
	if (rol == EXT || rol == LAT) {
		oz = lerp(oz, lado * (MEDIO_ANCHO - 7.0), plan.amplitud);
		if (rol == LAT && m.poseedor >= 0 && fichas[size_t(m.poseedor)].rol == EXT && pz * lado > 0.0
				&& presion_normalizada(m, px, pz, equipo) < 0.55) {
			ox = px + s * 10.0;
			oz = lado * (MEDIO_ANCHO - 4.0);
		}
	}
	if (transicion > 0.0 && (rol == EXT || rol == DC || rol == MCO)) {
		ox += s * (rol == MCO ? 9.0 : 14.0) * transicion;
		if (rol == EXT) {
			oz = lado * (MEDIO_ANCHO - 7.0);
		}
	}
	if (px * s > MEDIO_LARGO - AREA_LARGO - 5.0 && std::abs(pz) > 11.0) {
		if (rol == EXT && pz * lado < 0.0) {
			ox = std::max(ox * s, px * s + 4.0) * s;
			oz = lado * 7.0;
		} else if (rol == MCO) {
			ox = (MEDIO_LARGO - AREA_LARGO + 2.0) * s;
			oz = -signo_de(pz) * 4.0;
		}
	}
	if (_ultimo_de == i && (rol == MC || rol == MCO || rol == EXT)) {
		ox += s * 5.0 * plan.asociacion;
	}
	const double desplazamientos[4][2] = { { 0.0, 0.0 }, { 0.0, -6.0 }, { 0.0, 6.0 }, { -4.0 * s, 3.0 * lado } };
	double mejor = -1e18;
	double mx = ox, mz = oz;
	for (const auto &d : desplazamientos) {
		double cx = std::clamp(ox + d[0], -LIMITE_X, LIMITE_X);
		double cz = std::clamp(oz + d[1], -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0);
		double valor = 1.0 - presion_normalizada(m, cx, cz, equipo);
		valor += 0.5 * (1.0 - riesgo_linea(m, px, pz, cx, cz, equipo));
		valor -= hipot(d[0], d[1]) * 0.035;
		for (size_t c = 0; c < fichas.size(); c++) {
			if (fichas[c].equipo == equipo && int(c) != i) {
				valor -= std::max(0.0, 1.0 - dist(cx, cz, m.jugadores[c].x, m.jugadores[c].z) / 6.0);
			}
		}
		if (valor > mejor) {
			mejor = valor;
			mx = cx;
			mz = cz;
		}
	}
	a.x = mx;
	a.z = mz;
	a.hasta = m.segundos + PLAN_SEG;
	a.poseedor = m.poseedor;
	x = mx;
	z = mz;
}

void Cerebro::_objetivo_sin_pelota(const Mundo &m, int i, bool tiene, double &x, double &z) const {
	const FichaCerebro &f = fichas[size_t(i)];
	if (_ancla(m, i, tiene, x, z)) {
		return;
	}
	if (tiene && f.rol != DFC) {
		const PlanDesmarque &plan = _desmarques[size_t(i)];
		if (plan.vivo) {
			x = plan.x;
			z = plan.z;
		} else {
			_buscar_apoyo(m, i, x, z, x, z);
		}
	}
	if (!tiene && (f.rol == DFC || f.rol == LAT)) {
		x = lerp(x, _linea_defensiva[f.equipo & 1], clamp01(pesos.linea_mezcla));
	}
	double margen = pesos.offside_margen_torpe * (1.0 - clamp01(f.bruto[AT_INTELIGENCIA] / 100.0)) * f.margen_offside;
	if (f.equipo == 0) {
		x = std::min(x, _linea_offside[0] + margen);
	} else {
		x = std::max(x, _linea_offside[1] - margen);
	}
	z = std::clamp(z, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0);
}

Objetivo Cerebro::objetivo(const Mundo &m, int i) const {
	Objetivo o;
	const FichaCerebro &f = fichas[size_t(i)];
	bool tiene = m.equipo_con_pelota == f.equipo;
	if (tiene && _pared.vivo && _pared.corredor == i && m.segundos < _pared.hasta) {
		// El de la pared sale a buscar la devolución.
		o.x = _pared.x;
		o.z = _pared.z;
		o.frenar = false;
		o.desmarque = true;
		return o;
	}
	if (!tiene) {
		o.papel = papel(i);
		const Defensa &d = _defensa[f.equipo & 1];
		if (o.papel == COBERTURA && d.presionante >= 0) {
			_punto_de_cobertura(m, d.presionante, d.intensidad, o.x, o.z);
			return o;
		}
		if (o.papel == CIERRE && d.hay_cierre) {
			o.x = d.cierre_x;
			o.z = d.cierre_z;
			return o;
		}
		if (o.papel == PRESIONANTE) {
			o.x = m.pelota_x;
			o.z = m.pelota_z;
			return o;
		}
	}
	_objetivo_sin_pelota(m, i, tiene, o.x, o.z);
	o.desmarque = tiene && _desmarques[size_t(i)].vivo;
	return o;
}

// --- Desmarques ---

void Cerebro::_destino_legal(double x, double z, int equipo, double &lx, double &lz) const {
	lx = std::clamp(x, -LIMITE_X, LIMITE_X);
	lx = equipo == 0 ? std::min(lx, _linea_offside[0]) : std::max(lx, _linea_offside[1]);
	lz = std::clamp(z, -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0);
}

double Cerebro::_valor_de_desmarque(const Mundo &m, int i, int poseedor, double x, double z, int tipo) const {
	const JugadorVisto &e = m.jugadores[size_t(i)];
	const JugadorVisto &d = m.jugadores[size_t(poseedor)];
	int equipo = fichas[size_t(i)].equipo;
	double dist_pase = dist(d.x, d.z, x, z);
	double util = clamp01(1.0 - std::abs(dist_pase - pesos.sp_dist_ideal) / std::max(pesos.sp_dist_tolerancia, 0.01));
	double valor = pesos.sp_linea * (1.0 - riesgo_linea(m, d.x, d.z, x, z, equipo));
	valor += pesos.sp_espacio * (1.0 - presion_normalizada(m, x, z, equipo));
	valor += pesos.sp_progreso * (valor_posicion(x, z, equipo) - valor_posicion(e.x, e.z, equipo));
	valor += pesos.sp_distancia_util * util;
	valor -= pesos.sp_viaje * (dist(e.x, e.z, x, z) / 30.0);
	const double sesgos[4] = { pesos.sp_sesgo_apoyo, pesos.sp_sesgo_ruptura, pesos.sp_sesgo_arrastre, pesos.sp_sesgo_llegada };
	valor += sesgos[std::clamp(tipo, 0, 3)];
	static constexpr int RASGO_DE_TIPO[4] = { ASOCIACION, RUPTURA, DESCARGA, LLEGADA };
	valor += pesos.perfil_desmarque * _gusto(i, RASGO_DE_TIPO[std::clamp(tipo, 0, 3)]);
	return valor;
}

bool Cerebro::_diagonal_extremo(const Mundo &m, int i, int poseedor, Candidato &c) const {
	const FichaCerebro &f = fichas[size_t(i)];
	const JugadorVisto &e = m.jugadores[size_t(i)];
	if (f.rol != EXT || std::abs(e.z) < 14.0) {
		return false;
	}
	int equipo = f.equipo;
	double s = signo(equipo);
	double mejor = -1e18;
	bool hay = false;
	for (size_t l = 0; l < fichas.size(); l++) {
		const JugadorVisto &lat = m.jugadores[l];
		if (fichas[l].equipo == equipo || fichas[l].rol != LAT || lat.z * e.z <= 0.0) {
			continue;
		}
		for (size_t k = 0; k < fichas.size(); k++) {
			const JugadorVisto &cen = m.jugadores[k];
			if (fichas[k].equipo == equipo || fichas[k].rol != DFC) {
				continue;
			}
			if (std::abs(cen.z) >= std::abs(lat.z) || cen.z * e.z < 0.0) {
				continue;
			}
			double ancho = std::abs(lat.z - cen.z);
			if (ancho < 7.0 || ancho > 20.0 || std::abs(lat.x - cen.x) > 10.0) {
				continue;
			}
			double dx, dz;
			_destino_legal((lat.x + cen.x) * 0.5 + 2.0 * s, (lat.z + cen.z) * 0.5, equipo, dx, dz);
			if ((dx - e.x) * s <= 2.0 || std::abs(dz) > std::abs(e.z) - 3.0 || dist(e.x, e.z, dx, dz) > 22.0) {
				continue;
			}
			if (presion_normalizada(m, dx, dz, equipo) >= 0.4 || riesgo_linea(m, e.x, e.z, dx, dz, equipo) >= 0.55) {
				continue;
			}
			double valor = _valor_de_desmarque(m, i, poseedor, dx, dz, DES_RUPTURA) + 0.8;
			if (valor > mejor) {
				mejor = valor;
				c = Candidato();
				c.plan.tipo = DES_RUPTURA;
				c.plan.x = dx;
				c.plan.z = dz;
				c.plan.companero = poseedor;
				c.valor = valor;
				hay = true;
			}
		}
	}
	return hay;
}

void Cerebro::_candidatos_desmarque(const Mundo &m, int i, int poseedor, double ancla_x, double ancla_z,
		std::vector<Candidato> &salida) const {
	const FichaCerebro &f = fichas[size_t(i)];
	const JugadorVisto &e = m.jugadores[size_t(i)];
	const JugadorVisto &d = m.jugadores[size_t(poseedor)];
	int equipo = f.equipo;
	int rol = f.rol;
	double s = signo(equipo);
	double ax = MEDIO_LARGO * s;
	auto agregar = [&](int tipo, double x, double z, int companero, double extra) -> Candidato & {
		Candidato c;
		c.plan.tipo = tipo;
		c.plan.x = x;
		c.plan.z = z;
		c.plan.companero = companero;
		c.valor = _valor_de_desmarque(m, i, poseedor, x, z, tipo) + extra;
		salida.push_back(c);
		return salida.back();
	};
	// El 9 baja a recibir y deja el hueco a sus espaldas.
	if (rol == DC && (e.x - d.x) * s > 10.0 && dist(e.x, e.z, d.x, d.z) < 32.0) {
		double qx, qz, lx, lz;
		acercar(e.x, e.z, d.x, d.z, 7.0, qx, qz);
		_destino_legal(qx, qz, equipo, lx, lz);
		if (presion_normalizada(m, lx, lz, equipo) < 0.4 && riesgo_linea(m, d.x, d.z, lx, lz, equipo) < 0.55) {
			Candidato &c = agregar(DES_APOYO, lx, lz, poseedor, 0.65);
			c.plan.nueve_baja = true;
			c.plan.espacio_x = e.x;
			c.plan.espacio_z = e.z;
		}
	}
	// El que ocupa el hueco que dejó el 9.
	if (rol == EXT || rol == MCO || rol == MC) {
		for (size_t k = 0; k < _desmarques.size(); k++) {
			const PlanDesmarque &nueve = _desmarques[k];
			if (!nueve.vivo || !nueve.nueve_baja || nueve.hasta <= m.segundos || fichas[k].equipo != equipo) {
				continue;
			}
			if ((nueve.espacio_x - m.jugadores[k].x) * s < 3.0) {
				continue;
			}
			double lx, lz;
			_destino_legal(nueve.espacio_x, nueve.espacio_z, equipo, lx, lz);
			if ((lx - e.x) * s <= 2.0 || dist(e.x, e.z, lx, lz) > 22.0 || presion_normalizada(m, lx, lz, equipo) >= 0.4) {
				continue;
			}
			Candidato &c = agregar(DES_RUPTURA, lx, lz, int(k), 0.8);
			c.plan.relevo_nueve = true;
		}
	}
	Candidato diagonal;
	if (_diagonal_extremo(m, i, poseedor, diagonal)) {
		salida.push_back(diagonal);
	}
	// El lateral dobla por fuera al extremo que atrae marca.
	if (rol == LAT && fichas[size_t(poseedor)].rol == EXT && e.z * d.z > 0.0 && std::abs(d.z) >= 12.0
			&& std::abs(d.z) <= MEDIO_ANCHO - 7.0 && (e.x - d.x) * s <= 2.0 && dist(e.x, e.z, d.x, d.z) <= 24.0) {
		bool atrae = false;
		for (size_t o = 0; o < fichas.size(); o++) {
			if (fichas[o].equipo != equipo && fichas[o].rol != ARQ
					&& dist(m.jugadores[o].x, m.jugadores[o].z, d.x, d.z) < 8.0) {
				atrae = true;
				break;
			}
		}
		double lx, lz;
		_destino_legal(d.x + 8.0 * s, d.z + 6.0 * signo_de(d.z), equipo, lx, lz);
		if (atrae && (lx - d.x) * s > 3.0 && presion_normalizada(m, lx, lz, equipo) < 0.4) {
			Candidato &c = agregar(DES_RUPTURA, lx, lz, poseedor, 0.85);
			c.plan.doblamiento = true;
		}
	}
	// Abrirse del lado libre para el cambio de frente.
	if ((rol == EXT || rol == LAT) && ancla_z * d.z < 0.0) {
		double lx, lz;
		_destino_legal(ancla_x, signo_de(ancla_z) * 23.0, equipo, lx, lz);
		double ventaja = _ventaja_cambio_frente(m, d.x, d.z, lx, lz, equipo);
		if (ventaja > 0.0 && dist(e.x, e.z, lx, lz) <= 18.0) {
			agregar(DES_APOYO, lx, lz, poseedor, ventaja);
		}
	}
	// Llegar al punto del pase atrás cuando la pelota está en la banda, cerca del fondo.
	if (std::abs(d.z) >= pesos.banda_para_centrar && std::abs(ax - d.x) < ULTIMO_TRAMO_BANDA
			&& (rol == MC || rol == MCO || rol == DC || rol == EXT)) {
		for (double lateral : { -6.0, 0.0, 6.0 }) {
			double profundidad = std::clamp(std::abs(ax - d.x) + 4.0, 11.0, 16.0);
			if (rol == DC) {
				profundidad = PROFUNDIDAD_DEL_NUEVE_AL_CENTRO;
			}
			double lx, lz;
			_destino_legal(ax - s * profundidad, lateral, equipo, lx, lz);
			if (dist(e.x, e.z, lx, lz) > 22.0 || (lx - e.x) * s < -2.0) {
				continue;
			}
			if (presion_normalizada(m, lx, lz, equipo) > 0.55) {
				continue;
			}
			Candidato &c = agregar(DES_LLEGADA, lx, lz, poseedor, 0.8);
			c.plan.pase_atras = true;
		}
	}
	// Apoyo alrededor del ancla.
	double lado_apoyo = signo_de(ancla_z);
	if (lado_apoyo == 0.0) {
		lado_apoyo = 1.0;
	}
	const double desplazamientos[5][2] = { { 0.0, 0.0 }, { 0.0, -6.0 }, { 0.0, 6.0 }, { -4.0 * s, 3.0 * lado_apoyo },
		{ 4.0 * s, 0.0 } };
	for (const auto &dd : desplazamientos) {
		double lx, lz;
		_destino_legal(ancla_x + dd[0], ancla_z + dd[1], equipo, lx, lz);
		agregar(DES_APOYO, lx, lz, poseedor, 0.0);
	}
	// Nuevo: las mejores casillas de la grilla de apoyo, si le quedan cerca.
	for (const Casilla &q : _mejores_casillas) {
		if (dist(e.x, e.z, q.x, q.z) > 25.0) {
			continue;
		}
		double lx, lz;
		_destino_legal(q.x, q.z, equipo, lx, lz);
		agregar(DES_APOYO, lx, lz, poseedor, pesos.grilla_bono * q.puntaje).plan.de_grilla = true;
	}
	bool rompe = rol == MCO || rol == EXT || rol == DC;
	if (rompe) {
		double gx = ax - e.x, gz = -e.z;
		if (hipot(gx, gz) < 0.5) {
			gx = s;
			gz = 0.0;
		}
		normalizar(gx, gz);
		double t = clamp01((e.vel_max - pesos.vel_min) / std::max(pesos.vel_max - pesos.vel_min, 0.01));
		double largo = pesos.hueco_min + (pesos.hueco_max - pesos.hueco_min) * t;
		for (double giro : { -0.5, 0.5 }) {
			double rx, rz, lx, lz;
			rotar(gx, gz, giro, rx, rz);
			_destino_legal(e.x + rx * largo, e.z + rz * largo, equipo, lx, lz);
			agregar(DES_RUPTURA, lx, lz, poseedor, 0.0);
		}
		// Arrastre: se lleva a su marca y le abre el carril al poseedor.
		int marcador = -1;
		double d_marcador = 6.0;
		for (size_t o = 0; o < fichas.size(); o++) {
			if (fichas[o].equipo == equipo) {
				continue;
			}
			double dd = dist(e.x, e.z, m.jugadores[o].x, m.jugadores[o].z);
			if (dd < d_marcador) {
				d_marcador = dd;
				marcador = int(o);
			}
		}
		if (marcador != -1) {
			double lado = signo_de(e.z);
			if (lado == 0.0) {
				lado = 1.0;
			}
			double lx, lz;
			_destino_legal(e.x + s * 3.0, e.z + lado * 10.0, equipo, lx, lz);
			double despeja = dist_a_segmento(lx, lz, d.x, d.z, ax, 0.0) - dist_a_segmento(e.x, e.z, d.x, d.z, ax, 0.0);
			Candidato c;
			c.plan.tipo = DES_ARRASTRE;
			c.plan.x = lx;
			c.plan.z = lz;
			c.plan.companero = marcador;
			c.valor = _valor_de_desmarque(m, i, poseedor, lx, lz, DES_ARRASTRE) + clamp01(despeja / 10.0) * 0.8;
			salida.push_back(c);
		}
	}
	// Llegar desde atrás al borde del área cuando alguien fija la línea.
	if ((rol == MC || rol == MCO || rol == LAT) && (e.x - d.x) * s < 2.0) {
		int fijador = -1;
		double borde_linea = _linea_offside[equipo & 1];
		for (size_t c = 0; c < fichas.size(); c++) {
			if (fichas[c].equipo != equipo || int(c) == i || fichas[c].rol == ARQ) {
				continue;
			}
			if (std::abs(m.jugadores[c].x - borde_linea) <= 4.0) {
				fijador = int(c);
				break;
			}
		}
		if (fijador != -1) {
			double borde_area = (MEDIO_LARGO - AREA_LARGO) * s;
			for (double carril : { -10.0, 0.0, 10.0 }) {
				if (dist(e.x, e.z, borde_area, carril) > 30.0) {
					continue;
				}
				double lx, lz;
				_destino_legal(borde_area, carril, equipo, lx, lz);
				agregar(DES_LLEGADA, lx, lz, fijador, 0.0);
			}
		}
	}
}

bool Cerebro::_desmarque_sigue_vivo(const Mundo &m, int i) {
	PlanDesmarque &plan = _desmarques[size_t(i)];
	if (m.segundos >= plan.hasta) {
		return false;
	}
	double x, z;
	if (_ancla(m, i, true, x, z)) {
		return false;
	}
	double lx, lz;
	_destino_legal(plan.x, plan.z, fichas[size_t(i)].equipo, lx, lz);
	if (presion_normalizada(m, lx, lz, fichas[size_t(i)].equipo) > PRESION_DESTINO_INVIABLE) {
		return false;
	}
	plan.x = lx;
	plan.z = lz;
	return true;
}

void Cerebro::_anotar_desmarque(const Mundo &m, int i, const PlanDesmarque &p) {
	const JugadorVisto &e = m.jugadores[size_t(i)];
	double viaje = dist(e.x, e.z, p.x, p.z) / std::max(e.vel_max, 0.01);
	double dura = std::clamp(mate::redondear(viaje / TICK_ESPACIAL_SEG) * TICK_ESPACIAL_SEG, DESMARQUE_MIN_SEG,
			DESMARQUE_MAX_SEG);
	if (p.nueve_baja || p.pase_atras) {
		dura = std::min(dura + DESMARQUE_MIN_SEG, DESMARQUE_MAX_SEG);
	}
	PlanDesmarque &plan = _desmarques[size_t(i)];
	plan = p;
	plan.vivo = true;
	plan.hasta = m.segundos + dura;
	cuenta.desmarques[std::clamp(p.tipo, 0, 3)]++;
	if (p.de_grilla) {
		cuenta.apoyos_de_grilla++;
	}
}

int Cerebro::_cupo_de_rupturas(int equipo) const {
	double u = _urgencia[equipo & 1];
	if (u >= pesos.marc_urgencia_para_romper) {
		return MAX_RUPTURAS + 1;
	}
	if (u <= -pesos.marc_urgencia_para_guardar) {
		return std::max(1, MAX_RUPTURAS - 1);
	}
	return MAX_RUPTURAS;
}

void Cerebro::_planificar_desmarques(const Mundo &m, int ataca) {
	if (m.detenido) {
		for (PlanDesmarque &p : _desmarques) {
			p.vivo = false;
		}
		return;
	}
	if (_desmarques_equipo != ataca) {
		for (PlanDesmarque &p : _desmarques) {
			p.vivo = false;
		}
		_desmarques_hasta = -1.0;
	}
	_desmarques_equipo = ataca;
	for (size_t k = 0; k < _desmarques.size(); k++) {
		if (_desmarques[k].vivo && !_desmarque_sigue_vivo(m, int(k))) {
			_desmarques[k].vivo = false;
		}
	}
	if (m.segundos < _desmarques_hasta) {
		return;
	}
	_desmarques_hasta = m.segundos + DESMARQUE_MIN_SEG;
	int poseedor = m.poseedor;
	if (poseedor < 0 || fichas[size_t(poseedor)].equipo != ataca) {
		return;
	}
	int rupturas_vivas = 0;
	bool hay_apoyo = false;
	std::vector<double> ocupados;
	for (const PlanDesmarque &p : _desmarques) {
		if (!p.vivo) {
			continue;
		}
		ocupados.push_back(p.x);
		ocupados.push_back(p.z);
		if (p.tipo == DES_RUPTURA || p.tipo == DES_LLEGADA) {
			rupturas_vivas++;
		} else if (p.tipo == DES_APOYO) {
			hay_apoyo = true;
		}
	}
	struct Pendiente {
		int clave;
		std::vector<Candidato> candidatos;
	};
	std::vector<Pendiente> pendientes;
	for (size_t k = 0; k < fichas.size(); k++) {
		const FichaCerebro &f = fichas[k];
		if (_desmarques[k].vivo || f.equipo != ataca || int(k) == poseedor || f.rol == ARQ || f.rol == DFC) {
			continue;
		}
		double x, z;
		if (_ancla(m, int(k), true, x, z)) {
			continue;
		}
		Pendiente p;
		p.clave = int(k);
		_candidatos_desmarque(m, int(k), poseedor, x, z, p.candidatos);
		if (!p.candidatos.empty()) {
			pendientes.push_back(std::move(p));
		}
	}
	// Siempre hay un apoyo seguro: el mejor candidato de apoyo va primero.
	if (!hay_apoyo) {
		int mejor_p = -1;
		size_t mejor_c = 0;
		for (size_t a = 0; a < pendientes.size(); a++) {
			for (size_t c = 0; c < pendientes[a].candidatos.size(); c++) {
				const Candidato &cand = pendientes[a].candidatos[c];
				if (cand.plan.tipo != DES_APOYO) {
					continue;
				}
				if (mejor_p < 0 || cand.valor > pendientes[size_t(mejor_p)].candidatos[mejor_c].valor) {
					mejor_p = int(a);
					mejor_c = c;
				}
			}
		}
		if (mejor_p >= 0) {
			const Candidato &cand = pendientes[size_t(mejor_p)].candidatos[mejor_c];
			_anotar_desmarque(m, pendientes[size_t(mejor_p)].clave, cand.plan);
			ocupados.push_back(cand.plan.x);
			ocupados.push_back(cand.plan.z);
			pendientes.erase(pendientes.begin() + mejor_p);
		}
	}
	int cupo = _cupo_de_rupturas(ataca);
	while (!pendientes.empty()) {
		int elegido = -1;
		size_t mejor_c = 0;
		double mejor_valor = -1e18;
		for (size_t a = 0; a < pendientes.size(); a++) {
			for (size_t c = 0; c < pendientes[a].candidatos.size(); c++) {
				const Candidato &cand = pendientes[a].candidatos[c];
				bool corrida = cand.plan.tipo == DES_RUPTURA || cand.plan.tipo == DES_LLEGADA;
				if (corrida && rupturas_vivas >= cupo) {
					continue;
				}
				double valor = cand.valor;
				for (size_t o = 0; o + 1 < ocupados.size(); o += 2) {
					double d = dist(ocupados[o], ocupados[o + 1], cand.plan.x, cand.plan.z);
					if (d < SEPARACION_DESMARQUE) {
						valor -= pesos.sp_conflicto * (1.0 - d / SEPARACION_DESMARQUE);
					}
				}
				if (valor > mejor_valor) {
					mejor_valor = valor;
					mejor_c = c;
					elegido = int(a);
				}
			}
		}
		if (elegido == -1 || mejor_valor < pesos.sp_minimo) {
			break;
		}
		const Candidato &cand = pendientes[size_t(elegido)].candidatos[mejor_c];
		_anotar_desmarque(m, pendientes[size_t(elegido)].clave, cand.plan);
		ocupados.push_back(cand.plan.x);
		ocupados.push_back(cand.plan.z);
		if (cand.plan.tipo == DES_RUPTURA || cand.plan.tipo == DES_LLEGADA) {
			rupturas_vivas++;
		}
		pendientes.erase(pendientes.begin() + elegido);
	}
}

// --- Remate (etapa 5) ---

bool Cerebro::alcanza_para_tirar(int i, double x, double z) const {
	int equipo = fichas[size_t(i)].equipo;
	double ax = MEDIO_LARGO * signo(equipo);
	double rango = _por_atributo(i, AT_TIRO, pesos.rango_tiro_malo, pesos.rango_tiro_bueno, pesos.mezcla_fisica_rango_tiro);
	double f_dist = clamp01(1.0 - (dist(x, z, ax, 0.0) - 5.0) / std::max(rango, 1.0));
	return f_dist * factor_angulo(x, z, equipo) > pesos.geometria_minima_tiro;
}

Decision Cerebro::elegir_remate(const Mundo &m, int i, bool solo_cabeza, Azar &azar) const {
	(void)m;
	int equipo = fichas[size_t(i)].equipo;
	Decision d;
	d.tipo = DEC_REMATE;
	d.tiene_punto = true;
	d.x = MEDIO_LARGO * signo(equipo);
	d.z = 0.0;
	d.alto = 1.0;
	d.golpe = solo_cabeza ? REMATE_CABEZA : REMATE_COLOCADO;
	if (planeador == nullptr) {
		return d;
	}
	// Los puntos del arco que mira: pegado al palo (media pelota más un
	// margen), a un metro y medio del palo y al medio; raso, a media altura y
	// arriba (medio metro abajo del travesaño, 2,44 m).
	const double laterales[5] = { -(ARCO_MEDIO_ANCHO - 0.45), -(ARCO_MEDIO_ANCHO - 1.35), 0.0, ARCO_MEDIO_ANCHO - 1.35,
		ARCO_MEDIO_ANCHO - 0.45 };
	const double altos[3] = { 0.2, 1.0, 1.9 };
	const int de_pie[4] = { REMATE_COLOCADO, REMATE_FUERTE, REMATE_EFECTO, REMATE_GLOBO };
	const int de_cabeza[1] = { REMATE_CABEZA };
	const int *golpes = solo_cabeza ? de_cabeza : de_pie;
	int cuantos_golpes = solo_cabeza ? 1 : 4;
	struct Candidato {
		int golpe;
		double alto, lateral, valor;
	};
	std::vector<Candidato> candidatos;
	double mejor = -1.0;
	for (int g = 0; g < cuantos_golpes; g++) {
		for (double alto : altos) {
			for (double lateral : laterales) {
				double v = planeador->valor_remate(i, golpes[g], alto, lateral);
				if (v < 0.0) {
					continue;
				}
				candidatos.push_back({ golpes[g], alto, lateral, v });
				mejor = std::max(mejor, v);
			}
		}
	}
	if (candidatos.empty()) {
		return d;
	}
	// Softmax con temperatura baja: casi siempre el mejor punto, a veces uno
	// parecido (los delanteros no rematan siempre al mismo rincón).
	double temp = std::max(pesos.remate_temperatura, 1e-3);
	double suma = 0.0;
	std::vector<double> pesos_exp(candidatos.size());
	for (size_t k = 0; k < candidatos.size(); k++) {
		pesos_exp[k] = mate::exponencial((candidatos[k].valor - mejor) / temp);
		suma += pesos_exp[k];
	}
	double tirada = azar.uno() * suma;
	size_t elegido = candidatos.size() - 1;
	for (size_t k = 0; k < candidatos.size(); k++) {
		tirada -= pesos_exp[k];
		if (tirada < 0.0) {
			elegido = k;
			break;
		}
	}
	const Candidato &c = candidatos[elegido];
	d.golpe = c.golpe;
	d.alto = c.alto;
	// El lateral va del lado del arco que mira el que ataca: z en la cancha.
	d.z = c.lateral;
	d.utilidad = c.valor;
	return d;
}

