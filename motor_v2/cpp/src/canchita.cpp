#include "canchita.h"
#include "matematica_fija.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

namespace {
// Choque entre cuerpos: el mismo radio que el banco de la etapa 0
// (mundo_v2_nativo.cpp). Todos pesan lo mismo en el banco.
constexpr double RADIO_CUERPO = 0.35;
// Qué tan lejos del pie cuenta como "llegar" al planear (el alcance del
// punto de contacto de Control_Corriendo y Patear_Corriendo, 0,24 y 0,40 m).
constexpr double ALCANCE_PLAN_M = 0.35;
// El defensor llega con la pierna estirada (Barrida y Bloquear alcanzan
// 0,41 a 0,45 m): el que planea un pase lo cuenta.
constexpr double ALCANCE_RIVAL_M = 0.45;
// El que no está disputado no sale a recibir a fondo: así no se come al que
// se la pasó ni espera parado (ESPERA). Con 0,55 llegaba tarde a los pases
// fuertes (9 m/s) que se desviaban y se le iban afuera.
constexpr double FACTOR_RECIBIR = 0.8;
// Disputada: el rival llega hasta esto después que él.
constexpr double DISPUTA_SEG = 0.8;
// Pase al espacio: a lo sumo esto al costado del receptor.
constexpr double TANGENTE_MAX_M = 2.5;
// El defensor va a la pelota controlada solo si llega esto antes que el que
// la tiene; si no, contiene a CONTENER_M. Tirándose siempre, en el partidito
// había un quite cada 1,7 s.
constexpr double GANA_CARRERA_SEG = 0.1;
constexpr double CONTENER_M = 1.5;
// El que acaba de patear no vuelve a ir a la pelota enseguida.
constexpr int DESCANSO_PATEADOR = 30;
// Rondo: corte o pelota afuera, y se vuelve a empezar 1 s después; la
// pelota sale 2 m afuera del cuadrado (los de afuera están sobre la línea).
constexpr int RONDO_ESPERA_CORTE = 60;
constexpr double RONDO_AFUERA_M = 2.0;
// Reinicio: 1,5 s en que los rivales no la pueden tocar y se alejan 5 m.
constexpr int REINICIO_PASOS = 90;
constexpr double REINICIO_DISTANCIA_M = 5.0;
// Partidito: anclas de los cinco para el que ataca hacia +x (el otro las
// espeja): dos atrás, uno al medio y dos adelante abiertos.
constexpr double ANCLAS[5][2] = { { -12.0, -7.0 }, { -12.0, 7.0 }, { -2.0, 0.0 }, { 8.0, -8.0 }, { 8.0, 8.0 } };

double hipot(double x, double z) {
	return std::sqrt(x * x + z * z);
}

double rumbo_de(double dx, double dz) {
	return mate::arcotangente2(dx, dz);
}
} // namespace

void Canchita::agregar(int equipo, const Cuerpo &fisico, double pases, double control) {
	JugadorCanchita j;
	j.cuerpo = fisico;
	j.equipo = equipo;
	j.pases = pases;
	j.control = control;
	jugadores.push_back(j);
}

double Canchita::_medio_x() const {
	// El modo PRUEBA usa la cancha del partidito.
	return modo == RONDO ? RONDO_LADO * 0.5 : PARTIDITO_LARGO * 0.5;
}

double Canchita::_medio_z() const {
	return modo == RONDO ? RONDO_LADO * 0.5 : PARTIDITO_ANCHO * 0.5;
}

bool Canchita::_adentro(double x, double z, double margen) const {
	return std::abs(x) <= _medio_x() + margen && std::abs(z) <= _medio_z() + margen;
}

double Canchita::_ataca(int equipo) const {
	if (modo == RONDO) {
		return 0.0;
	}
	return equipo == 0 ? 1.0 : -1.0;
}

int Canchita::_indice_tray(int64_t paso_) const {
	return int(paso_ - _tray_paso - 1);
}

V3 Canchita::_bola_en(int64_t paso_) const {
	int k = _indice_tray(paso_);
	if (k < 0 || trayectoria.pos.empty()) {
		return pelota.pos;
	}
	return trayectoria.pos[size_t(std::min(k, int(trayectoria.pos.size()) - 1))];
}

void Canchita::empezar(int modo_, int64_t semilla) {
	modo = modo_;
	_azar.sembrar(semilla);
	paso = 0;
	cuenta = ContadoresCanchita();
	pelota = Pelota();
	pelota.configurar(param_pelota);
	_perfiles.configurar(param_pelota, param_toque.elevacion_globo, HORIZONTE);
	_reaccion_pasos = std::max(0, int(param_toque.reaccion_seg / PASO_SEG + 0.5));
	size_t n = jugadores.size();
	_k_llega.assign(n, -1);
	_t_llega.assign(n, 1e9);
	_perseguidor[0] = _perseguidor[1] = -1;
	_pase_activo = false;
	_pateador = _receptor = -1;
	_reinicio_en = _reinicio_hasta = -1;
	int por_equipo[2] = { 0, 0 };
	const double h = RONDO_LADO * 0.5;
	for (JugadorCanchita &j : jugadores) {
		j.puesto = por_equipo[j.equipo & 1]++;
		double x = 0.0, z = 0.0;
		if (modo == RONDO) {
			if (j.equipo == 0) {
				const double lados[4][2] = { { 0.0, -h }, { h, 0.0 }, { 0.0, h }, { -h, 0.0 } };
				x = lados[j.puesto % 4][0];
				z = lados[j.puesto % 4][1];
			} else {
				x = j.puesto == 0 ? -1.5 : 1.5;
			}
		} else {
			const double *a = ANCLAS[j.puesto % 5];
			// Cada uno en su mitad, a la mitad de su ancla.
			x = (a[0] * 0.5 - 8.0) * (j.equipo == 0 ? 1.0 : -1.0);
			z = a[1];
		}
		Cuerpo &c = j.cuerpo;
		c.x = c.previa_x = x;
		c.z = c.previa_z = z;
		c.vx = c.vz = 0.0;
		c.rumbo = (x == 0.0 && z == 0.0) ? 0.0 : rumbo_de(-x, -z);
		c.tiene_objetivo = false;
		c.clip = -1;
		c.fase = SIN_ACCION;
		j.persigue = j.toque_pendiente = false;
		j.toque = TOQUE_NADA;
		j.inmune_hasta = 0;
		j.pateo_en = -1000;
		j.marca = -1;
		j.quieto_seg = 0.0;
		j.rapidez_previa = 0.0;
		j.pensar_ya = true;
	}
	_reiniciar(0, 0.0, modo == RONDO ? -h : 0.0);
	cuenta.reinicios = 0;
}

void Canchita::poner_jugador(int i, double x, double z, double rumbo) {
	if (i < 0 || i >= int(jugadores.size())) {
		return;
	}
	JugadorCanchita &j = jugadores[size_t(i)];
	Cuerpo &c = j.cuerpo;
	c.x = c.previa_x = j.casa_x = x;
	c.z = c.previa_z = j.casa_z = z;
	c.vx = c.vz = 0.0;
	c.rumbo = rumbo;
	c.tiene_objetivo = false;
}

void Canchita::lanzar(V3 p, V3 v, V3 giro, int equipo) {
	pelota.poner(p, v, giro);
	equipo_con_pelota = equipo;
	poseedor = ultimo_toque = -1;
	ultimo_tipo = TOQUE_NADA;
	_pase_activo = false;
	_receptor = -1;
	_reinicio_en = _reinicio_hasta = -1;
	for (JugadorCanchita &j : jugadores) {
		j.toque_pendiente = false;
		j.persigue = false;
		j.pensar_ya = true;
	}
	trayectoria.predecir(pelota, HORIZONTE);
	_tray_paso = paso;
	_visto_paso = paso;
	for (size_t i = 0; i < jugadores.size(); i++) {
		_alcance(int(i), 1.0, _k_llega[i], _t_llega[i]);
	}
	_analizar();
}

void Canchita::avanzar() {
	paso++;
	_cambio = false;
	_pensar();
	for (JugadorCanchita &j : jugadores) {
		j.rapidez_previa = j.cuerpo.rapidez();
		j.cuerpo.paso(param_cuerpo, clips, PASO_SEG);
	}
	_separar_cuerpos();
	pelota.avanzar();
	V3 fisica = pelota.vel;
	bool tocada = _resolver_toques();
	tocada = _rebotes() || tocada;
	// Detector de la etapa 3: la pelota solo cambia por la física o por un
	// toque. Nada más la puede corregir.
	if (!tocada && (pelota.vel.x != fisica.x || pelota.vel.y != fisica.y || pelota.vel.z != fisica.z)) {
		cuenta.correcciones++;
	}
	_reglas();
	if (_cambio) {
		trayectoria.predecir(pelota, HORIZONTE);
		_tray_paso = paso;
	}
	_medir();
}

// --- Cerebro sencillo ---

void Canchita::_pensar() {
	bool vio = paso >= _visto_paso;
	if (paso % PASOS_POR_TURNO == 0) {
		_analizar();
	}
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		bool turno = (paso + int64_t(i)) % PASOS_POR_TURNO == 0;
		if (j.pensar_ya || (turno && (vio || int(i) == ultimo_toque))) {
			j.pensar_ya = false;
			_pensar_jugador(int(i));
		}
	}
	for (size_t i = 0; i < jugadores.size(); i++) {
		_gatillo(int(i));
	}
}

// Cuándo llega cada uno a la pelota (a fondo) y quién va de cada equipo. El
// que todavía no reaccionó a la pelota nueva sigue con lo que sabía.
void Canchita::_analizar() {
	bool vio = paso >= _visto_paso;
	for (size_t i = 0; i < jugadores.size(); i++) {
		if (vio || int(i) == ultimo_toque) {
			_alcance(int(i), 1.0, _k_llega[i], _t_llega[i]);
		}
	}
	bool reinicio = paso < _reinicio_hasta;
	for (int e = 0; e < 2; e++) {
		int mejor = -1;
		for (size_t i = 0; i < jugadores.size(); i++) {
			const JugadorCanchita &j = jugadores[i];
			if (j.equipo != e || paso - j.pateo_en < DESCANSO_PATEADOR) {
				continue;
			}
			if (mejor < 0 || _t_llega[i] < _t_llega[size_t(mejor)]) {
				mejor = int(i);
			}
		}
		if (reinicio && e != equipo_con_pelota) {
			mejor = -1;
		}
		_perseguidor[e] = mejor;
	}
	// El que la tiene controlada va él. Sin esto, con el análisis de antes
	// de su control, se iba a su ancla y dejaba la pelota (en el partidito,
	// un quite cada 2 s).
	if (poseedor >= 0) {
		_perseguidor[jugadores[size_t(poseedor)].equipo] = poseedor;
	}
	// El pase va a uno: va él, salvo que otro compañero llegue bastante antes.
	int p = equipo_con_pelota;
	if (_pase_activo && _receptor >= 0 && jugadores[size_t(_receptor)].equipo == p && _perseguidor[p] >= 0
			&& _perseguidor[p] != _receptor
			&& _t_llega[size_t(_receptor)] < _t_llega[size_t(_perseguidor[p])] + 0.5) {
		_perseguidor[p] = _receptor;
	}
	// Rondo: después de un corte nadie va a la pelota hasta el reinicio.
	if (modo == RONDO && _reinicio_en >= 0) {
		_perseguidor[0] = _perseguidor[1] = -1;
	}
}

// El primer punto de la trayectoria al que llega a tiempo corriendo a
// `factor` de su punta, y en cuántos segundos. La pelota más alta que la
// cabeza no cuenta. Si no llega a ninguno, el último.
void Canchita::_alcance(int i, double factor, int &k, double &t) const {
	const Cuerpo &c = jugadores[size_t(i)].cuerpo;
	int n = int(trayectoria.pos.size());
	if (n == 0) {
		k = -1;
		t = tiempo_de_llegada(c, pelota.pos.x, pelota.pos.z, ALCANCE_PLAN_M, factor);
		return;
	}
	int desde = std::max(0, _indice_tray(paso + 1));
	// Afuera ya no se juega: el que va la tiene que alcanzar antes. Sin esto
	// el receptor del rondo trotaba a buscarla afuera del cuadrado (15% de
	// los pases se iban).
	double adentro = modo == RONDO ? RONDO_AFUERA_M - 0.5 : -0.2;
	for (int q = desde; q < n; q++) {
		const V3 &p = trayectoria.pos[size_t(q)];
		if (!_adentro(p.x, p.z, adentro)) {
			n = std::max(q, desde + 1);
			break;
		}
		if (p.y > param_toque.cabeza_hasta) {
			continue;
		}
		double tq = double(_tray_paso + q + 1 - paso) * PASO_SEG;
		if (tiempo_de_llegada(c, p.x, p.z, ALCANCE_PLAN_M, factor) <= tq) {
			k = q;
			t = tq;
			return;
		}
	}
	k = n - 1;
	const V3 &ultima = trayectoria.pos[size_t(k)];
	t = std::max(double(_tray_paso + k + 1 - paso) * PASO_SEG,
			tiempo_de_llegada(c, ultima.x, ultima.z, ALCANCE_PLAN_M, factor));
}

void Canchita::_pensar_jugador(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	// Con el gesto ya empezado no cambia de idea.
	if (j.toque_pendiente && j.cuerpo.clip >= 0) {
		return;
	}
	bool contiene = j.equipo != equipo_con_pelota && poseedor >= 0
			&& jugadores[size_t(poseedor)].equipo == equipo_con_pelota
			&& _t_llega[size_t(i)] > _t_llega[size_t(poseedor)] - GANA_CARRERA_SEG;
	if (_perseguidor[j.equipo] == i && contiene) {
		// La tiene controlada otro y no le gana de mano: se para delante y
		// espera el error (o el pase), no se tira a ciegas.
		j.persigue = false;
		j.toque = TOQUE_NADA;
		_contener(i);
	} else if (modo == PRUEBA && i == poseedor) {
		// En la prueba el que la controla no sigue jugando.
		j.persigue = false;
		j.toque = TOQUE_NADA;
		_ubicar(i);
	} else if (_perseguidor[j.equipo] == i || i == poseedor) {
		_plan_tocar(i);
	} else {
		j.persigue = false;
		j.toque = TOQUE_NADA;
		_ubicar(i);
	}
}

// Va al punto de encuentro con la pelota y llega a tiempo, sin esperarla.
void Canchita::_plan_tocar(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	Cuerpo &c = j.cuerpo;
	bool ataca = j.equipo == equipo_con_pelota;
	bool poseedor_ = ultimo_toque == i && (ultimo_tipo == TOQUE_CONTROL || ultimo_tipo == TOQUE_CONDUCE);
	int rival = _perseguidor[1 - j.equipo];
	double t_rival = rival >= 0 ? _t_llega[size_t(rival)] : 1e9;
	bool disputada = !ataca || t_rival < _t_llega[size_t(i)] + DISPUTA_SEG;
	double factor = disputada ? 1.0 : (poseedor_ ? param_toque.conduccion_factor : FACTOR_RECIBIR);
	int k;
	double t;
	_alcance(i, factor, k, t);
	if (factor < 1.0 && k == int(trayectoria.pos.size()) - 1) {
		_alcance(i, 1.0, k, t);
	}
	V3 p = k >= 0 ? trayectoria.pos[size_t(k)] : pelota.pos;
	V3 vp = k >= 0 ? trayectoria.vel[size_t(k)] : pelota.vel;

	j.toque = TOQUE_CONTROL;
	if (poseedor_ && ataca && p.y <= param_toque.pie_hasta) {
		_decidir(i, p, t);
	} else if (ataca && _pase_activo && p.y <= param_toque.pie_hasta
			&& _rival_mas_cerca(i, p.x, p.z) < param_toque.presion_m + 1.0) {
		// De primera: con un rival encima no hay tiempo de parar la pelota.
		// Solo si hay un pase que le gana a todos.
		Pase pase = _planear_pase(i, p, t);
		if (pase.hay && pase.margen > 0.0 && !pase.globo) {
			j.toque = TOQUE_PASE;
			j.meta_x = pase.x;
			j.meta_z = pase.z;
			j.receptor = pase.receptor;
			j.globo = false;
		}
	}
	if (j.toque == TOQUE_CONTROL) {
		_orientar(i, p);
	}
	int clip = _clip_para(j, p.y);
	if (clip < 0) {
		// Pasa por arriba de la cabeza: va a donde cae.
		c.ir_a(p.x, p.z, 1.0, true);
		j.persigue = false;
		return;
	}
	// Hacia dónde mira al tocarla. El que patea va derecho a la pelota y la
	// manda adonde sea (de costado es más impreciso, ver _tocar): rodearla
	// para quedar de frente al destino le tomaba medio segundo y el rival
	// se la sacaba. El que recibe mira la pelota que viene.
	double fx, fz;
	if (j.toque == TOQUE_PASE || j.toque == TOQUE_CONDUCE) {
		fx = p.x - c.x;
		fz = p.z - c.z;
	} else if (hipot(vp.x, vp.z) > 1.0) {
		fx = -vp.x;
		fz = -vp.z;
	} else {
		fx = p.x - c.x;
		fz = p.z - c.z;
	}
	double vmax = std::max(0.1, c.vel_max * c.cansancio);
	double hacia = hipot(p.x - c.x, p.z - c.z);
	if (t > 0.0 && hacia / t > param_cuerpo.rapidez_para_girar) {
		fx = p.x - c.x;
		fz = p.z - c.z;
	}
	Cuerpo en_cero;
	V3 corre = punto_de_contacto(en_cero, clips[size_t(clip)], rumbo_de(fx, fz));
	double bx = p.x - corre.x, bz = p.z - corre.z;
	double dist = hipot(bx - c.x, bz - c.z);
	double necesita = dist / std::max(t, 0.05) / vmax * 1.15;
	double f = disputada ? 1.0 : std::clamp(necesita, 0.25, 1.0);
	c.ir_a(bx, bz, f, necesita < 0.25);
	c.mira = true;
	c.mira_x = p.x;
	c.mira_z = p.z;
	j.persigue = true;
	j.paso_meta = paso + int64_t(t / PASO_SEG + 0.5);
}

// A CONTENER_M de la pelota, del lado de lo que defiende: el medio del
// cuadrado en el rondo, su mitad en el partidito.
void Canchita::_contener(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	V3 bola = _bola_en(paso + PASOS_POR_TURNO);
	double dx, dz;
	if (modo == RONDO) {
		dx = -bola.x;
		dz = -bola.z;
	} else {
		dx = -_ataca(j.equipo);
		dz = -bola.z * 0.3;
	}
	double l = hipot(dx, dz);
	if (l < 1e-6) {
		dx = j.cuerpo.x - bola.x;
		dz = j.cuerpo.z - bola.z;
		l = std::max(hipot(dx, dz), 1e-6);
	}
	j.cuerpo.ir_a(bola.x + dx / l * CONTENER_M, bola.z + dz / l * CONTENER_M, 1.0, true);
	j.cuerpo.mira = true;
	j.cuerpo.mira_x = bola.x;
	j.cuerpo.mira_z = bola.z;
}

// El que patea le avisa al receptor (Simple Soccer): sale enseguida al punto
// del pase, sin esperar a leer la pelota; cuando la lee, corrige. Esperando
// la reacción y su turno de pensar arrancaba 0,3 s tarde y los pases al
// espacio se le iban.
void Canchita::_avisar_receptor(int pateador) {
	if (_receptor < 0) {
		return;
	}
	const JugadorCanchita &jp = jugadores[size_t(pateador)];
	JugadorCanchita &r = jugadores[size_t(_receptor)];
	_perseguidor[r.equipo] = _receptor;
	if (r.toque_pendiente && r.cuerpo.clip >= 0) {
		return;
	}
	double dx = jp.meta_x - pelota.pos.x, dz = jp.meta_z - pelota.pos.z;
	double l = std::max(hipot(dx, dz), 1e-6);
	r.persigue = true;
	r.toque = TOQUE_CONTROL;
	V3 meta = { jp.meta_x, param_pelota.radio, jp.meta_z };
	_orientar(_receptor, meta);
	// De frente a la pelota que viene, con el pie en el punto.
	r.cuerpo.ir_a(jp.meta_x + dx / l * ALCANCE_PLAN_M, jp.meta_z + dz / l * ALCANCE_PLAN_M, FACTOR_RECIBIR, true);
	r.cuerpo.mira = true;
	r.cuerpo.mira_x = pelota.pos.x;
	r.cuerpo.mira_z = pelota.pos.z;
}

// El control orientado: hacia adentro y lejos del rival más cercano.
void Canchita::_orientar(int i, V3 bola) {
	JugadorCanchita &j = jugadores[size_t(i)];
	double dx, dz;
	if (modo == RONDO) {
		dx = -bola.x;
		dz = -bola.z;
	} else {
		dx = _ataca(j.equipo);
		dz = -bola.z / _medio_z() * 0.5;
	}
	double l = std::max(hipot(dx, dz), 1e-9);
	dx /= l;
	dz /= l;
	int cerca = -1;
	double d_cerca = 1e9;
	for (size_t o = 0; o < jugadores.size(); o++) {
		if (jugadores[o].equipo == j.equipo) {
			continue;
		}
		double d = hipot(jugadores[o].cuerpo.x - bola.x, jugadores[o].cuerpo.z - bola.z);
		if (d < d_cerca) {
			d_cerca = d;
			cerca = int(o);
		}
	}
	if (cerca >= 0 && d_cerca < 6.0 && d_cerca > 1e-6) {
		double peso = 1.5 * (6.0 - d_cerca) / 6.0;
		dx += (bola.x - jugadores[size_t(cerca)].cuerpo.x) / d_cerca * peso;
		dz += (bola.z - jugadores[size_t(cerca)].cuerpo.z) / d_cerca * peso;
	}
	// Corriendo, la acomoda hacia donde va: si la frena o la tira para
	// atrás se pasa de largo y el rival se la lleva.
	const Cuerpo &c = j.cuerpo;
	double corre = c.rapidez() / std::max(c.vel_max, 0.1);
	if (corre > 0.2) {
		dx += c.vx / std::max(c.rapidez(), 1e-9) * 2.0 * corre;
		dz += c.vz / std::max(c.rapidez(), 1e-9) * 2.0 * corre;
	}
	l = hipot(dx, dz);
	if (l < 1e-9) {
		dx = 1.0;
		dz = 0.0;
		l = 1.0;
	}
	j.dir_x = dx / l;
	j.dir_z = dz / l;
	j.rapidez_toque = param_toque.control_ms;
}

// El poseedor: pase o conducción.
void Canchita::_decidir(int i, V3 bola, double t_patada) {
	JugadorCanchita &j = jugadores[size_t(i)];
	Pase pase = _planear_pase(i, bola, t_patada);
	double presion = _rival_mas_cerca(i, bola.x, bola.z);
	double tiene = double(paso - _desde_control) * PASO_SEG;
	bool pasa;
	if (modo == RONDO) {
		// El rondo es a uno o dos toques: siempre se la pasa.
		pasa = pase.hay;
	} else if (pase.hay && pase.margen >= param_toque.margen_seguro_seg && (tiene >= 0.6 || presion < 4.0)) {
		pasa = true;
	} else if (presion >= 2.5 || !pase.hay) {
		pasa = false;
	} else {
		pasa = true;
	}
	if (pasa) {
		j.toque = TOQUE_PASE;
		j.meta_x = pase.x;
		j.meta_z = pase.z;
		j.receptor = pase.receptor;
		j.globo = pase.globo;
		return;
	}
	// Conduce: hacia adelante (en el rondo, hacia el medio), lejos del que
	// presiona y sin irse de la cancha.
	_orientar(i, bola);
	double qx = std::clamp(bola.x + j.dir_x * 5.0, -_medio_x() + 2.0, _medio_x() - 2.0);
	double qz = std::clamp(bola.z + j.dir_z * 5.0, -_medio_z() + 2.0, _medio_z() - 2.0);
	double l = hipot(qx - bola.x, qz - bola.z);
	if (l > 1e-6) {
		j.dir_x = (qx - bola.x) / l;
		j.dir_z = (qz - bola.z) / l;
	}
	// Más largo con espacio, más corto con mejor control.
	double espacio = std::clamp((presion - 2.0) / 4.0, 0.0, 1.0);
	double largo = (param_toque.toque_corto_m + (param_toque.toque_largo_m - param_toque.toque_corto_m) * espacio)
			* (1.2 - 0.4 * j.control / 100.0);
	// Con lo que corre ahora (más lo que acelera en un segundo), no con su
	// punta: con la punta, el que venía despacio la dejaba 3 m adelante.
	double corre = std::min(j.cuerpo.vel_max * j.cuerpo.cansancio * param_toque.conduccion_factor,
			j.cuerpo.rapidez() + j.cuerpo.aceleracion * 0.5);
	j.toque = TOQUE_CONDUCE;
	j.rapidez_toque = _rapidez_conduce(corre, largo);
}

// Pase al punto de encuentro (docs/motor_v2.md, Simple Soccer): a los pies o
// a una de las dos tangentes al círculo que el receptor cubre mientras viaja
// la pelota. Cada punto se prueba con los tiempos de llegada de cada rival.
Canchita::Pase Canchita::_planear_pase(int i, V3 bola, double t_patada) {
	const JugadorCanchita &j = jugadores[size_t(i)];
	Pase mejor;
	for (size_t r = 0; r < jugadores.size(); r++) {
		const JugadorCanchita &jr = jugadores[r];
		if (int(r) == i || jr.equipo != j.equipo) {
			continue;
		}
		const Cuerpo &cr = jr.cuerpo;
		double ex = cr.x - bola.x, ez = cr.z - bola.z;
		double d0 = hipot(ex, ez);
		if (d0 < 3.0) {
			continue;
		}
		ex /= d0;
		ez /= d0;
		int k0;
		double v0 = _rapidez_raso(d0, k0);
		double puntos[3][2] = { { cr.x, cr.z }, { 0.0, 0.0 }, { 0.0, 0.0 } };
		int cuantos = 1;
		if (v0 > 0.0) {
			double t0 = t_patada + double(k0 + 1) * PASO_SEG;
			// El círculo que cubre trotando, sin contar la reacción: con la
			// mitad de la punta y hasta 4 m, el receptor llegaba tarde y el
			// pase se iba afuera.
			double radio = std::min(TANGENTE_MAX_M, 0.4 * cr.vel_max * cr.cansancio * std::max(0.0, t0 - param_toque.reaccion_seg));
			if (radio > 0.5 && d0 > radio + 1.0) {
				double largo = std::sqrt(d0 * d0 - radio * radio);
				double sen = radio / d0, cos_ = largo / d0;
				for (int lado = -1; lado <= 1; lado += 2) {
					double s = sen * double(lado);
					puntos[cuantos][0] = bola.x + (ex * cos_ - ez * s) * largo;
					puntos[cuantos][1] = bola.z + (ex * s + ez * cos_) * largo;
					cuantos++;
				}
			}
		}
		double espacio = std::min(_rival_mas_cerca(i, cr.x, cr.z), 8.0);
		for (int q = 0; q < cuantos; q++) {
			double tx = puntos[q][0], tz = puntos[q][1];
			if (!_adentro(tx, tz, modo == RONDO ? 0.5 : -0.5)) {
				continue;
			}
			double dx = tx - bola.x, dz = tz - bola.z;
			double d = hipot(dx, dz);
			int k;
			double v = _rapidez_raso(d, k);
			if (v < 0.0) {
				continue;
			}
			double t_bola = t_patada + double(k + 1) * PASO_SEG;
			if (q > 0 && tiempo_de_llegada(cr, tx, tz, ALCANCE_PLAN_M, FACTOR_RECIBIR) + param_toque.reaccion_seg > t_bola) {
				continue;
			}
			const Perfil &perfil = _perfiles.de(v, false);
			double margen = _margen(i, bola, dx / d, dz / d, perfil, k, t_patada);
			double avance = (tx - bola.x) * _ataca(j.equipo);
			double puntaje = std::min(margen, 1.0) + 0.02 * avance + 0.03 * espacio - (q > 0 ? 0.05 : 0.0);
			if (puntaje > mejor.puntaje) {
				mejor = { true, int(r), tx, tz, false, margen, puntaje };
			}
		}
		// Globo por arriba de los defensores, a los pies.
		if (d0 >= 7.0) {
			int k;
			double v = _rapidez_globo(d0, k);
			if (v > 0.0) {
				const Perfil &perfil = _perfiles.de(v, true);
				double margen = _margen(i, bola, ex, ez, perfil, k, t_patada);
				double avance = (cr.x - bola.x) * _ataca(j.equipo);
				double puntaje = std::min(margen, 1.0) + 0.02 * avance + 0.03 * espacio - 0.2;
				if (puntaje > mejor.puntaje) {
					mejor = { true, int(r), cr.x, cr.z, true, margen, puntaje };
				}
			}
		}
	}
	return mejor;
}

// Cuánto antes que la pelota llega el rival que mejor corta (segundos; < 0
// es que llega antes). Solo cuentan los tramos a menos de la altura de la cabeza.
double Canchita::_margen(int i, V3 bola, double dx, double dz, const Perfil &perfil, int k_fin,
		double t_patada) const {
	int equipo = jugadores[size_t(i)].equipo;
	double margen = 1e9;
	for (size_t o = 0; o < jugadores.size(); o++) {
		const JugadorCanchita &jo = jugadores[o];
		if (jo.equipo == equipo) {
			continue;
		}
		for (int q = 0; q <= k_fin; q += (q + 3 <= k_fin || q == k_fin) ? 3 : k_fin - q) {
			if (perfil.alto[size_t(q)] <= param_toque.cabeza_hasta) {
				double px = bola.x + dx * perfil.dist[size_t(q)];
				double pz = bola.z + dz * perfil.dist[size_t(q)];
				double tb = t_patada + double(q + 1) * PASO_SEG;
				double to = tiempo_de_llegada(jo.cuerpo, px, pz, ALCANCE_RIVAL_M) + param_toque.reaccion_seg;
				margen = std::min(margen, to - tb);
			}
			if (q == k_fin) {
				break;
			}
		}
	}
	return margen;
}

// La rapidez más baja (de la grilla de Perfiles) con la que la pelota llega
// a `d` todavía a llegada_pase_ms: un pase firme, no uno que muere. Si ni
// la más fuerte llega así, la más fuerte si llega; si no, -1.
double Canchita::_rapidez_raso(double d, int &k) {
	int desde = int(param_toque.pase_min_ms / Perfiles::PASO_RAPIDEZ + 0.5);
	int hasta = int(param_toque.pase_max_ms / Perfiles::PASO_RAPIDEZ + 0.5);
	for (int iv = desde; iv <= hasta; iv++) {
		double v = Perfiles::rapidez_de(iv);
		const Perfil &p = _perfiles.de(v, false);
		k = p.paso_a(d);
		if (k >= 0 && p.rapidez[size_t(k)] >= param_toque.llegada_pase_ms) {
			return v;
		}
	}
	double v = Perfiles::rapidez_de(hasta);
	k = _perfiles.de(v, false).paso_a(d);
	return k >= 0 ? v : -1.0;
}

// El globo más suave que baja a la altura del pecho recién a `d`, después de
// pasar por arriba de la cabeza.
double Canchita::_rapidez_globo(double d, int &k) {
	int desde = int(6.0 / Perfiles::PASO_RAPIDEZ + 0.5);
	int hasta = int(param_toque.pase_max_ms / Perfiles::PASO_RAPIDEZ + 0.5);
	for (int iv = desde; iv <= hasta; iv++) {
		const Perfil &p = _perfiles.de(Perfiles::rapidez_de(iv), true);
		bool arriba = false;
		for (size_t q = 0; q < p.alto.size(); q++) {
			if (p.alto[q] > param_toque.cabeza_hasta) {
				arriba = true;
			} else if (arriba && p.alto[q] <= param_toque.pecho_hasta) {
				if (p.dist[q] >= d - 0.5) {
					k = int(q);
					return Perfiles::rapidez_de(iv);
				}
				break;
			}
		}
	}
	k = -1;
	return -1.0;
}

// Que la pelota se le adelante `largo` metros al que corre a `corre` m/s y
// después la alcance.
double Canchita::_rapidez_conduce(double corre, double largo) {
	for (int iv = 2; iv <= 40; iv++) {
		double v = Perfiles::rapidez_de(iv);
		const Perfil &p = _perfiles.de(v, false);
		double adelante = 0.0;
		for (size_t q = 0; q < p.dist.size(); q++) {
			adelante = std::max(adelante, p.dist[q] - corre * double(q + 1) * PASO_SEG);
		}
		if (adelante >= largo) {
			return v;
		}
	}
	return Perfiles::rapidez_de(40);
}

double Canchita::_rival_mas_cerca(int i, double x, double z) const {
	int equipo = jugadores[size_t(i)].equipo;
	double d = 1e9;
	for (const JugadorCanchita &o : jugadores) {
		if (o.equipo != equipo) {
			d = std::min(d, hipot(o.cuerpo.x - x, o.cuerpo.z - z));
		}
	}
	return d;
}

// Qué tan libre está la línea de pase de la pelota a (x, z): el rival más
// cerca de esa línea, hasta 5 m.
double Canchita::_claridad(V3 bola, double x, double z, int equipo) const {
	double m = 5.0;
	V3 fin = { x, 0.0, z };
	for (const JugadorCanchita &o : jugadores) {
		if (o.equipo != equipo) {
			m = std::min(m, distancia_al_tramo(o.cuerpo.x, o.cuerpo.z, bola, fin));
		}
	}
	return m;
}

// Los que no van a la pelota.
void Canchita::_ubicar(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	Cuerpo &c = j.cuerpo;
	V3 bola = pelota.pos;
	double qx = c.x, qz = c.z, factor = 0.7;
	if (modo == RONDO) {
		const double h = RONDO_LADO * 0.5;
		if (j.equipo == 0) {
			// Sobre su lado, donde la línea de pase queda más libre.
			const double base[4][4] = { { 0.0, -h, 1.0, 0.0 }, { h, 0.0, 0.0, 1.0 }, { 0.0, h, -1.0, 0.0 },
				{ -h, 0.0, 0.0, -1.0 } };
			const double *b = base[j.puesto % 4];
			const double lugares[5] = { -h + 1.5, -h * 0.5, 0.0, h * 0.5, h - 1.5 };
			double mejor = -1e9;
			for (double u : lugares) {
				double x = b[0] + b[2] * u, z = b[1] + b[3] * u;
				if (hipot(x - bola.x, z - bola.z) < 3.0) {
					continue;
				}
				double puntaje = _claridad(bola, x, z, 0) - 0.25 * hipot(x - c.x, z - c.z);
				if (puntaje > mejor) {
					mejor = puntaje;
					qx = x;
					qz = z;
				}
			}
			factor = 0.6;
		} else {
			factor = 0.85;
			if (paso < _reinicio_hasta || _reinicio_en >= 0) {
				qx = j.puesto == 0 ? -1.5 : 1.5;
				qz = 0.0;
			} else {
				// Tapa la línea de pase más libre.
				int mejor_a = -1;
				double mejor = -1.0;
				for (size_t a = 0; a < jugadores.size(); a++) {
					const JugadorCanchita &ja = jugadores[a];
					if (ja.equipo != 0 || int(a) == poseedor || int(a) == _perseguidor[0]) {
						continue;
					}
					double cl = _claridad(bola, ja.cuerpo.x, ja.cuerpo.z, 0);
					if (cl > mejor) {
						mejor = cl;
						mejor_a = int(a);
					}
				}
				if (mejor_a >= 0) {
					qx = bola.x + (jugadores[size_t(mejor_a)].cuerpo.x - bola.x) * 0.45;
					qz = bola.z + (jugadores[size_t(mejor_a)].cuerpo.z - bola.z) * 0.45;
				}
			}
		}
	} else if (modo == PRUEBA) {
		qx = j.casa_x;
		qz = j.casa_z;
	} else if (j.equipo == equipo_con_pelota) {
		// Su ancla, corrida hacia la pelota, y lejos del que lo marca.
		const double *a = ANCLAS[j.puesto % 5];
		double ax = a[0] * _ataca(j.equipo), az = a[1];
		qx = ax + (bola.x - ax) * 0.35;
		qz = az + (bola.z - az) * 0.35;
		double d = _rival_mas_cerca(i, qx, qz);
		for (const JugadorCanchita &o : jugadores) {
			double e = hipot(qx - o.cuerpo.x, qz - o.cuerpo.z);
			if (o.equipo != j.equipo && e == d && d < 3.0 && d > 1e-6) {
				qx += (qx - o.cuerpo.x) / d * (3.0 - d);
				qz += (qz - o.cuerpo.z) / d * (3.0 - d);
				break;
			}
		}
		factor = 0.7;
	} else {
		// Marca: del lado de su mitad y un poco hacia la pelota. Parado justo
		// entre su marca y la pelota tapaba todas las líneas de pase y se
		// cortaba uno de cada tres.
		if (j.marca >= 0) {
			const Cuerpo &m = jugadores[size_t(j.marca)].cuerpo;
			double ux = bola.x - m.x, uz = bola.z - m.z;
			double l = std::max(hipot(ux, uz), 1e-9);
			double gx = -_ataca(j.equipo) * 0.6 + ux / l * 0.4, gz = uz / l * 0.4;
			double lg = std::max(hipot(gx, gz), 1e-9);
			double cerca = std::min(j.marca == poseedor ? 3.0 : 2.0, l * 0.5);
			qx = m.x + gx / lg * cerca;
			qz = m.z + gz / lg * cerca;
		}
		factor = 0.9;
	}
	// En un reinicio los rivales se alejan.
	if (paso < _reinicio_hasta && j.equipo != equipo_con_pelota) {
		double d = hipot(qx - bola.x, qz - bola.z);
		if (d < REINICIO_DISTANCIA_M) {
			double ux = d > 1e-6 ? (qx - bola.x) / d : -_ataca(j.equipo);
			double uz = d > 1e-6 ? (qz - bola.z) / d : 0.0;
			qx = bola.x + ux * REINICIO_DISTANCIA_M;
			qz = bola.z + uz * REINICIO_DISTANCIA_M;
		}
	}
	qx = std::clamp(qx, -_medio_x() - 0.5, _medio_x() + 0.5);
	qz = std::clamp(qz, -_medio_z() - 0.5, _medio_z() + 0.5);
	c.ir_a(qx, qz, factor, true);
	c.mira = true;
	c.mira_x = bola.x;
	c.mira_z = bola.z;
}

void Canchita::_franja(Parte parte, double &desde, double &hasta) const {
	const double limites[5] = { 0.0, param_toque.pie_hasta, param_toque.muslo_hasta, param_toque.pecho_hasta,
		param_toque.cabeza_hasta };
	int k = std::clamp(int(parte), 0, 3);
	desde = limites[k];
	hasta = limites[k + 1];
}

int Canchita::_clip_de_parte(const JugadorCanchita &j, Parte parte) const {
	if (j.toque == TOQUE_PASE) {
		return param_toque.clip_pase;
	}
	if (j.toque == TOQUE_CONDUCE) {
		return param_toque.clip_conduce;
	}
	return parte == NINGUNA ? -1 : param_toque.clip_recepcion[parte];
}

int Canchita::_clip_para(const JugadorCanchita &j, double alto) const {
	return _clip_de_parte(j, parte_para(param_toque, alto));
}

// El pie llega un poco de costado (el ajuste de pie de la vista lo tapa):
// hacia la pelota, pero a no más de giro_alcance_rad de adonde mira.
double Canchita::_rumbo_al_tocar(const Cuerpo &c, double rumbo, double x, double z) const {
	double dx = x - c.x, dz = z - c.z;
	if (dx * dx + dz * dz < 1e-9) {
		return rumbo;
	}
	double dif = std::clamp(mate::envolver(rumbo_de(dx, dz) - rumbo), -param_toque.giro_alcance_rad,
			param_toque.giro_alcance_rad);
	return rumbo + dif;
}

// Arranca el gesto cuando, en lo que tarda en llegar a su cuadro de
// contacto, el punto que toca va a estar en la pelota.
void Canchita::_gatillo(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	Cuerpo &c = j.cuerpo;
	if (!j.persigue || c.clip >= 0) {
		return;
	}
	if (paso < _reinicio_hasta && j.equipo != equipo_con_pelota) {
		return;
	}
	if (modo == RONDO && _reinicio_en >= 0) {
		return;
	}
	// El clip depende de la parte con que la va a tocar, y la parte de la
	// altura de la pelota en su cuadro de contacto: se prueba la de dentro
	// de 8 pasos y, si en el contacto de ese clip la pelota queda en otra
	// franja, la de esa franja. Clip y parte van siempre juntos.
	Parte parte = PIE;
	if (j.toque == TOQUE_CONTROL) {
		parte = parte_para(param_toque, _bola_en(paso + 8).y);
		if (parte == NINGUNA) {
			return;
		}
	}
	int clip = _clip_de_parte(j, parte);
	if (clip < 0) {
		return;
	}
	for (int vuelta = 0; vuelta < 2; vuelta++) {
		double tc = std::max(clips[size_t(clip)].contacto_seg, 0.0);
		V3 p = _bola_en(paso + int64_t(tc / PASO_SEG + 0.5));
		if (j.toque == TOQUE_CONTROL && vuelta == 0) {
			Parte otra = parte_para(param_toque, p.y);
			if (otra == NINGUNA) {
				return;
			}
			if (otra != parte) {
				parte = otra;
				clip = _clip_de_parte(j, parte);
				if (clip < 0) {
					return;
				}
				continue;
			}
		}
		{
			// Dónde va a estar su punto de contacto respecto de la pelota en
			// el cuadro de contacto si arranca ahora, y si arrancara un paso después.
			double d[2];
			V3 q;
			for (int luego_de = 0; luego_de < 2; luego_de++) {
				double t = tc + double(luego_de) * PASO_SEG;
				V3 pt = _bola_en(paso + int64_t(t / PASO_SEG + 0.5));
				Cuerpo luego = c;
				luego.x += c.vx * t;
				luego.z += c.vz * t;
				q = punto_de_contacto(luego, clips[size_t(clip)], _rumbo_al_tocar(luego, c.rumbo, pt.x, pt.z));
				d[luego_de] = hipot(q.x - pt.x, q.z - pt.z);
				if (luego_de == 0) {
					p = pt;
				}
			}
			double desde, hasta;
			_franja(parte, desde, hasta);
			bool alto_ok = j.toque != TOQUE_CONTROL
					? std::abs(clips[size_t(clip)].punto_y - p.y) <= param_toque.tolerancia_alto_m
					: p.y >= desde - param_toque.tolerancia_alto_m && p.y <= hasta + param_toque.tolerancia_alto_m;
			bool quietos = c.rapidez() < RAPIDEZ_QUIETO && hipot(pelota.vel.x, pelota.vel.z) < RAPIDEZ_QUIETO;
			// Arranca si va a quedar justo en la pelota, o si este es el mejor
			// momento (después se aleja) y queda al alcance: con la pelota a
			// 9 m/s pasando a medio metro, esperar el gatillo exacto la dejaba
			// pasar (en el rondo, la mitad de los pases que se iban afuera).
			bool mejor_ahora = d[0] <= d[1] && d[0] <= param_toque.tolerancia_m;
			if (alto_ok && (d[0] <= param_toque.gatillo_m || mejor_ahora || (quietos && d[0] <= param_toque.tolerancia_m))) {
				if (c.empezar(clip)) {
					j.clip_toque = clip;
					j.parte = parte;
					j.toque_pendiente = true;
				}
			}
			return;
		}
	}
}

// --- Mundo: quién toca la pelota ---

// El primero cuyo punto de contacto, con la ventana abierta, pasa por la
// pelota en este paso. Nadie la mueve: cambia su velocidad desde donde está.
bool Canchita::_resolver_toques() {
	int mejor = -1;
	double mejor_d = 1e9;
	bool bloqueado = modo == RONDO && _reinicio_en >= 0;
	for (size_t i = 0; i < jugadores.size(); i++) {
		const JugadorCanchita &j = jugadores[i];
		const Cuerpo &c = j.cuerpo;
		if (!j.toque_pendiente || bloqueado) {
			continue;
		}
		bool abierta = c.fase == CONTACTO || (c.eventos & CIERRA_CONTACTO);
		if (!abierta || (paso < _reinicio_hasta && j.equipo != equipo_con_pelota)) {
			continue;
		}
		const Clip &k = clips[size_t(j.clip_toque)];
		V3 q = punto_de_contacto(c, k, _rumbo_al_tocar(c, c.rumbo, pelota.pos.x, pelota.pos.z));
		double d = distancia_al_tramo(q.x, q.z, pelota.previa, pelota.pos);
		bool alto_ok;
		if (j.toque == TOQUE_CONTROL) {
			// La pelota tiene que estar a la altura de la parte con que la
			// recibe (su franja, más la tolerancia): la cabeza no para una
			// pelota que ya bajó al pie.
			double desde, hasta;
			_franja(Parte(j.parte), desde, hasta);
			double tol = param_toque.tolerancia_alto_m;
			double bajo = std::min(pelota.previa.y, pelota.pos.y), alto = std::max(pelota.previa.y, pelota.pos.y);
			alto_ok = alto >= desde - tol && bajo <= hasta + tol;
		} else {
			alto_ok = std::min(std::abs(pelota.previa.y - q.y), std::abs(pelota.pos.y - q.y)) <= param_toque.tolerancia_alto_m;
		}
		if (alto_ok && d <= param_toque.tolerancia_m && d < mejor_d) {
			mejor = int(i);
			mejor_d = d;
		}
	}
	if (mejor >= 0) {
		_tocar(mejor, mejor_d);
		// El primero gana el cruce: las otras piernas que ya estaban en la
		// pelota iban a la pelota de antes. Sin esto el que perdía la tocaba
		// al paso siguiente y se la llevaba (en el partidito, quites de ida y
		// vuelta en 0,02 s).
		for (size_t i = 0; i < jugadores.size(); i++) {
			JugadorCanchita &j = jugadores[i];
			if (int(i) != mejor && j.toque_pendiente && j.cuerpo.fase == CONTACTO) {
				j.toque_pendiente = false;
				j.persigue = false;
				j.pensar_ya = true;
				cuenta.cruces_perdidos++;
			}
		}
	}
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		if (!j.toque_pendiente || int(i) == mejor) {
			continue;
		}
		const Cuerpo &c = j.cuerpo;
		if ((c.eventos & CIERRA_CONTACTO) || c.fase == RECUPERACION || c.clip < 0) {
			// Se cerró la ventana y no la tocó: un fallo, vuelve a pensar.
			j.toque_pendiente = false;
			j.persigue = false;
			j.pensar_ya = true;
			cuenta.fallos++;
		}
	}
	return mejor >= 0;
}

void Canchita::_tocar(int i, double distancia) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	bool pase_en_juego = _pase_activo;
	bool ataca = j.equipo == equipo_con_pelota;
	int tipo = j.toque;
	bool poseedor_ = ultimo_toque == i && (ultimo_tipo == TOQUE_CONTROL || ultimo_tipo == TOQUE_CONDUCE);
	// Pase de primera: el receptor de un pase la puede mandar sin pararla.
	bool de_primera = tipo == TOQUE_PASE && pase_en_juego && !poseedor_;
	if (!ataca || (!poseedor_ && !de_primera) || (tipo != TOQUE_PASE && tipo != TOQUE_CONDUCE)) {
		tipo = TOQUE_CONTROL;
	}
	if (tipo == TOQUE_CONTROL && j.toque != TOQUE_CONTROL) {
		// Iba a patear y otro la tocó antes: la controla hacia adentro.
		_orientar(i, pelota.pos);
	}
	double presion = _rival_mas_cerca(i, pelota.pos.x, pelota.pos.z);
	// Con un rival encima el error crece, hasta 1,5 veces.
	double apretado = 1.0 + 0.5 * std::clamp(1.0 - presion / param_toque.presion_m, 0.0, 1.0);
	double vin = std::sqrt(pelota.vel.x * pelota.vel.x + pelota.vel.y * pelota.vel.y + pelota.vel.z * pelota.vel.z);
	double angulo = 0.0, rapidez = 0.0, elevacion = 0.0, vertical = 0.0;
	switch (tipo) {
		case TOQUE_PASE: {
			double dx = j.meta_x - pelota.pos.x, dz = j.meta_z - pelota.pos.z;
			double d = std::max(hipot(dx, dz), 0.5);
			int k;
			rapidez = j.globo ? _rapidez_globo(d, k) : _rapidez_raso(d, k);
			if (rapidez < 0.0) {
				rapidez = j.globo ? 12.0 : param_toque.pase_max_ms;
			}
			angulo = rumbo_de(dx, dz);
			// Patear hacia un costado de adonde mira es más impreciso: de
			// espaldas, el doble.
			double de_lado = std::abs(mate::envolver(angulo - c.rumbo)) / mate::PI;
			double sigma = param_toque.error_pase_rad * (1.0 - 0.8 * j.pases / 100.0) * apretado * (1.0 + de_lado);
			angulo += _azar.normal() * sigma;
			rapidez *= 1.0 + _azar.normal() * param_toque.error_pase_rapidez * (1.0 - 0.7 * j.pases / 100.0) * apretado;
			elevacion = j.globo ? param_toque.elevacion_globo : 0.0;
			cuenta.pases++;
			if (j.globo) {
				cuenta.pases_globo++;
			}
			if (de_primera) {
				// El de primera también completa el pase que le llegaba.
				if (i == _receptor) {
					cuenta.completados++;
					cuenta.de_primera++;
					cuenta.recepciones_medidas++;
					cuenta.espera_suma += j.quieto_seg;
					cuenta.espera_max = std::max(cuenta.espera_max, j.quieto_seg);
					if (j.quieto_seg > 0.5) {
						cuenta.esperas_largas++;
					}
				} else {
					cuenta.completados_otro++;
				}
			}
			_pase_activo = true;
			_pateador = i;
			_receptor = j.receptor;
			_avisar_receptor(i);
			j.pateo_en = paso;
			for (JugadorCanchita &o : jugadores) {
				o.quieto_seg = 0.0;
			}
			poseedor = -1;
			break;
		}
		case TOQUE_CONDUCE: {
			angulo = rumbo_de(j.dir_x, j.dir_z) + _azar.normal() * 0.05 * (1.0 - 0.8 * j.control / 100.0) * apretado;
			rapidez = j.rapidez_toque * (1.0 + _azar.normal() * 0.08 * (1.0 - 0.7 * j.control / 100.0));
			cuenta.conducciones++;
			_pase_activo = false;
			poseedor = i;
			break;
		}
		default: {
			// La parte del gesto que la tocó (el clip), no la de la altura de
			// este paso: en el borde de dos franjas no coinciden.
			Parte parte = Parte(j.parte);
			if (j.toque != TOQUE_CONTROL || parte == NINGUNA) {
				parte = parte_para(param_toque, pelota.pos.y);
				parte = parte == NINGUNA ? CABEZA : parte;
			}
			double dificil = (0.5 + vin / 15.0) * (parte == PIE ? 1.0 : 1.3) * apretado;
			double torpeza = 1.0 - 0.8 * j.control / 100.0;
			angulo = rumbo_de(j.dir_x, j.dir_z) + _azar.normal() * param_toque.error_control_rad * torpeza * dificil;
			rapidez = param_toque.control_ms + std::abs(_azar.normal()) * param_toque.error_control_ms * torpeza * dificil;
			// Pecho, muslo y cabeza la bajan: sale más lenta y cae.
			if (parte != PIE) {
				rapidez *= 0.7;
				vertical = parte == CABEZA ? 1.0 : 0.3;
			}
			cuenta.controles++;
			cuenta.recepciones[parte]++;
			if (ataca && pase_en_juego) {
				if (i == _receptor) {
					cuenta.completados++;
					cuenta.recepciones_medidas++;
					cuenta.espera_suma += j.quieto_seg;
					cuenta.espera_max = std::max(cuenta.espera_max, j.quieto_seg);
					if (j.quieto_seg > 0.5) {
						cuenta.esperas_largas++;
					}
				} else {
					cuenta.completados_otro++;
				}
			}
			_pase_activo = false;
			poseedor = i;
			_desde_control = paso;
			break;
		}
	}
	if (!ataca) {
		// El rival la tocó: corte si venía un pase, si no quite.
		if (pase_en_juego) {
			cuenta.cortes++;
			cuenta.corte_mas_lejos_m = std::max(cuenta.corte_mas_lejos_m, distancia);
		} else {
			cuenta.quites++;
		}
		if (modo == RONDO) {
			_reinicio_en = paso + RONDO_ESPERA_CORTE;
			poseedor = -1;
		} else {
			equipo_con_pelota = j.equipo;
			_asignar_marcas();
		}
	}
	double s, co;
	mate::seno_coseno(angulo, s, co);
	double se, ce;
	mate::seno_coseno(elevacion, se, ce);
	V3 v = { s * rapidez * ce, rapidez * se + vertical, co * rapidez * ce };
	pelota.poner(pelota.pos, v, {});
	j.toque_pendiente = false;
	j.persigue = false;
	j.pensar_ya = true;
	j.inmune_hasta = paso + int64_t(param_toque.sin_rebote_seg / PASO_SEG + 0.5);
	ultimo_toque = i;
	ultimo_tipo = tipo;
	_visto_paso = paso + _reaccion_pasos;
	_cambio = true;
}

// La pelota que pega en las piernas de alguien que no la iba a tocar rebota
// contra él (choque con restitución, en el piso). Solo cambia la velocidad:
// la posición sigue siendo la de la física.
bool Canchita::_rebotes() {
	if (modo == RONDO && _reinicio_en >= 0) {
		return false;
	}
	const double r = param_pelota.radio;
	if (pelota.pos.y > param_toque.alto_cuerpo + r) {
		return false;
	}
	const double minimo = param_toque.radio_piernas + r;
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		if (paso < j.inmune_hasta || j.toque_pendiente) {
			continue;
		}
		const Cuerpo &c = j.cuerpo;
		double ex = pelota.pos.x - c.x, ez = pelota.pos.z - c.z;
		double d = hipot(ex, ez);
		if (d >= minimo || d < 1e-6) {
			continue;
		}
		double nx = ex / d, nz = ez / d;
		double rx = pelota.vel.x - c.vx, rz = pelota.vel.z - c.vz;
		double vn = rx * nx + rz * nz;
		if (vn >= 0.0) {
			continue;
		}
		rx -= nx * (1.0 + param_toque.restitucion_cuerpo) * vn;
		rz -= nz * (1.0 + param_toque.restitucion_cuerpo) * vn;
		pelota.vel.x = rx + c.vx;
		pelota.vel.z = rz + c.vz;
		cuenta.rebotes_cuerpo++;
		j.inmune_hasta = paso + 10;
		if (j.equipo != equipo_con_pelota) {
			cuenta.desvios++;
			if (_pase_activo) {
				cuenta.cortes++;
				cuenta.corte_mas_lejos_m = std::max(cuenta.corte_mas_lejos_m, d - r);
			}
			_pase_activo = false;
			if (modo == RONDO) {
				_reinicio_en = paso + RONDO_ESPERA_CORTE;
				poseedor = -1;
			}
		}
		_visto_paso = paso + _reaccion_pasos;
		_cambio = true;
		return true;
	}
	return false;
}

void Canchita::_reglas() {
	if (_reinicio_en >= 0 && paso >= _reinicio_en) {
		_reinicio_en = -1;
		_reiniciar(0, pelota.pos.x, pelota.pos.z);
		return;
	}
	double margen = modo == RONDO ? RONDO_AFUERA_M : param_pelota.radio;
	if (_adentro(pelota.pos.x, pelota.pos.z, margen)) {
		return;
	}
	cuenta.salidas++;
	if (_pase_activo) {
		cuenta.pases_afuera++;
	}
	if (modo == RONDO) {
		_reinicio_en = -1;
		_reiniciar(0, pelota.pos.x, pelota.pos.z);
	} else {
		int equipo = ultimo_toque >= 0 ? 1 - jugadores[size_t(ultimo_toque)].equipo : 1 - equipo_con_pelota;
		_reiniciar(equipo, pelota.pos.x, pelota.pos.z);
	}
}

// Reanudación: la pelota se pone quieta donde corresponde (no es una
// corrección: es un saque) y el equipo que saca la tiene 1,5 s sin rivales
// cerca. En el rondo la saca el de afuera más cercano, a sus pies.
void Canchita::_reiniciar(int equipo, double x, double z) {
	cuenta.reinicios++;
	double bx, bz;
	int saca = -1;
	if (modo == RONDO) {
		double mejor = 1e9;
		for (size_t a = 0; a < jugadores.size(); a++) {
			const Cuerpo &c = jugadores[a].cuerpo;
			double d = hipot(c.x - x, c.z - z);
			if (jugadores[a].equipo == equipo && d < mejor) {
				mejor = d;
				saca = int(a);
			}
		}
		// Sobre su lado, frente a él y medio metro adentro: el que la fue a
		// buscar afuera vuelve a sacar desde la línea.
		const Cuerpo &c = jugadores[size_t(saca)].cuerpo;
		const double h = RONDO_LADO * 0.5 - 0.5;
		bx = std::clamp(c.x, -h, h);
		bz = std::clamp(c.z, -h, h);
		if (std::abs(bx) > std::abs(bz)) {
			bx = bx > 0.0 ? h : -h;
		} else {
			bz = bz > 0.0 ? h : -h;
		}
	} else {
		bx = std::clamp(x, -_medio_x() + 0.3, _medio_x() - 0.3);
		bz = std::clamp(z, -_medio_z() + 0.3, _medio_z() - 0.3);
	}
	pelota.poner({ bx, param_pelota.radio, bz }, {}, {});
	equipo_con_pelota = equipo;
	poseedor = saca;
	ultimo_toque = saca;
	ultimo_tipo = saca >= 0 ? TOQUE_CONTROL : TOQUE_NADA;
	_desde_control = paso;
	_pase_activo = false;
	_receptor = -1;
	_reinicio_hasta = paso + REINICIO_PASOS;
	for (JugadorCanchita &j : jugadores) {
		j.toque_pendiente = false;
		j.persigue = false;
		j.pensar_ya = true;
	}
	if (modo == PARTIDITO) {
		_asignar_marcas();
	}
	// Un saque lo ven todos enseguida.
	_visto_paso = paso;
	_cambio = true;
	trayectoria.predecir(pelota, HORIZONTE);
	_tray_paso = paso;
	for (size_t i = 0; i < jugadores.size(); i++) {
		_alcance(int(i), 1.0, _k_llega[i], _t_llega[i]);
	}
	_analizar();
}

// Partidito: cada defensor marca al atacante libre más cercano.
void Canchita::_asignar_marcas() {
	std::vector<bool> tomado(jugadores.size(), false);
	for (JugadorCanchita &d : jugadores) {
		d.marca = -1;
		if (d.equipo == equipo_con_pelota) {
			continue;
		}
		double mejor = 1e9;
		for (size_t a = 0; a < jugadores.size(); a++) {
			const JugadorCanchita &ja = jugadores[a];
			if (ja.equipo != equipo_con_pelota || tomado[a]) {
				continue;
			}
			double e = hipot(ja.cuerpo.x - d.cuerpo.x, ja.cuerpo.z - d.cuerpo.z);
			if (e < mejor) {
				mejor = e;
				d.marca = int(a);
			}
		}
		if (d.marca >= 0) {
			tomado[size_t(d.marca)] = true;
		}
	}
}

void Canchita::_separar_cuerpos() {
	const double minimo = RADIO_CUERPO * 2.0;
	for (size_t i = 0; i + 1 < jugadores.size(); i++) {
		for (size_t k = i + 1; k < jugadores.size(); k++) {
			Cuerpo &a = jugadores[i].cuerpo;
			Cuerpo &b = jugadores[k].cuerpo;
			double ex = b.x - a.x, ez = b.z - a.z;
			if (std::abs(ex) >= minimo || std::abs(ez) >= minimo) {
				continue;
			}
			double d2 = ex * ex + ez * ez;
			if (d2 < minimo * minimo && d2 > 1e-6) {
				double d = std::sqrt(d2);
				double hunde = (minimo - d) * 0.5;
				a.x -= ex / d * hunde;
				a.z -= ez / d * hunde;
				b.x += ex / d * hunde;
				b.z += ez / d * hunde;
			}
		}
	}
}

void Canchita::_medir() {
	double tope = Cuerpo::caida_maxima(param_cuerpo, PASO_SEG) + 1e-9;
	bool mide_espera = _pase_activo && _receptor >= 0 && _pateador >= 0
			&& paso - jugadores[size_t(_pateador)].pateo_en >= _reaccion_pasos;
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		const Cuerpo &c = j.cuerpo;
		double r = c.rapidez();
		if (j.rapidez_previa - r > tope) {
			cuenta.frenadas_en_seco++;
		}
		double anduvo = hipot(c.x - c.previa_x, c.z - c.previa_z);
		cuenta.peor_salto_cuerpo_m = std::max(cuenta.peor_salto_cuerpo_m,
				anduvo - std::max(r, j.rapidez_previa) * PASO_SEG);
		if (mide_espera && int(i) == _receptor && r < RAPIDEZ_QUIETO) {
			j.quieto_seg += PASO_SEG;
		}
	}
	if (poseedor >= 0 || _pase_activo) {
		cuenta.posesion_seg[equipo_con_pelota & 1] += PASO_SEG;
	}
}

// FNV-1a sobre cuerpos y pelota.
uint64_t Canchita::huella() const {
	uint64_t h = 1469598103934665603ULL;
	auto mezclar = [&h](const double &v) {
		const unsigned char *b = reinterpret_cast<const unsigned char *>(&v);
		for (size_t i = 0; i < sizeof(double); i++) {
			h = (h ^ b[i]) * 1099511628211ULL;
		}
	};
	for (const JugadorCanchita &j : jugadores) {
		mezclar(j.cuerpo.x);
		mezclar(j.cuerpo.z);
		mezclar(j.cuerpo.vx);
		mezclar(j.cuerpo.vz);
		mezclar(j.cuerpo.rumbo);
	}
	mezclar(pelota.pos.x);
	mezclar(pelota.pos.y);
	mezclar(pelota.pos.z);
	mezclar(pelota.vel.x);
	mezclar(pelota.vel.y);
	mezclar(pelota.vel.z);
	return h;
}
