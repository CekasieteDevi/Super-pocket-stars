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
// El que se acomoda a menos de esto de su lugar llega sin apuro (Cuerpo::suave).
constexpr double ACOMODA_SUAVE_M = 5.0;
// Si el encuentro con la pelota queda a más de esto sin apurarse, va a fondo.
constexpr double ENCUENTRO_LEJOS_SEG = 1.2;
// Pase al espacio: a lo sumo esto al costado del receptor.
constexpr double TANGENTE_MAX_M = 2.5;
// El defensor va a la pelota controlada solo si llega esto antes que el que
// la tiene; si no, contiene a CONTENER_M. Tirándose siempre, en el partidito
// había un quite cada 1,7 s.
constexpr double GANA_CARRERA_SEG = 0.1;
constexpr double CONTENER_M = 1.5;
// El que acaba de patear no vuelve a ir a la pelota enseguida.
constexpr int DESCANSO_PATEADOR = 30;
// El que dio el pase no va a buscarlo mientras viaja hacia un compañero.
// Con el descanso solo (0,5 s), el pase largo que nadie recibía lo iba a
// buscar él: en la revisión visual, un autopase.
constexpr int DESCANSO_PASE_PROPIO = 150;
// La predicción de la pelota se rehace cuando le quedan estos pasos (1 s).
constexpr int TRAYECTORIA_MARGEN = 60;
// Con el arco a tiro, cada cuánto vuelve a decidir el que conduce.
constexpr double DECIDE_A_TIRO_SEG = 0.5;
// El gol que entra hasta esto después de un remate (3 s) es del que remató,
// aunque la pelota se haya desviado en el camino.
constexpr int64_t GOL_DEL_REMATE_PASOS = 180;
// El control mira este largo adelante para no mandarla afuera (toque.control_raya_m).
constexpr double CONTROL_MIRA_M = 4.0;
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
constexpr double COMPRESION_SAQUE = Canchita::COMPRESION_SAQUE;
// Partido: saque de arco desde el borde del área chica.
constexpr double SAQUE_DE_ARCO_M = 5.5;
// Pase al espacio: la pelota puede llegar hasta esto después que el receptor
// (así no la espera parado), y todavía rodando a esta rapidez como mínimo.
// Medición: la pelota conducida a más de esto del que la lleva ya no la lleva.
constexpr double CONDUCE_LEJOS_M = 2.5;
// Lo más fuerte que sale un centro tendido (el pase llega a pase_max_ms).
constexpr double CENTRO_MAX_MS = 30.0;
// Al centro salta, además del que va a la pelota, el compañero que lo puede
// cabecear moviéndose menos, y esto como mucho.
constexpr double CENTRO_A_TIRO_M = 3.0;
constexpr double ESPACIO_TARDE_SEG = 0.3;
constexpr double ESPACIO_RESTO_MS = 2.0;
// Partido: _alcance mira la trayectoria de a estos puntos (0,05 s).
constexpr int SALTO_ALCANCE = 3;
constexpr int FESTEJO_PASOS = Canchita::FESTEJO_PASOS;
// Un remate termina a lo sumo 3 s después de salir (si ya nadie la toca ni
// sale, se quedó corto) o cuando la pelota casi no se mueve.
constexpr int REMATE_MAX_PASOS = 180;
constexpr double REMATE_MUERTO_MS = 1.0;
// El remate que sale hasta 3 s después de un rebote del arquero.
constexpr int TRAS_REBOTE_PASOS = 180;
// La trayectoria "va al arco" si cruza la línea hasta esto afuera de los
// palos y del travesaño: el arquero también va a la que pasa rozando.
constexpr double CRUCE_MARGEN_M = 0.5;
// En las manos: adelante del pecho (Arquero_Sostiene) y a qué alto.
constexpr double MANOS_ADELANTE_M = 0.35;
constexpr double MANOS_ALTO_M = 0.6;
// La pasada de la pelota por la mano del arquero se mide hasta esto más
// adelante (0,1 s: lo que dura la ventana de contacto).
constexpr double PASOS_PASADA = 6.0;
// Al soltarla para jugar, la deja caer adelante a esta rapidez.
constexpr double SUELTA_MS = 1.0;

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
	// El modo PRUEBA usa la cancha del partidito; ARCO, la entera.
	if (_con_arcos()) {
		return PARTIDO_LARGO * 0.5;
	}
	return modo == RONDO ? RONDO_LADO * 0.5 : PARTIDITO_LARGO * 0.5;
}

double Canchita::_medio_z() const {
	if (_con_arcos()) {
		return PARTIDO_ANCHO * 0.5;
	}
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
	_perfiles.configurar(param_pelota, param_toque.elevacion_globo, HORIZONTE, cerebro.pesos.centro_elevacion_rad);
	_reaccion_pasos = std::max(0, int(param_toque.reaccion_seg / PASO_SEG + 0.5));
	size_t n = jugadores.size();
	_k_llega.assign(n, -1);
	_t_llega.assign(n, 1e9);
	_perseguidor[0] = _perseguidor[1] = -1;
	_segundo[0] = _segundo[1] = -1;
	_pase_activo = false;
	_pateador = _receptor = -1;
	_reinicio_en = _reinicio_hasta = -1;
	_pases_posesion = 0;
	_pase_al_espacio = false;
	_en_manos = -1;
	_suelta_en = -1;
	_mano = SaqueMano();
	_suspendido = false;
	_saque_medio_en = -1;
	_llegada_contada = false;
	_ultimo_resultado = -1;
	_rebote_arquero_en = -1000;
	_remate = Remate();
	registro.clear();
	registro_pases.clear();
	_pase_reg = -1;
	_k_cruce[0] = _k_cruce[1] = -1;
	if (modo == PARTIDO) {
		cerebro.pesos.reaccion_seg = param_toque.reaccion_seg;
		cerebro.empezar();
	}
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
		} else if (modo == PARTIDO) {
			// Su casillero, comprimido hacia su arco para caber en su mitad.
			size_t k = size_t(&j - jugadores.data());
			const FichaCerebro &f = cerebro.fichas[k];
			x = (-Cerebro::MEDIO_LARGO + (f.base_x + Cerebro::MEDIO_LARGO) * COMPRESION_SAQUE) * _ataca(j.equipo);
			z = f.base_z;
			if (reglas) {
				// El mismo lugar que en cualquier saque del medio: en su mitad
				// y afuera del círculo. Con la cuenta de arriba el delantero
				// de punta arrancaba 0,6 m adentro de la mitad rival, cruzado
				// con el del otro equipo: los dos se empujaban de frente y el
				// saque inicial no salía nunca (5 de 60 partidos, semilla
				// 97000). El reloj corría igual y tapaba el partido vacío.
				_ubicar_saque_del_medio(int(k), x, z);
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
		j.hay_decision = false;
		j.rapidez_pase = 0.0;
		j.tipo_pase = DEC_NADA;
		j.clip_arquero = -1;
		j.remata_prueba = false;
		j.entra = false;
		j.entrada_hasta = -1;
		j.regate = j.regate_elegido = -1;
		j.amagado_hasta = -1;
	}
	_regate_de_id = -1;
	_parada = Parada();
	if (modo == PARTIDO) {
		_armar_mundo();
	}
	if (reglas && modo == PARTIDO) {
		// Etapa 6: el saque inicial lo ejecuta uno que llega a la pelota.
		_empezar_reglas();
	} else {
		_reiniciar(0, 0.0, modo == RONDO ? -h : 0.0);
	}
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
	_en_manos = -1;
	_remate = Remate();
	_ultimo_resultado = -1;
	for (JugadorCanchita &j : jugadores) {
		j.toque_pendiente = false;
		j.persigue = false;
		j.pensar_ya = true;
	}
	_nueva_trayectoria();
	_visto_paso = paso;
	for (size_t i = 0; i < jugadores.size(); i++) {
		_alcance(int(i), 1.0, _k_llega[i], _t_llega[i]);
	}
	_analizar();
}

void Canchita::avanzar() {
	paso++;
	_cambio = false;
	bool con_reglas = reglas && modo == PARTIDO;
	if (con_reglas && periodo == TERMINADO) {
		// Terminó: cada uno frena donde está y la pelota sigue con la física.
		for (size_t i = 0; i < jugadores.size(); i++) {
			int clip_antes = jugadores[i].cuerpo.clip;
			jugadores[i].cuerpo.paso(param_cuerpo, clips, PASO_SEG);
			if (jugadores[i].arquero && (jugadores[i].cuerpo.eventos & TERMINA_ACCION)) {
				_levantarse(int(i), clip_antes);
			}
		}
		if (_en_manos < 0) {
			pelota.avanzar();
		}
		_desgastar();
		return;
	}
	_pensar();
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		int clip_antes = j.cuerpo.clip;
		j.rapidez_previa = j.cuerpo.rapidez();
		j.cuerpo.paso(param_cuerpo, clips, PASO_SEG);
		if (j.arquero && (j.cuerpo.eventos & TERMINA_ACCION)) {
			_levantarse(int(i), clip_antes);
		}
	}
	_separar_cuerpos();
	// En las manos del arquero la pelota no es de la física: va con él hasta
	// que la suelta (etapa 5).
	// Etapa 6: el lateral también va en las manos hasta que sale.
	bool lateral = con_reglas && _parada.activa && _parada.en_manos;
	bool en_manos = _en_manos >= 0 || lateral;
	uint32_t eventos = 0;
	if (lateral) {
		_llevar_lateral();
	} else if (en_manos) {
		_llevar_en_manos();
	} else {
		eventos = pelota.avanzar();
	}
	V3 fisica = pelota.vel;
	bool tocada = _resolver_toques();
	tocada = _rebotes() || tocada;
	// Detector de la etapa 3: la pelota solo cambia por la física o por un
	// toque. Nada más la puede corregir.
	if (!en_manos && !tocada && (pelota.vel.x != fisica.x || pelota.vel.y != fisica.y || pelota.vel.z != fisica.z)) {
		cuenta.correcciones++;
	}
	if (_remate.activo && (eventos & (PALO | TRAVESANO))) {
		_remate.palo = true;
	}
	_reglas();
	_cerrar_regate();
	// La predicción llega a HORIZONTE pasos (5 s). Si en ese tiempo nadie
	// toca la pelota y sigue moviéndose, hay que rehacerla: todos iban al
	// último punto previsto, le pegaban al aire a 7 m de la pelota y el
	// partido quedaba trabado (un pase largo que rodó más de 5 s).
	if (_cambio || paso - _tray_paso >= HORIZONTE - TRAYECTORIA_MARGEN) {
		_nueva_trayectoria();
	}
	_medir();
	if (con_reglas) {
		_desgastar();
		// El reloj espera en las pelotas paradas (y en el festejo, que es la
		// parada del saque del medio).
		if (_parada.activa) {
			_pasos_parados++;
		}
	}
}

// --- Cerebro sencillo ---

void Canchita::_pensar() {
	bool vio = paso >= _visto_paso;
	if (modo == PARTIDO) {
		_armar_mundo();
	}
	if (paso % PASOS_POR_TURNO == 0) {
		if (modo == PARTIDO) {
			cerebro.planificar(_mundo);
		}
		_analizar();
	}
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		bool turno = (paso + int64_t(i)) % PASOS_POR_TURNO == 0;
		// El arquero con un remate encima piensa en cada paso hasta tirarse:
		// esperando su turno (hasta 0,1 s) y la reacción de los demás
		// (reaccion_seg) planeaba 0,27 s después de la patada aunque sus
		// reflejos dieran 0,2 s, y a 13 m ya no llegaba a estirarse.
		bool atajando = j.arquero && _k_cruce[j.equipo & 1] >= 0 && j.cuerpo.clip < 0 && j.toque != TOQUE_ATAJADA;
		if (j.pensar_ya || atajando || (turno && (vio || int(i) == ultimo_toque))) {
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
	// Lo que tarda el más rápido de cada equipo (etapa 5: el arquero sale solo
	// si le gana a ese).
	double t_min[2] = { 1e9, 1e9 };
	for (size_t i = 0; i < jugadores.size(); i++) {
		const JugadorCanchita &j = jugadores[i];
		if (paso - j.pateo_en >= DESCANSO_PATEADOR) {
			t_min[j.equipo & 1] = std::min(t_min[j.equipo & 1], _t_llega[i]);
		}
	}
	for (int e = 0; e < 2; e++) {
		int mejor = -1;
		for (size_t i = 0; i < jugadores.size(); i++) {
			const JugadorCanchita &j = jugadores[i];
			if (j.equipo != e || paso - j.pateo_en < DESCANSO_PATEADOR) {
				continue;
			}
			if (_pase_activo && int(i) == _pateador && _receptor >= 0 && _receptor != int(i)
					&& paso - j.pateo_en < DESCANSO_PASE_PROPIO) {
				continue;
			}
			// Etapa 5: el arquero sale solo a la pelota que alcanza en su área
			// (con las manos) y si le gana al rival más rápido por lo que le
			// cuesta dejar el arco (MotorEspacial, ventaja_base y
			// ventaja_por_metro). En la etapa 4 iba a cualquiera y dejaba el arco
			// solo; sin la ventaja, salía a buscar la pelota que el delantero
			// tenía en el área y le pateaban con él corriendo.
			if (j.arquero && int(i) != poseedor) {
				V3 donde = _k_llega[i] >= 0 && !trayectoria.pos.empty()
						? trayectoria.pos[size_t(std::min(_k_llega[i], int(trayectoria.pos.size()) - 1))]
						: pelota.pos;
				double sale = std::abs(donde.x + _ataca(j.equipo) * param_pelota.medio_largo);
				double ventaja = param_arquero.ventaja_base + param_arquero.ventaja_por_metro * sale;
				if (!_es_mi_area(int(i), donde.x, donde.z) || _t_llega[i] + ventaja > t_min[1 - e]) {
					continue;
				}
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
	if (_pase_activo && !(_pase_centro && cerebro.pesos.centro_al_que_llega > 0.0) && _receptor >= 0
			&& jugadores[size_t(_receptor)].equipo == p && _perseguidor[p] >= 0
			&& _perseguidor[p] != _receptor
			&& _t_llega[size_t(_receptor)] < _t_llega[size_t(_perseguidor[p])] + 0.5) {
		_perseguidor[p] = _receptor;
	}
	// Rondo: después de un corte nadie va a la pelota hasta el reinicio.
	if (modo == RONDO && _reinicio_en >= 0) {
		_perseguidor[0] = _perseguidor[1] = -1;
	}
	// Partido: con la pelota controlada sale el presionante del plan de
	// defensa, no el que llega primero (ese puede ser el que cubre).
	if (modo == PARTIDO && poseedor >= 0 && !reinicio) {
		int defiende = 1 - jugadores[size_t(poseedor)].equipo;
		int presiona = cerebro.presionante(defiende);
		if (presiona >= 0) {
			_perseguidor[defiende] = presiona;
		}
	}
	// El que tiene la pelota del rival al lado también va, aunque el plan de
	// defensa mande a otro: el que la perdía a dos metros se volvía a su
	// puesto y la dejaba ir (revisión visual de la etapa 7).
	_segundo[0] = _segundo[1] = -1;
	if (modo == PARTIDO && poseedor >= 0 && !reinicio) {
		int defiende = 1 - jugadores[size_t(poseedor)].equipo;
		double mejor_t = cerebro.pesos.contrapresion_seg;
		// Jugada "presión tras pérdida": mientras el rival sale de la
		// recuperación, el segundo hombre va desde más lejos.
		if (cerebro.planes[defiende & 1].contrapresion > 0.0 && cerebro.transicion_de(_mundo, 1 - defiende) > 0.0) {
			mejor_t *= 1.0 + cerebro.planes[defiende & 1].contrapresion;
		}
		// Presión alta: con la pelota en campo rival aprietan dos, siempre.
		// En partidos parejos recuperaba a 41 m de su fondo, igual que los
		// otros cinco estilos (tests/_diag_identidad_v2.gd).
		if (cerebro.planes[defiende & 1].presion_alta && pelota.pos.x * _ataca(defiende) > 0.0) {
			mejor_t *= 1.0 + cerebro.pesos.presion_alta_segundo;
		}
		for (size_t i = 0; i < jugadores.size(); i++) {
			const JugadorCanchita &j = jugadores[i];
			if (j.equipo != defiende || j.arquero || int(i) == _perseguidor[defiende]) {
				continue;
			}
			if (_t_llega[i] < mejor_t) {
				mejor_t = _t_llega[i];
				_segundo[defiende] = int(i);
			}
		}
	}
	// Al centro salta uno más por equipo: el que lo tiene más a tiro. Con uno
	// solo yendo a la pelota, el centro pasaba a un metro de los demás y nadie
	// saltaba (revisión visual de la etapa 7: "no cabecean"). Saltando todos
	// los que lo tenían a tiro, en el 36% de los córners quedaban tres o más
	// compañeros a 1,5 m de la pelota, encimados y saltando a la vez (BUG-011,
	// 400 córners, semilla 97000); con uno más, en el 10%.
	// Probado y descartado: que el segundo no vaya al punto del primero (a
	// menos de 1,5 m). Baja al 2%, pero los cabezazos al arco pasan del 40% al
	// 25% de los córners y los goles del 2,8% al 4,8%.
	if (_pase_activo && _pase_centro && cerebro.pesos.centro_al_que_llega > 0.0 && poseedor < 0) {
		double cerca[2] = { CENTRO_A_TIRO_M, CENTRO_A_TIRO_M };
		for (size_t i = 0; i < jugadores.size(); i++) {
			const JugadorCanchita &j = jugadores[i];
			int e = j.equipo & 1;
			if (j.arquero || int(i) == _pateador || int(i) == _perseguidor[e] || _k_llega[i] < 0
					|| _k_llega[i] >= int(trayectoria.pos.size()) - 1) {
				continue;
			}
			const V3 &q = trayectoria.pos[size_t(_k_llega[i])];
			double d = hipot(q.x - j.cuerpo.x, q.z - j.cuerpo.z);
			if (q.y >= param_toque.pecho_hasta && d <= cerca[e]) {
				cerca[e] = d;
				_segundo[e] = int(i);
			}
		}
	}
	// Etapa 6: en una parada nadie va a la pelota; cuando saca, solo el que saca.
	if (reglas && modo == PARTIDO && (_parada.activa || periodo >= TANDA)) {
		_perseguidor[0] = _perseguidor[1] = -1;
		_segundo[0] = _segundo[1] = -1;
		if (_parada.activa && _parada.sacando && _parada.ejecutor >= 0) {
			_perseguidor[_parada.equipo & 1] = _parada.ejecutor;
		}
	}
}

// El primer punto de la trayectoria al que llega a tiempo corriendo a
// `factor` de su punta, y en cuántos segundos. La pelota más alta que la
// cabeza no cuenta. Si no llega a ninguno, el último.
void Canchita::_alcance(int i, double factor, int &k, double &t, int no_antes) const {
	const Cuerpo &c = jugadores[size_t(i)].cuerpo;
	int n = int(trayectoria.pos.size());
	if (n == 0) {
		k = -1;
		t = tiempo_de_llegada(c, pelota.pos.x, pelota.pos.z, ALCANCE_PLAN_M, factor);
		return;
	}
	int desde = std::max(0, _indice_tray(paso + 1 + no_antes));
	desde = std::min(desde, std::max(n - 1, 0));
	// Afuera ya no se juega: el que va la tiene que alcanzar antes. Sin esto
	// el receptor del rondo trotaba a buscarla afuera del cuadrado (15% de
	// los pases se iban).
	double adentro = modo == RONDO ? RONDO_AFUERA_M - 0.5 : -0.2;
	// Partido: de a SALTO_ALCANCE puntos y, al encontrar uno, se busca hacia
	// atrás el primero. Con 22 jugadores recorrer los 300 puntos uno por uno
	// era el 45% del costo del paso (tests/_diag_cerebro_v2.gd); en la
	// canchita chica se sigue de a uno.
	const int salto = modo == PARTIDO ? SALTO_ALCANCE : 1;
	// El arquero en su área la juega con las manos: hasta donde cree que
	// llegan (ver _alto_que_cree_alcanzar). Con la cabeza de los demás
	// (1,8 m) salía a centros que pasaban 0,3 m por arriba de las manos.
	const bool arquero = jugadores[size_t(i)].arquero;
	const double manos = arquero ? _alto_que_cree_alcanzar(i) : 0.0;
	auto llega = [&](int q, double &tq) {
		const V3 &p = trayectoria.pos[size_t(q)];
		double tope = arquero && _es_mi_area(i, p.x, p.z) ? manos : param_toque.cabeza_hasta;
		if (p.y > tope) {
			return false;
		}
		tq = double(_tray_paso + q + 1 - paso) * PASO_SEG;
		return tiempo_de_llegada(c, p.x, p.z, ALCANCE_PLAN_M, factor) <= tq;
	};
	for (int q = desde; q < n; q += salto) {
		const V3 &p = trayectoria.pos[size_t(q)];
		if (!_adentro(p.x, p.z, adentro)) {
			n = std::max(q, desde + 1);
			break;
		}
		double tq;
		if (llega(q, tq)) {
			for (int atras = std::max(desde, q - salto + 1); atras < q; atras++) {
				double ta;
				if (llega(atras, ta)) {
					k = atras;
					t = ta;
					return;
				}
			}
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
	// Etapa 5. Con la pelota en las manos el arquero espera para soltarla.
	if (_en_manos == i) {
		j.persigue = false;
		j.toque = TOQUE_NADA;
		j.cuerpo.ir_a(j.cuerpo.x, j.cuerpo.z, 0.3, true);
		return;
	}
	// Etapa 6: en una parada cada uno va a su lugar; el que está en el piso no
	// juega; en la tanda solo juega el arquero.
	if (reglas && modo == PARTIDO) {
		if (_parada.activa && _pensar_en_parada(i)) {
			return;
		}
		bool ataja = j.arquero && _k_cruce[j.equipo & 1] >= 0;
		bool saca = _parada.activa && _parada.sacando && i == _parada.ejecutor;
		if (paso < j.en_el_piso_hasta || periodo == TERMINADO || (periodo == TANDA && !ataja && !saca)) {
			j.persigue = false;
			j.toque = TOQUE_NADA;
			j.cuerpo.ir_a(j.cuerpo.x, j.cuerpo.z, 0.3, true);
			return;
		}
	}
	// Festejo del gol: todos a su mitad para el saque del medio.
	if (_saque_medio_en >= 0) {
		j.persigue = false;
		j.toque = TOQUE_NADA;
		_ubicar(i);
		return;
	}
	// El remate que va a su arco manda sobre todo lo demás. Hasta que lo lee
	// se queda en su lugar: siguiendo el plan de antes (salir a buscar la
	// pelota) arrancaba un gesto equivocado y cuando reaccionaba ya no podía
	// tirarse.
	if (j.arquero && _k_cruce[j.equipo & 1] >= 0) {
		if (!_plan_atajar(i)) {
			j.persigue = false;
			j.toque = TOQUE_NADA;
			_ubicar(i);
		}
		return;
	}
	// Se comió un amague: sigue de largo hacia donde se tiró (_amagar).
	if (paso < j.amagado_hasta) {
		return;
	}
	// En el partido el cerebro decide cuánta ventaja pide para tirarse
	// (cerebro.pesos.entrada_ventaja_seg).
	double gana = modo == PARTIDO ? cerebro.pesos.entrada_ventaja_seg : GANA_CARRERA_SEG;
	bool contiene = j.equipo != equipo_con_pelota && poseedor >= 0
			&& jugadores[size_t(poseedor)].equipo == equipo_con_pelota
			&& _t_llega[size_t(i)] > _t_llega[size_t(poseedor)] - gana;
	bool va = _perseguidor[j.equipo] == i || _segundo[j.equipo] == i;
	if (va && contiene) {
		// La tiene controlada otro y no le gana de mano: se para delante y
		// espera el error (o el pase), no se tira a ciegas. Etapa 6: de cerca,
		// a veces se tira igual (una entrada, que puede ser falta).
		if (reglas && modo == PARTIDO && paso < j.entrada_hasta) {
			// Ya se decidió a tirarse: sigue hasta el gesto.
			j.entra = true;
			_plan_tocar(i);
			j.entra = false;
		} else if (!(reglas && modo == PARTIDO && _plan_entrada(i))) {
			j.persigue = false;
			j.toque = TOQUE_NADA;
			_contener(i);
		}
	} else if (_prueba() && i == poseedor) {
		// En la prueba el que la controla no sigue jugando.
		j.persigue = false;
		j.toque = TOQUE_NADA;
		_ubicar(i);
	} else if (va || i == poseedor) {
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
	double factor = disputada ? 1.0 : (poseedor_ ? param_toque.conduccion_factor * j.ritmo_conduce : FACTOR_RECIBIR);
	int k;
	double t;
	// El que conduce no puede volver a tocarla hasta que termina el gesto de
	// ahora y llega el contacto del siguiente. Sin esto el punto de encuentro
	// era la pelota recién tocada, a sus pies: clavaba los frenos (de 6,5 a
	// 4,3 m/s en 0,2 s), la pelota se le iba a 2 o 3 m y picaba a buscarla.
	// En la revisión visual de la etapa 7: "adelantan la pelota como un pase
	// y la van a buscar a full".
	int no_antes = 0;
	if (poseedor_ && param_toque.clip_conduce >= 0) {
		double falta = c.clip >= 0 ? std::max(clips[size_t(c.clip)].duracion - c.tiempo_accion, 0.0) : 0.0;
		// El regate que ya decidió tarda más en llegar a su contacto.
		falta += std::max(clips[size_t(_clip_conduce_de(j))].contacto_seg, 0.0);
		no_antes = int(falta / PASO_SEG + 0.5);
	}
	j.regate = -1;
	_alcance(i, factor, k, t, no_antes);
	// Si sin apurarse la alcanza recién lejos (o no la alcanza), va a fondo
	// y la toma antes. Detrás de un pelotazo que rodaba a 5 m/s el más
	// cercano la seguía a 3 m, a la misma rapidez, 5 segundos sin tocarla
	// (93 pelotas sueltas de más de 2,5 s en 36 minutos).
	// Solo con la pelota que se aleja de él: a la que viene la espera en su
	// punto (y la recibe con el pecho o la cabeza si llega alta).
	bool se_aleja = pelota.vel.x * (pelota.pos.x - c.x) + pelota.vel.z * (pelota.pos.z - c.z) > 0.0;
	if (factor < 1.0 && !poseedor_ && se_aleja && (k == int(trayectoria.pos.size()) - 1 || t > ENCUENTRO_LEJOS_SEG)) {
		_alcance(i, 1.0, k, t, no_antes);
		factor = 1.0;
	} else if (factor < 1.0 && k == int(trayectoria.pos.size()) - 1) {
		_alcance(i, 1.0, k, t, no_antes);
	}
	V3 p = k >= 0 ? trayectoria.pos[size_t(k)] : pelota.pos;
	V3 vp = k >= 0 ? trayectoria.vel[size_t(k)] : pelota.vel;

	j.toque = j.entra ? TOQUE_ENTRADA : TOQUE_CONTROL;
	j.rapidez_pase = 0.0;
	j.tipo_pase = DEC_NADA;
	int corredor_pared = -1;
	double retorno_x = 0.0, retorno_z = 0.0;
	bool devuelve_pared = modo == PARTIDO && ataca && _pase_activo && p.y <= param_toque.pie_hasta
			&& cerebro.muro_de_pared(_mundo, corredor_pared, retorno_x, retorno_z) == i;
	if (poseedor_ && ataca && p.y <= param_toque.pie_hasta) {
		_decidir(i, p, t);
	} else if (j.toque == TOQUE_ENTRADA) {
		// Etapa 6: va con la pierna estirada (el clip de la entrada).
	} else if (j.arquero && !ataca && _es_mi_area(i, p.x, p.z)) {
		// Etapa 5: en su área la pelota del rival la agarra con las manos (a la
		// que le pasa un compañero no: la juega con el pie).
		int a = p.y <= param_toque.pie_hasta ? ATAJA_ABAJO : (p.y <= param_toque.pecho_hasta ? ATAJA_AGARRA : ATAJA_ARRIBA);
		if (param_arquero.clips[a] >= 0) {
			j.toque = TOQUE_ATAJADA;
			j.clip_arquero = a;
		}
	} else if (ataca && !poseedor_ && !devuelve_pared && _decidir_remate_de_primera(i, p, t)) {
		// Etapa 5: le pega de primera al arco (de pie, de volea o de cabeza).
	} else if (devuelve_pared) {
		// El muro de la pared la devuelve de primera al que sale a buscarla.
		Decision d;
		d.tipo = DEC_PASE_HUECO;
		d.receptor = corredor_pared;
		d.tiene_punto = true;
		d.x = retorno_x;
		d.z = retorno_z;
		Pase pase = _pase_a(i, p, t, d);
		if (pase.hay) {
			j.toque = TOQUE_PASE;
			j.meta_x = pase.x;
			j.meta_z = pase.z;
			j.receptor = pase.receptor;
			j.globo = pase.globo;
			j.rapidez_pase = pase.rapidez;
			j.tipo_pase = DEC_PASE_HUECO;
		}
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
	int clip = j.toque == TOQUE_ATAJADA ? param_arquero.clips[j.clip_arquero] : _clip_para(j, p.y);
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
	if (j.toque == TOQUE_PASE || j.toque == TOQUE_CONDUCE || j.toque == TOQUE_REMATE || j.toque == TOQUE_ENTRADA) {
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
	double f = disputada || factor >= 1.0 ? 1.0 : std::clamp(necesita, 0.25, 1.0);
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
	// De frente a la pelota que viene, con el pie en el punto. Al espacio pica
	// a fondo: la rapidez del pase se calculó con él corriendo a su punta.
	double factor = modo == PARTIDO && _pase_al_espacio ? 1.0 : FACTOR_RECIBIR;
	r.cuerpo.ir_a(jp.meta_x + dx / l * ALCANCE_PLAN_M, jp.meta_z + dz / l * ALCANCE_PLAN_M, factor, true);
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
	if (modo == PARTIDO) {
		_decidir_partido(i, bola, t_patada);
		return;
	}
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
	double espacio = _espacio_adelante(i, bola, j.dir_x, j.dir_z);
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
Canchita::Pase Canchita::_planear_pase(int i, V3 bola, double t_patada, int solo) {
	const JugadorCanchita &j = jugadores[size_t(i)];
	Pase mejor;
	for (size_t r = 0; r < jugadores.size(); r++) {
		const JugadorCanchita &jr = jugadores[r];
		if (int(r) == i || jr.equipo != j.equipo || (solo >= 0 && int(r) != solo)) {
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
double Canchita::_rapidez_globo(double d, int &k, bool centro) {
	// El centro (etapa 7) va tendido: sale a centro_elevacion_rad y llega al
	// punto a la altura de la cabeza, bajando despacio. Con el globo de
	// siempre (34 grados) el córner subía a 7-9 m, caía casi vertical, pasaba
	// por la altura de la cabeza en 0,1 s y picaba en el piso: en 200 córners
	// lo tocaba primero el que ataca el 11% y salía un cabezazo al arco cada
	// 20 (tests/_diag_corners_v2.gd).
	bool tendido = centro && cerebro.pesos.centro_elevacion_rad > 0.0 && cerebro.pesos.centro_alto_m > 0.0;
	double llegada = tendido ? cerebro.pesos.centro_alto_m : param_toque.pecho_hasta;
	double sobre = tendido ? cerebro.pesos.centro_alto_m : param_toque.cabeza_hasta;
	int tipo = tendido ? Perfiles::CENTRO : Perfiles::GLOBO;
	int desde = int(6.0 / Perfiles::PASO_RAPIDEZ + 0.5);
	int hasta = int((tendido ? CENTRO_MAX_MS : param_toque.pase_max_ms) / Perfiles::PASO_RAPIDEZ + 0.5);
	for (int iv = desde; iv <= hasta; iv++) {
		const Perfil &p = _perfiles.de(Perfiles::rapidez_de(iv), tipo);
		bool arriba = false;
		for (size_t q = 0; q < p.alto.size(); q++) {
			if (p.alto[q] > sobre) {
				arriba = true;
			} else if (arriba && p.alto[q] <= llegada) {
				if (p.dist[q] >= d - 0.5) {
					k = int(q);
					return Perfiles::rapidez_de(iv);
				}
				break;
			}
		}
	}
	if (tendido) {
		// Tendido no llega tan lejos: va el globo.
		return _rapidez_globo(d, k, false);
	}
	k = -1;
	return -1.0;
}

// Que la pelota se le adelante `largo` metros al que corre a `corre` m/s y
// después la alcance. Con `alcanza_seg`, además recorre `alcanza_m` en ese
// tiempo: no queda detrás del que todavía no terminó de frenar.
double Canchita::_rapidez_conduce(double corre, double largo, double alcanza_m, double alcanza_seg) {
	size_t q_alcanza = size_t(std::max(alcanza_seg / PASO_SEG - 0.5, 0.0));
	for (int iv = 2; iv <= 40; iv++) {
		double v = Perfiles::rapidez_de(iv);
		const Perfil &p = _perfiles.de(v, false);
		double adelante = 0.0;
		for (size_t q = 0; q < p.dist.size(); q++) {
			adelante = std::max(adelante, p.dist[q] - corre * double(q + 1) * PASO_SEG);
		}
		if (adelante >= largo && (alcanza_seg <= 0.0 || p.dist.empty() || p.dist[std::min(q_alcanza, p.dist.size() - 1)] >= alcanza_m)) {
			return v;
		}
	}
	return Perfiles::rapidez_de(40);
}

// Cuánto lugar hay para adelantarse la pelota hacia (dx, dz), de 0 a 1. El
// rival que está adelante cuenta desde el doble de lejos que el de atrás: la
// pelota va hacia él y él viene. Con solo la distancia (lleno a 6 m), el que
// controlaba corriendo se la adelantaba a un rival que venía de frente a 7-10 m
// y se la sacaba en 0,6 s (tests/_diag_sensaciones_v2.gd).
double Canchita::_espacio_adelante(int i, V3 bola, double dx, double dz) const {
	int equipo = jugadores[size_t(i)].equipo;
	double cerca = 1e9;
	for (const JugadorCanchita &o : jugadores) {
		if (o.equipo == equipo) {
			continue;
		}
		double ex = o.cuerpo.x - bola.x, ez = o.cuerpo.z - bola.z;
		double d = hipot(ex, ez);
		bool adelante = d > 1e-6 && (ex * dx + ez * dz) / d > 0.3;
		cerca = std::min(cerca, adelante ? d : d * 2.0);
	}
	return std::clamp((cerca - 4.0) / 8.0, 0.0, 1.0);
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
	bool frenar = true;
	if (modo == PARTIDO) {
		_ubicar_partido(i, qx, qz, factor, frenar);
	} else if (modo == RONDO) {
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
	} else if (_prueba()) {
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
	// En un reinicio los rivales se alejan (etapa 6: lo reglamentario de cada
	// parada, desde donde se repone la pelota).
	if (paso < _reinicio_hasta && j.equipo != equipo_con_pelota) {
		bool parada = reglas && modo == PARTIDO && _parada.activa;
		double lejos = parada ? _distancia_parada(i) : REINICIO_DISTANCIA_M;
		V3 punto = parada ? V3{ _parada.x, 0.0, _parada.z } : bola;
		double d = hipot(qx - punto.x, qz - punto.z);
		if (d < lejos) {
			double ux = d > 1e-6 ? (qx - punto.x) / d : -_ataca(j.equipo);
			double uz = d > 1e-6 ? (qz - punto.z) / d : 0.0;
			// El que ya está cerca se aleja derecho desde donde está parado, y
			// también el que por su objetivo se iría afuera de la cancha. En el
			// lateral el que marca al que saca va a la pelota, que está en las
			// manos, a 0,2 m del punto y a veces afuera de la raya: el lado al
			// que se alejaba cambiaba con ese 0,2 m, cruzaba por el punto y el
			// recorte de abajo lo dejaba en la raya, al lado del que saca. 80
			// partidos de quinta, semilla 97000: a menos de 1,9 m del punto en
			// el 41% de los laterales y a menos de 1,5 m en el 13%.
			double bx = c.x - punto.x, bz = c.z - punto.z;
			double lb = hipot(bx, bz);
			bool afuera = std::abs(punto.x + ux * lejos) > _medio_x() || std::abs(punto.z + uz * lejos) > _medio_z();
			if (lb > 1e-6 && (afuera || lb < lejos + param_reglas.llegada_m)) {
				ux = bx / lb;
				uz = bz / lb;
			}
			qx = punto.x + ux * lejos;
			qz = punto.z + uz * lejos;
		}
		if (parada && _parada.tipo == SAQUE_ARCO && !j.arquero) {
			// En el saque de arco los rivales esperan afuera del área.
			double propio = -Cerebro::MEDIO_LARGO * _ataca(_parada.equipo);
			if (std::abs(qx - propio) <= Cerebro::AREA_LARGO + 0.5 && std::abs(qz) <= Cerebro::AREA_MEDIO_ANCHO + 0.5) {
				qx = propio + _ataca(_parada.equipo) * (Cerebro::AREA_LARGO + 1.0);
			}
		}
	}
	qx = std::clamp(qx, -_medio_x() - 0.5, _medio_x() + 0.5);
	qz = std::clamp(qz, -_medio_z() - 0.5, _medio_z() + 0.5);
	c.ir_a(qx, qz, factor, frenar);
	// En el partido el que se acomoda cerca llega sin apuro (el arquero no:
	// su lugar en la línea decide si llega a la pelota). Solo a menos de
	// ACOMODA_SUAVE_M: con todos los que se acomodan frenando suave, el que
	// volvía a defender llegaba tarde y había 40% más de goles (15,7 contra
	// 11,2 en 40 minutos, tests/_diag_reglas_v2.gd).
	c.suave = modo == PARTIDO && !j.arquero && hipot(qx - c.x, qz - c.z) < ACOMODA_SUAVE_M;
	c.mira = true;
	c.mira_x = bola.x;
	c.mira_z = bola.z;
}

// `control`: la franja del que recibe, con el pecho hasta pecho_control_hasta.
void Canchita::_franja(Parte parte, double &desde, double &hasta, bool control) const {
	double pecho = control ? std::max(param_toque.pecho_hasta, param_toque.pecho_control_hasta) : param_toque.pecho_hasta;
	const double limites[5] = { 0.0, param_toque.pie_hasta, param_toque.muslo_hasta, pecho, param_toque.cabeza_hasta };
	int k = std::clamp(int(parte), 0, 3);
	desde = limites[k];
	hasta = limites[k + 1];
}

int Canchita::_clip_de_parte(const JugadorCanchita &j, Parte parte) const {
	if (j.toque == TOQUE_ATAJADA) {
		return j.clip_arquero >= 0 ? param_arquero.clips[j.clip_arquero] : -1;
	}
	if (j.toque == TOQUE_REMATE) {
		// De cabeza: parado (Cabecear) o tirándose de palomita a la pelota más
		// baja. De pie: el empeine, o de volea a la altura del muslo.
		if (j.golpe_remate == REMATE_CABEZA) {
			return parte == CABEZA ? param_remate.clip_cabeza : (parte == PECHO ? param_remate.clip_palomita : -1);
		}
		if (parte == PIE) {
			return j.golpe_remate == REMATE_EFECTO && param_remate.clip_efecto >= 0 ? param_remate.clip_efecto
																				 : param_remate.clip_pie;
		}
		return parte == MUSLO ? param_remate.clip_volea : -1;
	}
	if (j.toque == TOQUE_PASE) {
		return param_toque.clip_pase;
	}
	if (j.toque == TOQUE_ENTRADA) {
		return parte == PIE ? param_reglas.clip_entrada : -1;
	}
	if (j.toque == TOQUE_CONDUCE) {
		return _clip_conduce_de(j);
	}
	return parte == NINGUNA ? -1 : param_toque.clip_recepcion[parte];
}

// El gesto del toque de conducción: el del regate que está planeando o el de
// siempre.
int Canchita::_clip_conduce_de(const JugadorCanchita &j) const {
	return j.regate >= 0 && param_toque.clips_regate[j.regate] >= 0 ? param_toque.clips_regate[j.regate]
																	: param_toque.clip_conduce;
}

// El amague del regate: arranca el gesto y el rival al que encara se lo come
// o no. Pesan el control y la agilidad del que encara contra el quite y la
// agilidad del que marca, como en el duelo del motor espacial
// (_resolver_gambeta). Nadie adjudica la pelota: el que se lo come se tira
// hacia el lado contrario al de la salida y hasta amagado_hasta no va a la
// pelota. El que no se lo come sigue jugando y se la puede sacar.
void Canchita::_amagar(int i, int clip) {
	JugadorCanchita &j = jugadores[size_t(i)];
	cuenta.regates++;
	int r = j.decision.rival;
	if (r < 0 || r >= int(jugadores.size()) || jugadores[size_t(r)].equipo == j.equipo
			|| cerebro.fichas.size() != jugadores.size()) {
		return;
	}
	JugadorCanchita &jr = jugadores[size_t(r)];
	const FichaCerebro &fa = cerebro.fichas[size_t(i)];
	const FichaCerebro &fd = cerebro.fichas[size_t(r)];
	double habilidad = fa.bruto[AT_CONTROL] * 0.7 + fa.bruto[AT_AGILIDAD] * 0.3;
	double marca = fd.bruto[AT_QUITE] * 0.7 + fd.bruto[AT_AGILIDAD] * 0.3;
	double pica = std::clamp(param_toque.regate_pica_base + param_toque.regate_pica_por_punto * (habilidad - marca), 0.05,
			0.95);
	if (jr.cuerpo.clip >= 0 || paso < jr.en_el_piso_hasta || _azar.uno() >= pica) {
		return;
	}
	cuenta.regates_amague++;
	const Clip &k = clips[size_t(clip)];
	jr.amagado_hasta = paso + int64_t((std::max(k.contacto_seg, 0.0) + param_toque.regate_pasado_seg) / PASO_SEG + 0.5);
	// Hacia el lado contrario al de la salida, visto desde el que encara.
	double ux = jr.cuerpo.x - j.cuerpo.x, uz = jr.cuerpo.z - j.cuerpo.z;
	double l = std::max(hipot(ux, uz), 1e-6);
	ux /= l;
	uz /= l;
	double a_lo_largo = j.dir_x * ux + j.dir_z * uz;
	double lx = j.dir_x - ux * a_lo_largo, lz = j.dir_z - uz * a_lo_largo;
	double ll = hipot(lx, lz);
	if (ll > 1e-6) {
		jr.cuerpo.ir_a(jr.cuerpo.x - lx / ll * param_toque.regate_pica_m, jr.cuerpo.z - lz / ll * param_toque.regate_pica_m,
				1.0, true);
	}
	jr.persigue = false;
	jr.toque = TOQUE_NADA;
	_regate_de_id = _id(i);
	_regate_rival_id = _id(r);
	_regate_tipo = j.regate;
	_regate_equipo = j.equipo;
	_regate_hasta = jr.amagado_hasta;
}

// El regate sirvió si, cuando el rival vuelve a jugar, la pelota sigue en el
// equipo del que encaró y el juego no se paró.
void Canchita::_cerrar_regate() {
	if (_regate_de_id < 0 || paso < _regate_hasta) {
		return;
	}
	if (equipo_con_pelota == _regate_equipo && !(reglas && _parada.activa) && _saque_medio_en < 0) {
		cuenta.regates_ganados++;
		if (reglas && modo == PARTIDO) {
			_anotar(EV_REGATE, _regate_equipo, _regate_de_id, _regate_rival_id, _regate_tipo, pelota.pos.x, pelota.pos.z);
		}
	}
	_regate_de_id = -1;
}

// La parte con que la toca a esta altura: la del que recibe va con el pecho
// hasta pecho_control_hasta.
Parte Canchita::_parte_de(const JugadorCanchita &j, double alto) const {
	if (j.toque != TOQUE_CONTROL) {
		return parte_para(param_toque, alto);
	}
	ParametrosToque p = param_toque;
	p.pecho_hasta = std::max(p.pecho_hasta, p.pecho_control_hasta);
	return parte_para(p, alto);
}

int Canchita::_clip_para(const JugadorCanchita &j, double alto) const {
	return _clip_de_parte(j, _parte_de(j, alto));
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
	if (!j.persigue || c.clip >= 0 || paso < j.amagado_hasta) {
		return;
	}
	if (paso < _reinicio_hasta && j.equipo != equipo_con_pelota) {
		return;
	}
	if (modo == RONDO && _reinicio_en >= 0) {
		return;
	}
	if (_en_manos >= 0 || _saque_medio_en >= 0) {
		return;
	}
	if (reglas && modo == PARTIDO
			&& ((_parada.activa && !(_parada.sacando && i == _parada.ejecutor)) || paso < j.en_el_piso_hasta)) {
		return;
	}
	// El clip depende de la parte con que la va a tocar, y la parte de la
	// altura de la pelota en su cuadro de contacto: se prueba la de dentro
	// de 8 pasos y, si en el contacto de ese clip la pelota queda en otra
	// franja, la de esa franja. Clip y parte van siempre juntos. El remate de
	// primera elige igual (empeine, volea o cabeza); el arquero ya eligió su
	// clip al planear la atajada.
	bool por_altura = j.toque == TOQUE_CONTROL || j.toque == TOQUE_REMATE;
	bool ataja = j.toque == TOQUE_ATAJADA;
	Parte parte = PIE;
	if (por_altura) {
		// Cada parte se prueba con la pelota en el cuadro de contacto de SU
		// clip, de arriba para abajo. Mirando siempre 8 pasos adelante (0,13 s),
		// el cabezazo (contacto a 0,29 s) arrancaba recién cuando la pelota
		// estaba por entrar a la franja de la cabeza: al contacto ya había
		// bajado al pecho o al pie. En 200 córners arrancaban 0,4 gestos de
		// cabeza por córner y la pelota rebotaba 1,4 veces en un cuerpo
		// (tests/_diag_corners_v2.gd).
		parte = NINGUNA;
		for (Parte candidata : { CABEZA, PECHO, MUSLO, PIE }) {
			int cc = _clip_de_parte(j, candidata);
			if (cc < 0) {
				continue;
			}
			double tcc = std::max(clips[size_t(cc)].contacto_seg, 0.0);
			if (_parte_de(j, _bola_en(paso + int64_t(tcc / PASO_SEG + 0.5)).y) == candidata) {
				parte = candidata;
				break;
			}
		}
		if (parte == NINGUNA) {
			return;
		}
	}
	int clip = _clip_de_parte(j, parte);
	if (clip < 0) {
		return;
	}
	double tolerancia = ataja ? _tolerancia(i, j.clip_arquero) : param_toque.tolerancia_m;
	if (j.toque == TOQUE_ENTRADA) {
		tolerancia = std::max(tolerancia, param_reglas.entrada_alcance_m);
	}
	double gatillo = ataja ? tolerancia * 0.5 : param_toque.gatillo_m;
	for (int vuelta = 0; vuelta < 2; vuelta++) {
		double tc = std::max(clips[size_t(clip)].contacto_seg, 0.0);
		V3 p = _bola_en(paso + int64_t(tc / PASO_SEG + 0.5));
		if (por_altura && vuelta == 0) {
			Parte otra = _parte_de(j, p.y);
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
				q = punto_de_contacto(luego, clips[size_t(clip)], _rumbo_contacto(j, luego, clip, c.rumbo, pt.x, pt.z));
				d[luego_de] = ataja ? _distancia_al_brazo(j, luego, q, pt, pt) : hipot(q.x - pt.x, q.z - pt.z);
				if (luego_de == 0) {
					p = pt;
				}
			}
			bool alto_ok;
			if (ataja) {
				alto_ok = p.y >= _alto_minimo(j.clip_arquero, clips[size_t(clip)])
						&& p.y <= clips[size_t(clip)].punto_y + _tolerancia_alto(j.clip_arquero, true);
			} else if (j.toque == TOQUE_CONTROL) {
				double desde, hasta;
				_franja(parte, desde, hasta, true);
				alto_ok = p.y >= desde - param_toque.tolerancia_alto_m && p.y <= hasta + param_toque.tolerancia_alto_m;
			} else if (j.toque == TOQUE_ENTRADA) {
				// La entrada va a la pelota del piso (el punto de Barrida es el
				// de la tibia, a 0,37 m: con su alto no tocaba ninguna).
				alto_ok = p.y <= param_toque.pie_hasta + param_toque.tolerancia_alto_m;
			} else if (clip == param_remate.clip_cabeza) {
				// El cabezazo al arco: en toda la franja de la cabeza (salta).
				alto_ok = p.y >= param_toque.pecho_hasta - param_toque.tolerancia_alto_m
						&& p.y <= param_toque.cabeza_hasta + param_toque.tolerancia_alto_m;
			} else {
				alto_ok = std::abs(clips[size_t(clip)].punto_y - p.y) <= param_toque.tolerancia_alto_m;
			}
			bool quietos = c.rapidez() < RAPIDEZ_QUIETO && hipot(pelota.vel.x, pelota.vel.z) < RAPIDEZ_QUIETO;
			// Arranca si va a quedar justo en la pelota, o si este es el mejor
			// momento (después se aleja) y queda al alcance: con la pelota a
			// 9 m/s pasando a medio metro, esperar el gatillo exacto la dejaba
			// pasar (en el rondo, la mitad de los pases que se iban afuera).
			bool mejor_ahora = d[0] <= d[1] && d[0] <= tolerancia;
			// El arquero se tira a tiempo aunque no vaya a llegar: esperando a
			// quedar justo, el remate ya estaba adentro cuando arrancaba.
			bool a_tiempo = ataja && paso + int64_t(tc / PASO_SEG + 0.5) >= j.paso_meta;
			// Saliendo a una pelota que no es un remate (un centro, un rebote)
			// se tira a tiempo solo si llega, o si calcula mal: el de poco
			// achique cree que llega desde salida_error_m más lejos. Se tiraban
			// todos a cualquier distancia, y en primera fallaban más salidas
			// (0,40 por partido) que las que tocaban (0,29). Revisión del
			// 2026-10-03: "le pasó por arriba; debería pasar cuando el golero
			// es malo".
			if (a_tiempo && !(_remate.activo && _remate.equipo != j.equipo)) {
				a_tiempo = d[0] <= tolerancia + segun_atributo(j.achique, param_arquero.salida_error_m, 0.0);
			}
			if ((alto_ok && (d[0] <= gatillo || mejor_ahora || (quietos && d[0] <= tolerancia))) || a_tiempo) {
				if (c.empezar(clip)) {
					j.clip_toque = clip;
					j.parte = parte;
					j.toque_pendiente = true;
					j.toque_d_min = 1e9;
					j.toque_alto_ok = false;
					j.alcanza = alto_ok && d[0] <= tolerancia;
					if (j.toque == TOQUE_CONDUCE && j.regate >= 0) {
						_amagar(i, clip);
					}
					if (ataja && !j.alcanza) {
						// La atajada se resuelve en toda la ventana del contacto, con
						// el tramo que recorre la pelota en cada paso (_resolver_toques):
						// mirando solo el cuadro del contacto, una de cada cinco
						// atajadas que sí tocaba quedaba sin las manos en la pelota.
						const Clip &kc = clips[size_t(clip)];
						int medio = int(param_cuerpo.ventana_contacto_seg * 0.5 / PASO_SEG + 0.5);
						int centro = int(tc / PASO_SEG + 0.5);
						for (int q_paso = std::max(centro - medio, 1); q_paso <= centro + medio && !j.alcanza; q_paso++) {
							V3 a = _bola_en(paso + q_paso - 1), b = _bola_en(paso + q_paso);
							Cuerpo luego = c;
							luego.x += c.vx * double(q_paso) * PASO_SEG;
							luego.z += c.vz * double(q_paso) * PASO_SEG;
							V3 mano = punto_de_contacto(luego, kc, _rumbo_contacto(j, luego, clip, c.rumbo, b.x, b.z));
							bool alto_tramo = std::max(a.y, b.y) >= _alto_minimo(j.clip_arquero, kc)
									&& std::min(a.y, b.y) <= kc.punto_y + _tolerancia_alto(j.clip_arquero, true);
							j.alcanza = alto_tramo && _distancia_al_brazo(j, luego, mano, a, b) <= tolerancia;
						}
					}
					if (por_altura) {
						cuenta.gestos_parte[std::clamp(int(parte), 0, 3)]++;
					}
					if (j.toque == TOQUE_ENTRADA) {
						cuenta.entradas++;
						j.entrada_hasta = -1;
					}
					if (ataja && _remate.activo && _remate.equipo != j.equipo && _remate.indice < registro.size()
							&& registro[_remate.indice].clip_arquero < 0) {
						registro[_remate.indice].clip_arquero = j.clip_arquero;
					}
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
	bool con_reglas = reglas && modo == PARTIDO;
	bool bloqueado = (modo == RONDO && _reinicio_en >= 0) || _en_manos >= 0 || _saque_medio_en >= 0
			|| (con_reglas && _parada.activa && !_parada.sacando);
	// Etapa 6: la entrada que no llega a la pelota pero sí a las piernas de un
	// rival (la primera de este paso).
	int falta_de = -1, falta_a = -1;
	double falta_gravedad = 0.0;
	auto gravedad = [&](int de, int a) {
		const JugadorCanchita &jd = jugadores[size_t(de)];
		const Cuerpo &cd = jd.cuerpo;
		const Cuerpo &ca = jugadores[size_t(a)].cuerpo;
		double v = std::max(cd.rapidez(), jd.rapidez_previa);
		// Desde atrás: el que entra va hacia donde mira el otro.
		double sa, ca_;
		mate::seno_coseno(ca.rumbo, sa, ca_);
		double atras = v > 0.1 ? std::clamp((cd.vx * sa + cd.vz * ca_) / std::max(cd.rapidez(), 0.1), 0.0, 1.0) : 0.0;
		// Contra la punta del que entra, no en m/s: con m/s el de décima, más
		// lento, casi no veía tarjetas (0,31 amarillas por falta contra 0,47
		// en primera; en el motor espacial 0,43 en las dos) y el favorito de
		// un partido desparejo las veía todas.
		return v / std::max(cd.vel_max, 0.1) * param_reglas.gravedad_a_fondo
				* (1.0 + param_reglas.gravedad_desde_atras * atras);
	};
	auto piernas = [&](int de, V3 q) {
		// El que barre mal le pega más al rival: en el motor espacial las
		// faltas suben de 2,2 por partido en primera a 3,1 en décima, y con
		// un radio igual para todos acá no cambiaban con la división.
		const FichaReglas &fr = jugadores[size_t(de)].reglas;
		double torpeza = 1.0 - std::clamp((fr.quite + fr.barrida) / 200.0, 0.0, 1.0);
		double radio = param_reglas.falta_radio_m * (1.0 + param_reglas.falta_torpeza * torpeza);
		for (size_t o = 0; o < jugadores.size(); o++) {
			if (jugadores[o].equipo != jugadores[size_t(de)].equipo
					&& hipot(q.x - jugadores[o].cuerpo.x, q.z - jugadores[o].cuerpo.z) <= radio) {
				return int(o);
			}
		}
		return -1;
	};
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		const Cuerpo &c = j.cuerpo;
		if (!j.toque_pendiente || bloqueado) {
			continue;
		}
		bool abierta = c.fase == CONTACTO || (c.eventos & CIERRA_CONTACTO);
		if (!abierta || (paso < _reinicio_hasta && j.equipo != equipo_con_pelota)) {
			continue;
		}
		const Clip &k = clips[size_t(j.clip_toque)];
		V3 q = punto_de_contacto(c, k, _rumbo_contacto(j, c, j.clip_toque, c.rumbo, pelota.pos.x, pelota.pos.z));
		double d = j.toque == TOQUE_ATAJADA ? _distancia_al_brazo(j, c, q, pelota.previa, pelota.pos)
											: distancia_al_tramo(q.x, q.z, pelota.previa, pelota.pos);
		double tolerancia = param_toque.tolerancia_m;
		bool alto_ok;
		if (j.toque == TOQUE_ATAJADA) {
			// Las manos: su alto, más el salto que dibuja la vista en la estirada.
			tolerancia = _tolerancia(int(i), j.clip_arquero);
			double bajo = std::min(pelota.previa.y, pelota.pos.y), alto = std::max(pelota.previa.y, pelota.pos.y);
			double desde = _alto_minimo(j.clip_arquero, k);
			alto_ok = alto >= desde && bajo <= k.punto_y + _tolerancia_alto(j.clip_arquero, true);
		} else if (j.toque == TOQUE_CONTROL) {
			// La pelota tiene que estar a la altura de la parte con que la
			// recibe (su franja, más la tolerancia): la cabeza no para una
			// pelota que ya bajó al pie.
			double desde, hasta;
			_franja(Parte(j.parte), desde, hasta, true);
			double tol = param_toque.tolerancia_alto_m;
			double bajo = std::min(pelota.previa.y, pelota.pos.y), alto = std::max(pelota.previa.y, pelota.pos.y);
			alto_ok = alto >= desde - tol && bajo <= hasta + tol;
		} else if (j.toque == TOQUE_ENTRADA) {
			// La pierna que barre tapa más que el pie que controla.
			tolerancia = std::max(tolerancia, param_reglas.entrada_alcance_m);
			alto_ok = std::min(pelota.previa.y, pelota.pos.y) <= param_toque.pie_hasta + param_toque.tolerancia_alto_m;
		} else if (j.clip_toque == param_remate.clip_cabeza) {
			double bajo = std::min(pelota.previa.y, pelota.pos.y), alto = std::max(pelota.previa.y, pelota.pos.y);
			alto_ok = alto >= param_toque.pecho_hasta - param_toque.tolerancia_alto_m
					&& bajo <= param_toque.cabeza_hasta + param_toque.tolerancia_alto_m;
		} else {
			alto_ok = std::min(std::abs(pelota.previa.y - q.y), std::abs(pelota.pos.y - q.y)) <= param_toque.tolerancia_alto_m;
		}
		j.toque_d_min = std::min(j.toque_d_min, d);
		j.toque_alto_ok = j.toque_alto_ok || alto_ok;
		if (alto_ok && d <= tolerancia && d < mejor_d) {
			mejor = int(i);
			mejor_d = d;
		} else if (con_reglas && j.toque == TOQUE_ENTRADA && falta_de < 0) {
			int a = piernas(int(i), q);
			if (a >= 0) {
				falta_de = int(i);
				falta_a = a;
				falta_gravedad = gravedad(falta_de, falta_a);
			}
		}
	}
	if (mejor < 0 && falta_de >= 0) {
		// La pierna llegó antes a las piernas que a la pelota: falta.
		jugadores[size_t(falta_de)].toque_pendiente = false;
		_falta(falta_de, falta_a, falta_gravedad, true);
		return false;
	}
	if (mejor >= 0 && con_reglas && _offside_al_tocar(mejor)) {
		// Juega la pelota el que estaba adelantado en el pase: offside, y la
		// pelota sigue sin que la toque.
		return false;
	}
	int cruce_de = -1;
	if (mejor >= 0) {
		const int ganador_equipo = jugadores[size_t(mejor)].equipo;
		const Cuerpo ganador = jugadores[size_t(mejor)].cuerpo;
		_tocar(mejor, mejor_d);
		// El primero gana el cruce: las otras piernas que ya estaban en la
		// pelota iban a la pelota de antes. Sin esto el que perdía la tocaba
		// al paso siguiente y se la llevaba (en el partidito, quites de ida y
		// vuelta en 0,02 s).
		for (size_t i = 0; i < jugadores.size(); i++) {
			JugadorCanchita &j = jugadores[i];
			if (int(i) != mejor && j.toque_pendiente && j.cuerpo.fase == CONTACTO) {
				// Etapa 6: el que pierde el cruce le puede pegar en las piernas al
				// que la tocó.
				// Solo con la pierna: dos que saltan a cabecear no se hacen falta.
				// Cuando los gestos de cabeza pasaron de 4 a 19 por partido
				// (etapa 7), las faltas subieron de 2,4 a 4,5.
				bool con_la_pierna = j.toque == TOQUE_ENTRADA || j.parte == PIE || j.parte == MUSLO;
				if (con_reglas && cruce_de < 0 && j.equipo != ganador_equipo && !j.arquero && con_la_pierna) {
					V3 q = punto_de_contacto(j.cuerpo, clips[size_t(j.clip_toque)], j.cuerpo.rumbo);
					if (hipot(q.x - ganador.x, q.z - ganador.z) <= param_reglas.falta_radio_m
							&& _azar.uno() < param_reglas.cruce_falta_prob) {
						cruce_de = int(i);
					}
				}
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
			if (j.toque == TOQUE_CONTROL || j.toque == TOQUE_REMATE) {
				int parte = std::clamp(j.parte, 0, 3);
				cuenta.fallos_parte[parte]++;
				if (j.toque_d_min > param_toque.tolerancia_m) {
					cuenta.fallos_lejos[parte]++;
					cuenta.fallos_metros[parte] += std::min(j.toque_d_min, 5.0);
				} else if (!j.toque_alto_ok) {
					cuenta.fallos_altura[parte]++;
				}
			}
			if (j.toque == TOQUE_ATAJADA) {
				cuenta.atajadas_falladas++;
				if (!(_remate.activo && _remate.equipo != j.equipo)) {
					cuenta.salidas_falladas++;
					if (j.toque_d_min > _tolerancia(int(i), j.clip_arquero)) {
						cuenta.salidas_lejos++;
					} else if (!j.toque_alto_ok) {
						cuenta.salidas_por_arriba++;
					}
				}
			}
			if (j.toque == TOQUE_CONTROL) {
				// Erró el control: sale a buscarla sin esperar al gesto. Pecho y
				// Cabecear no dejan moverse hasta que terminan (0,75 y 0,5 s):
				// el que erraba un pase por arriba quedaba clavado mientras la
				// pelota picaba y se iba (revisión visual: "quedan bobos").
				j.cuerpo.suelto = true;
			}
		}
	}
	if (cruce_de >= 0 && mejor >= 0) {
		_falta(cruce_de, mejor, gravedad(cruce_de, mejor), false);
	}
	return mejor >= 0;
}

void Canchita::_tocar(int i, double distancia) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	_cerrar_separacion(j.equipo);
	if (_entrada_de >= 0) {
		if (jugadores[size_t(_entrada_de)].equipo == j.equipo) {
			cuenta.entrada_gana++;
		} else {
			cuenta.entrada_pierde++;
		}
		_entrada_de = -1;
	}
	if (j.toque == TOQUE_ATAJADA) {
		_atajar(i, distancia);
		return;
	}
	// Etapa 6: el que saca toca la pelota y se juega. Del lateral, del saque
	// de arco y del córner no hay offside. Cualquier toque termina el pase de
	// los adelantados (lo que hace el arquero no: una atajada no lo habilita).
	bool saque = reglas && modo == PARTIDO && _parada.activa && _parada.sacando && i == _parada.ejecutor;
	bool sin_offside = saque && _parada.sin_offside;
	bool entrada = j.toque == TOQUE_ENTRADA;
	_adelantados.clear();
	// Etapa 5: el remate termina con el primer toque de otro. Si antes lo tocó
	// el arquero es atajada; si no, un rival lo bloqueó (o un compañero lo
	// desvió).
	if (_remate.activo) {
		if (_remate.toco_arquero) {
			_cerrar_remate(REMATE_ATAJADO);
		} else if (j.equipo != _remate.equipo) {
			_cerrar_remate(REMATE_BLOQUEADO);
		} else {
			_cerrar_remate(REMATE_OTRO);
		}
	}
	bool pase_en_juego = _pase_activo;
	bool ataca = j.equipo == equipo_con_pelota;
	if (_pase_reg >= 0) {
		RegistroPase &reg = registro_pases[size_t(_pase_reg)];
		reg.toque_fin = j.toque;
		reg.parte_fin = j.parte;
		reg.alto_fin = pelota.pos.y;
		reg.toca_id = _id(i);
		_cerrar_pase(!ataca ? PASE_CORTE : (i == _receptor ? PASE_COMPLETO : (i == _pateador ? PASE_PROPIO : PASE_OTRO)));
	}
	// La asistencia: el pase de un compañero que termina en este toque.
	if (!ataca) {
		_asistente_id = _asistido_id = -1;
	} else if (pase_en_juego && _pateador >= 0 && _pateador != i && _pateador < int(jugadores.size())
			&& jugadores[size_t(_pateador)].equipo == j.equipo) {
		_asistente_id = _id(_pateador);
		_asistido_id = _id(i);
	}
	int tipo = j.toque;
	int receptor_previo = _receptor;
	bool al_espacio_previo = _pase_al_espacio;
	bool poseedor_ = ultimo_toque == i && (ultimo_tipo == TOQUE_CONTROL || ultimo_tipo == TOQUE_CONDUCE);
	// Pase de primera: el receptor de un pase la puede mandar sin pararla.
	bool de_primera = tipo == TOQUE_PASE && pase_en_juego && !poseedor_;
	// Al arco se le pega de primera a cualquier pelota del equipo (pase,
	// rebote o centro), o después de controlarla.
	bool remata = tipo == TOQUE_REMATE && ataca;
	if (!remata && (!ataca || (!poseedor_ && !de_primera) || (tipo != TOQUE_PASE && tipo != TOQUE_CONDUCE))) {
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
	// El remate arma su propia velocidad y su giro (_patear_al_arco).
	bool pateada = false;
	switch (tipo) {
		case TOQUE_REMATE: {
			if (pase_en_juego) {
				// De primera: completa el pase que le llegaba.
				if (i == _receptor) {
					cuenta.completados++;
				} else {
					cuenta.completados_otro++;
				}
				if (modo == PARTIDO) {
					_pases_posesion++;
				}
			}
			_patear_al_arco(i, !poseedor_, apretado);
			pateada = true;
			if (!sin_offside) {
				_offside_al_patear(i);
			}
			break;
		}
		case TOQUE_PASE: {
			double dx = j.meta_x - pelota.pos.x, dz = j.meta_z - pelota.pos.z;
			double d = std::max(hipot(dx, dz), 0.5);
			int k;
			bool tendido = false;
			if (j.rapidez_pase > 0.0) {
				rapidez = j.rapidez_pase;
			} else if (j.globo) {
				rapidez = _rapidez_globo(d, k, j.tipo_pase == DEC_CENTRO);
				tendido = j.tipo_pase == DEC_CENTRO && _centro_tendido(d);
			} else {
				rapidez = _rapidez_raso(d, k);
			}
			if (rapidez < 0.0) {
				rapidez = j.globo ? 12.0 : param_toque.pase_max_ms;
			}
			angulo = rumbo_de(dx, dz);
			// Patear hacia un costado de adonde mira es más impreciso: de
			// espaldas, el doble.
			double de_lado = std::abs(mate::envolver(angulo - c.rumbo)) / mate::PI;
			// El estilo del equipo en el pase raso (Cerebro::error_de_estilo).
			double oficio = modo == PARTIDO && !j.globo ? cerebro.error_de_estilo(j.equipo) : 1.0;
			double sigma = param_toque.error_pase_rad * (1.0 - 0.8 * j.pases / 100.0) * apretado * (1.0 + de_lado) * oficio;
			angulo += _azar.normal() * sigma;
			rapidez *= 1.0 + _azar.normal() * param_toque.error_pase_rapidez * (1.0 - 0.7 * j.pases / 100.0) * apretado * oficio;
			elevacion = j.globo ? (tendido ? cerebro.pesos.centro_elevacion_rad : param_toque.elevacion_globo) : 0.0;
			cuenta.pases++;
			if (j.globo) {
				cuenta.pases_globo++;
			}
			if (j.tipo_pase == DEC_DESPEJE) {
				cuenta.pases_despeje++;
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
			if (modo == PARTIDO) {
				_armar_mundo();
				if (cerebro.en_offside(_mundo, j.receptor)) {
					cuenta.offsides++;
				}
				if (!sin_offside) {
					_offside_al_patear(i);
				}
				_pase_al_espacio = false;
				if (j.receptor >= 0 && j.rapidez_pase > 0.0) {
					const Cuerpo &cr = jugadores[size_t(j.receptor)].cuerpo;
					_pase_al_espacio = (j.meta_x - cr.x) * _ataca(j.equipo) > 2.0;
				}
				if (_pase_al_espacio) {
					cuenta.pases_al_espacio++;
				}
				if (j.tipo_pase != DEC_NADA && j.hay_decision && j.decision.corrida_preparada) {
					cuenta.pases_a_corrida++;
				}
				int corredor;
				double rx, rz;
				if (cerebro.muro_de_pared(_mundo, corredor, rx, rz) == i) {
					cuenta.paredes_devueltas++;
					cerebro.terminar_pared();
				}
				if (j.tipo_pase == DEC_PARED && j.hay_decision) {
					cerebro.anotar_pared(_mundo, j.receptor, j.decision.corredor, j.decision.retorno_x,
							j.decision.retorno_z);
				}
				cerebro.anotar_pase(_mundo, i, j.receptor);
			}
			_pase_activo = true;
			_pateador = i;
			_receptor = j.receptor;
			_pase_centro = j.tipo_pase == DEC_CENTRO;
			{
				RegistroPase reg;
				reg.paso = paso;
				reg.equipo = j.equipo;
				reg.pateador = i;
				reg.pateador_id = _id(i);
				reg.minuto = reglas ? minuto() : double(paso) * PASO_SEG / 60.0;
				reg.receptor = j.receptor;
				reg.tipo = j.tipo_pase;
				reg.globo = j.globo;
				reg.al_espacio = _pase_al_espacio;
				reg.de_primera = de_primera;
				reg.x = pelota.pos.x;
				reg.z = pelota.pos.z;
				reg.meta_x = j.meta_x;
				reg.meta_z = j.meta_z;
				reg.de_lado = de_lado;
				reg.presion_m = presion;
				if (j.receptor >= 0) {
					const Cuerpo &cr = jugadores[size_t(j.receptor)].cuerpo;
					reg.receptor_al_punto_m = hipot(cr.x - j.meta_x, cr.z - j.meta_z);
					_plan_bola = pelota.pos;
					_plan_t = 0.0;
					reg.margen = j.globo ? margen_globo(i, j.receptor, j.meta_x, j.meta_z)
							: (j.rapidez_pase > 0.0 ? margen_al_punto(i, j.receptor, j.meta_x, j.meta_z) : margen_pase(i, j.receptor));
				}
				registro_pases.push_back(reg);
				_pase_reg = int(registro_pases.size()) - 1;
			}
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
			double torpeza = (1.0 - 0.8 * j.control / 100.0) * (modo == PARTIDO ? cerebro.error_de_estilo(j.equipo) : 1.0);
			angulo = rumbo_de(j.dir_x, j.dir_z) + _azar.normal() * param_toque.error_control_rad * torpeza * dificil;
			if (modo == PARTIDO && !entrada && param_toque.control_raya_m > 0.0) {
				// Cerca de la raya la para hacia adentro: el control (con su
				// error) salía de la cancha 1,2 veces por partido
				// (tests/_diag_juego_v2.gd). El punto adonde la manda, a
				// CONTROL_MIRA_M, se trae adentro de la cancha.
				double sa, ca;
				mate::seno_coseno(angulo, sa, ca);
				double qx = pelota.pos.x + sa * CONTROL_MIRA_M, qz = pelota.pos.z + ca * CONTROL_MIRA_M;
				double lx = std::clamp(qx, -_medio_x() + param_toque.control_raya_m, _medio_x() - param_toque.control_raya_m);
				double lz = std::clamp(qz, -_medio_z() + param_toque.control_raya_m, _medio_z() - param_toque.control_raya_m);
				if ((lx != qx || lz != qz) && hipot(lx - pelota.pos.x, lz - pelota.pos.z) > 0.1) {
					angulo = rumbo_de(lx - pelota.pos.x, lz - pelota.pos.z);
				}
			}
			// El que controla corriendo se la lleva: sale para quedarle
			// toque_corto_m adelante a lo que corre hacia ahí. Con control_ms
			// fijo (1,5 m/s) el que llegaba a 5 m/s la pasaba de largo: tenía
			// que frenar y volver, y el rival se la sacaba el 18% de las veces
			// (tests/_diag_sensaciones_v2.gd).
			double sd, cd;
			mate::seno_coseno(angulo, sd, cd);
			// Lo que corre hacia ahí, hasta lo que va a correr llevándola
			// (conduccion_factor de su punta): con la rapidez a la que
			// llegaba, la pelota salía a 7 m/s y se le iba 1,2 m.
			double lleva = std::clamp(c.vx * sd + c.vz * cd, 0.0, c.vel_max * c.cansancio * param_toque.conduccion_factor);
			// Con un rival cerca la deja más cerca del pie (como la conducción).
			double largo = param_toque.toque_corto_m * (0.3 + 0.7 * _espacio_adelante(i, pelota.pos, sd, cd));
			double base = std::max(param_toque.control_ms, _rapidez_conduce(lleva, largo));
			rapidez = base + std::abs(_azar.normal()) * param_toque.error_control_ms * torpeza * dificil;
			// Pecho, muslo y cabeza la bajan: sale más lenta y cae.
			if (parte != PIE) {
				rapidez *= 0.7;
				vertical = parte == CABEZA ? 1.0 : 0.3;
				// Y sigue jugando: esos gestos no dejan moverse hasta que
				// terminan, y la pelota que bajaba se le iba antes de que
				// pudiera volver a correr (revisión visual de la etapa 6).
				if (!entrada) {
					j.cuerpo.suelto = true;
				}
			}
			if (entrada) {
				// Etapa 6: la entrada no la controla, la saca: sale suelta hacia
				// donde iba la pierna.
				cuenta.entradas_limpias++;
				_entrada_de = i;
				angulo = c.rumbo + _azar.normal() * 0.6;
				rapidez = 3.0 + 4.0 * _azar.uno();
				vertical = 0.0;
				// El que la llevaba tropieza con la pierna y cae (sin falta: tocó
				// la pelota primero). Sin esto seguía de pie al lado de la pelota
				// suelta, con el que barrió en el piso, y la volvía a agarrar su
				// equipo 3 de cada 4 veces: en la revisión visual "nunca una
				// barrida le saca la pelota a nadie" (tests/_diag_juego_v2.gd).
				if (reglas && ultimo_toque >= 0 && ultimo_toque != i && jugadores[size_t(ultimo_toque)].equipo != j.equipo
						&& !jugadores[size_t(ultimo_toque)].arquero && param_reglas.clip_caer >= 0) {
					const Cuerpo &cv = jugadores[size_t(ultimo_toque)].cuerpo;
					if (hipot(cv.x - pelota.pos.x, cv.z - pelota.pos.z) <= param_reglas.entrada_tumba_m
							&& _azar.uno() < param_reglas.entrada_tumba) {
						_caer(ultimo_toque, param_reglas.clip_caer, clips[size_t(param_reglas.clip_caer)].duracion);
						cuenta.entradas_tumban++;
					}
				}
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
			poseedor = entrada ? -1 : i;
			_desde_control = paso;
			break;
		}
	}
	if (modo == PARTIDO && ataca && pase_en_juego && (tipo == TOQUE_CONTROL || de_primera)) {
		// Un pase completado entre compañeros.
		_pases_posesion++;
		if (al_espacio_previo && i == receptor_previo) {
			cuenta.pases_al_espacio_completos++;
		}
	}
	if (!ataca) {
		if (modo == PARTIDO) {
			_cerrar_posesion();
			cerebro.terminar_pared();
		}
		// El rival la tocó: corte si venía un pase, si no quite.
		if (pase_en_juego) {
			cuenta.cortes++;
			cuenta.corte_mas_lejos_m = std::max(cuenta.corte_mas_lejos_m, distancia);
		} else {
			cuenta.quites++;
			// Para el relato y la experiencia: solo el quite al que la tenía
			// dominada. La pelota suelta que agarra un rival no es un quite.
			if (reglas && modo == PARTIDO && ultimo_toque >= 0 && ultimo_toque != i
					&& (ultimo_tipo == TOQUE_CONDUCE || ultimo_tipo == TOQUE_CONTROL)) {
				_anotar(EV_QUITE, j.equipo, _id(i), _id(ultimo_toque), entrada ? 1 : 0, pelota.pos.x, pelota.pos.z);
				if (cerebro.planes[j.equipo & 1].contrapresion > 0.0 && cerebro.transicion_de(_mundo, 1 - j.equipo) > 0.0) {
					// La recuperó enseguida: salió la presión tras pérdida.
					_anotar(EV_JUGADA, j.equipo, _id(i), -1, JUGADA_CONTRAPRESION, pelota.pos.x, pelota.pos.z);
				}
			}
			if (ultimo_tipo == TOQUE_CONDUCE) {
				cuenta.quites_conduccion++;
			} else if (ultimo_tipo == TOQUE_CONTROL) {
				cuenta.quites_control++;
			} else {
				cuenta.quites_suelta++;
			}
		}
		if (modo == RONDO) {
			_reinicio_en = paso + RONDO_ESPERA_CORTE;
			poseedor = -1;
		} else {
			equipo_con_pelota = j.equipo;
			_asignar_marcas();
		}
	}
	if (!pateada) {
		double s, co;
		mate::seno_coseno(angulo, s, co);
		double se, ce;
		mate::seno_coseno(elevacion, se, ce);
		V3 v = { s * rapidez * ce, rapidez * se + vertical, co * rapidez * ce };
		pelota.poner(pelota.pos, v, {});
	}
	j.toque_pendiente = false;
	j.persigue = false;
	j.pensar_ya = true;
	// La conducción que el cerebro pidió sigue hasta que vence (cadencia);
	// cualquier otro toque vuelve a decidir.
	if (tipo != TOQUE_CONDUCE || j.decision.tipo != DEC_CONDUCIR) {
		j.hay_decision = false;
	}
	j.rapidez_pase = 0.0;
	j.tipo_pase = DEC_NADA;
	j.regate = -1;
	j.inmune_hasta = paso + int64_t(param_toque.sin_rebote_seg / PASO_SEG + 0.5);
	_rebote_equipo = -1;
	ultimo_toque = i;
	ultimo_tipo = entrada ? TOQUE_NADA : tipo;
	if (poseedor == i && (ultimo_tipo == TOQUE_CONTROL || ultimo_tipo == TOQUE_CONDUCE)) {
		_separa_tipo = ultimo_tipo == TOQUE_CONDUCE ? 1 : 0;
		_separa_de = i;
		_separa_max = 0.0;
	}
	_visto_paso = paso + _reaccion_pasos;
	_cambio = true;
	if (saque) {
		_termina_saque(i);
	}
}

// La pelota que pega en las piernas de alguien que no la iba a tocar rebota
// contra él (choque con restitución, en el piso). Solo cambia la velocidad:
// la posición sigue siendo la de la física.
bool Canchita::_rebotes() {
	if ((modo == RONDO && _reinicio_en >= 0) || _en_manos >= 0 || _saque_medio_en >= 0
			|| (reglas && modo == PARTIDO && _parada.activa && !_parada.sacando)) {
		return false;
	}
	const double r = param_pelota.radio;
	// El arquero parado en su área tapa más: brazos abiertos y más alto
	// (etapa 5). Los de campo, las piernas.
	double alto_max = std::max(param_toque.alto_cuerpo, param_arquero.alto_cuerpo_m);
	if (pelota.pos.y > alto_max + r) {
		return false;
	}
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		if (paso < j.inmune_hasta || j.toque_pendiente) {
			continue;
		}
		const Cuerpo &c = j.cuerpo;
		bool tapa = j.arquero && _es_mi_area(int(i), c.x, c.z);
		if (pelota.pos.y > (tapa ? param_arquero.alto_cuerpo_m : param_toque.alto_cuerpo) + r) {
			continue;
		}
		const double minimo = (tapa ? param_arquero.radio_cuerpo_m : param_toque.radio_piernas) + r;
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
		// El rebote también es tocarla: si después sale, saca el otro equipo
		// (y el remate que rebota en un defensor y se va es córner). Sin esto
		// contaba el toque anterior: la pelota que rebotaba en uno y se iba
		// por la banda la sacaba él mismo.
		_rebote_equipo = j.equipo;
		// Etapa 5: el remate que pega en el arquero es atajada (aunque siga
		// hacia el arco: se decide cuando termina); en un rival, bloqueo.
		if (_remate.activo && j.equipo != _remate.equipo) {
			if (j.arquero) {
				_remate.toco_arquero = true;
			} else if (!_remate.toco_arquero) {
				_cerrar_remate(REMATE_BLOQUEADO);
			}
		}
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
	if (_con_arcos()) {
		_reglas_partido();
		return;
	}
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
	if (modo == PARTIDO && equipo != equipo_con_pelota) {
		_cerrar_posesion();
	}
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
	_nueva_trayectoria();
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

// Si el centro a `d` metros sale tendido (hay una rapidez que llega) o va
// como un globo.
bool Canchita::_centro_tendido(double d) {
	if (cerebro.pesos.centro_elevacion_rad <= 0.0 || cerebro.pesos.centro_alto_m <= 0.0) {
		return false;
	}
	int hasta = int(CENTRO_MAX_MS / Perfiles::PASO_RAPIDEZ + 0.5);
	const Perfil &p = _perfiles.de(Perfiles::rapidez_de(hasta), Perfiles::CENTRO);
	bool arriba = false;
	for (size_t q = 0; q < p.alto.size(); q++) {
		if (p.alto[q] > cerebro.pesos.centro_alto_m) {
			arriba = true;
		} else if (arriba) {
			return p.dist[q] >= d - 0.5;
		}
	}
	return false;
}

void Canchita::_cerrar_pase(int resultado) {
	if (_pase_reg < 0 || _pase_reg >= int(registro_pases.size())) {
		_pase_reg = -1;
		return;
	}
	RegistroPase &reg = registro_pases[size_t(_pase_reg)];
	reg.resultado = resultado;
	reg.paso_fin = paso;
	reg.error_m = hipot(pelota.pos.x - reg.meta_x, pelota.pos.z - reg.meta_z);
	if (reg.receptor >= 0 && reg.receptor < int(jugadores.size())) {
		const JugadorCanchita &r = jugadores[size_t(reg.receptor)];
		reg.receptor_a_pelota_m = hipot(r.cuerpo.x - pelota.pos.x, r.cuerpo.z - pelota.pos.z);
		reg.receptor_iba = r.persigue;
	}
	_pase_reg = -1;
}

void Canchita::_cerrar_separacion(int equipo_que_sigue) {
	if (_separa_tipo < 0 || _separa_de < 0) {
		_separa_tipo = -1;
		return;
	}
	int franja = _separa_max < 1.0 ? 0 : (_separa_max < 2.0 ? 1 : (_separa_max < 3.0 ? 2 : (_separa_max < 5.0 ? 3 : 4)));
	cuenta.separa[_separa_tipo][franja]++;
	if (equipo_que_sigue != jugadores[size_t(_separa_de)].equipo) {
		cuenta.separa_pierde[_separa_tipo][franja]++;
	}
	_separa_tipo = -1;
}

bool Canchita::_remate_reciente() const {
	return _salio_remate || ultimo_tipo == TOQUE_REMATE;
}

void Canchita::_medir() {
	if (_separa_tipo >= 0 && _separa_de >= 0) {
		const Cuerpo &cs = jugadores[size_t(_separa_de)].cuerpo;
		_separa_max = std::max(_separa_max, hipot(cs.x - pelota.pos.x, cs.z - pelota.pos.z));
		cuenta.lleva_pasos++;
		if (cs.rapidez() > 0.9 * cs.vel_max * cs.cansancio) {
			cuenta.lleva_a_fondo++;
		}
	}
	if (poseedor >= 0 && ultimo_tipo == TOQUE_CONDUCE && ultimo_toque == poseedor) {
		const Cuerpo &cp = jugadores[size_t(poseedor)].cuerpo;
		double d = hipot(cp.x - pelota.pos.x, cp.z - pelota.pos.z);
		cuenta.conduce_pasos++;
		cuenta.conduce_metros += d;
		cuenta.conduce_max_m = std::max(cuenta.conduce_max_m, d);
		cuenta.conduce_corre += cp.rapidez() / std::max(cp.vel_max * cp.cansancio, 0.1);
		if (d > CONDUCE_LEJOS_M) {
			cuenta.conduce_lejos++;
		}
	}
	if (_pase_reg >= 0) {
		if (!_pase_activo) {
			_cerrar_pase(PASE_SUELTO);
		} else {
			RegistroPase &reg = registro_pases[size_t(_pase_reg)];
			if (reg.receptor >= 0 && reg.receptor < int(jugadores.size()) && jugadores[size_t(reg.receptor)].persigue) {
				reg.pasos_receptor_iba++;
			}
		}
	}
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

// --- Partido (etapa 4): el cerebro de verdad ---

// La foto que lee el cerebro.
void Canchita::_armar_mundo() {
	size_t n = jugadores.size();
	_mundo.jugadores.resize(n);
	for (size_t i = 0; i < n; i++) {
		const Cuerpo &c = jugadores[i].cuerpo;
		JugadorVisto &v = _mundo.jugadores[i];
		v.x = c.x;
		v.z = c.z;
		v.vx = c.vx;
		v.vz = c.vz;
		v.vel_max = c.vel_max * c.cansancio;
		v.aceleracion = c.aceleracion * c.cansancio;
		v.resistencia = 1.0;
		mate::seno_coseno(c.rumbo, v.mira_x, v.mira_z);
	}
	_mundo.pelota_x = pelota.pos.x;
	_mundo.pelota_z = pelota.pos.z;
	_mundo.poseedor = poseedor;
	_mundo.equipo_con_pelota = equipo_con_pelota;
	_mundo.con_pelota_seg = poseedor >= 0 ? double(paso - _desde_control) * PASO_SEG : 0.0;
	_mundo.segundos = double(paso) * PASO_SEG;
	_mundo.minuto = _mundo.segundos / 60.0;
	_mundo.goles[0] = int(cuenta.goles[0]);
	_mundo.goles[1] = int(cuenta.goles[1]);
	_mundo.detenido = _saque_medio_en >= 0 || _en_manos >= 0;
	if (reglas) {
		// Etapa 6: el minuto del partido (para la urgencia del marcador) y la
		// energía de cada uno.
		_mundo.minuto = minuto();
		_mundo.detenido = _mundo.detenido || _parada.activa || periodo >= TANDA;
		for (size_t i = 0; i < n; i++) {
			_mundo.jugadores[i].resistencia = jugadores[i].energia;
		}
	}
}

void Canchita::_ubicar_partido(int i, double &qx, double &qz, double &factor, bool &frenar) {
	if (_saque_medio_en >= 0) {
		// Festejo: cada uno a su casillero del saque del medio, caminando.
		const JugadorCanchita &j = jugadores[size_t(i)];
		const FichaCerebro &f = cerebro.fichas[size_t(i)];
		qx = (-Cerebro::MEDIO_LARGO + (f.base_x + Cerebro::MEDIO_LARGO) * COMPRESION_SAQUE) * _ataca(j.equipo);
		qz = f.base_z;
		factor = 0.5;
		frenar = true;
		return;
	}
	Objetivo o = cerebro.objetivo(_mundo, i);
	qx = o.x;
	qz = o.z;
	factor = o.factor;
	frenar = o.frenar;
	if (jugadores[size_t(i)].arquero) {
		_ubicar_arquero(i, qx, qz, factor);
	}
}

// El poseedor le pregunta al cerebro. La decisión vale un rato: la conducción
// hasta su cadencia (MotorEspacial.cadencia_de_decision) y el pase hasta que
// sale; si no, a cada paso cambiaría de idea por el sorteo del softmax.
void Canchita::_decidir_partido(int i, V3 bola, double t_patada) {
	if (reglas && _parada.activa && _parada.sacando && i == _parada.ejecutor) {
		_decidir_saque(i, bola, t_patada);
		return;
	}
	JugadorCanchita &j = jugadores[size_t(i)];
	double tiene = double(paso - _desde_control) * PASO_SEG;
	double cadencia = cerebro.cadencia_seg(i);
	if (_corto_id >= 0 && _id(i) == _corto_id) {
		// Córner corto: el socio centra apenas la controla, al de más amenaza
		// de los que quedaron en el área. Decidiendo como en el juego abierto
		// se la llevaba o la tocaba atrás y el área se vaciaba (7,3% de gol
		// contra 12,0% del córner colgado, tests/_diag_jugadas_v2.gd).
		// Lo decide cada vez que piensa hasta que centra: la decisión vence
		// antes de que vuelva a tocar la pelota.
		bool a_tiempo = paso <= _corto_hasta;
		if (!a_tiempo) {
			_corto_id = -1;
		}
		int mejor = -1;
		double amenaza = -1e9;
		double gx = Cerebro::MEDIO_LARGO * _ataca(j.equipo);
		for (size_t k = 0; a_tiempo && k < jugadores.size(); k++) {
			const JugadorCanchita &o = jugadores[k];
			if (o.equipo != j.equipo || int(k) == i || o.arquero || std::abs(gx - o.cuerpo.x) > Cerebro::AREA_LARGO
					|| std::abs(o.cuerpo.z) > Cerebro::AREA_MEDIO_ANCHO) {
				continue;
			}
			if (o.reglas.amenaza > amenaza) {
				amenaza = o.reglas.amenaza;
				mejor = int(k);
			}
		}
		if (mejor >= 0) {
			Decision d;
			d.tipo = DEC_CENTRO;
			d.receptor = mejor;
			d.tiene_punto = true;
			d.x = jugadores[size_t(mejor)].cuerpo.x;
			d.z = jugadores[size_t(mejor)].cuerpo.z;
			j.decision = d;
			j.hay_decision = true;
			j.decision_hasta = paso + int64_t(cerebro.pesos.decision_vigencia_seg / PASO_SEG + 0.5);
		}
	}
	if (!j.hay_decision || paso >= j.decision_hasta) {
		// El motor espacial aguantaba la cadencia con la pelota pegada al pie y
		// el robo era un duelo. Acá la conducción la deja suelta entre toques:
		// con un rival encima, aguantar era regalarla (16 quites por minuto).
		bool puede_pasar = tiene >= cadencia || _rival_mas_cerca(i, bola.x, bola.z) < param_toque.presion_m + 1.0;
		_plan_bola = bola;
		_plan_t = t_patada;
		cerebro.planeador = this;
		j.decision = cerebro.decidir(_mundo, i, puede_pasar, _azar);
		cerebro.planeador = nullptr;
		j.hay_decision = true;
		// Cuál regate hace: se sortea una vez, al decidir.
		j.regate_elegido = j.decision.tipo == DEC_REGATE ? std::min(int(_azar.uno() * double(REGATES)), REGATES - 1) : -1;
		double vale = cerebro.pesos.decision_vigencia_seg;
		if (j.decision.tipo == DEC_CONDUCIR) {
			vale = puede_pasar ? cadencia : std::max(cadencia - tiene, PASO_SEG);
			// Con un tiro claro vuelve a mirar seguido: conduciendo 1 o 2 s
			// sin decidir entraba al área sin patear.
			if (cerebro.factor_geometria(bola.x, bola.z, j.equipo) >= Cerebro::TIRO_CLARO) {
				vale = std::min(vale, DECIDE_A_TIRO_SEG);
			}
			if (puede_pasar && cerebro.pesos.conduce_decide_seg > 0.0) {
				vale = std::min(vale, cerebro.pesos.conduce_decide_seg);
			}
		}
		j.decision_hasta = paso + std::max<int64_t>(1, int64_t(vale / PASO_SEG + 0.5));
		{
			double al_arco = hipot(param_pelota.medio_largo * _ataca(j.equipo) - bola.x, bola.z);
			if (al_arco <= 35.0 && !j.arquero && cerebro.via_libre(_mundo, i)) {
				cuenta.via_libre[al_arco <= 16.5 ? 0 : (al_arco <= 25.0 ? 1 : 2)][std::clamp(j.decision.tipo, 0, DECISIONES - 1)]++;
			}
		}
	}
	// De espaldas al arco no remata: lleva la pelota hacia el punto que
	// eligió, con un toque corto, y vuelve a decidir en el toque siguiente,
	// ya de frente (_remate_de_espaldas).
	bool gira_al_arco = j.decision.tipo == DEC_REMATE && _remate_de_espaldas(i, bola, j.decision.x, j.decision.z);
	if (gira_al_arco) {
		Decision gira;
		gira.tipo = DEC_CONDUCIR;
		double gx = j.decision.x - bola.x, gz = j.decision.z - bola.z;
		double gl = std::max(hipot(gx, gz), 1e-6);
		gira.dir_x = gx / gl;
		gira.dir_z = gz / gl;
		j.decision = gira;
		j.decision_hasta = paso;
		cuenta.giros_al_arco++;
	}
	const Decision &d = j.decision;
	if (d.tipo == DEC_REMATE) {
		j.toque = TOQUE_REMATE;
		j.meta_x = d.x;
		j.meta_alto = d.alto;
		j.meta_z = d.z;
		j.golpe_remate = d.golpe;
		return;
	}
	// Sin el clip de ese regate (los bancos que no lo configuran), conduce.
	bool regatea = d.tipo == DEC_REGATE && j.regate_elegido >= 0 && param_toque.clips_regate[j.regate_elegido] >= 0
			&& param_toque.clip_conduce >= 0;
	if (d.tipo != DEC_CONDUCIR && d.tipo != DEC_REGATE && d.tipo != DEC_NADA) {
		Pase pase = _pase_a(i, bola, t_patada, d);
		if (pase.hay) {
			j.toque = TOQUE_PASE;
			j.meta_x = pase.x;
			j.meta_z = pase.z;
			j.receptor = pase.receptor;
			j.globo = pase.globo;
			j.rapidez_pase = pase.rapidez;
			j.tipo_pase = d.tipo;
			return;
		}
	}
	// Conduce por el carril que eligió el cerebro, sin irse de la cancha. El
	// cuerpo protege la pelota: la aleja del rival más cercano igual que el
	// control orientado (_orientar). Con el carril solo, la pelota iba suelta
	// hacia el que presionaba y se perdían 8 pelotas por minuto conduciendo.
	bool con_rumbo = d.tipo == DEC_CONDUCIR || d.tipo == DEC_REGATE;
	double dx = con_rumbo ? d.dir_x : _ataca(j.equipo);
	double dz = con_rumbo ? d.dir_z : 0.0;
	// El regate sale por donde eligió el cerebro: pasa al lado del rival, no
	// se aleja de él.
	if (!regatea) {
		int cerca = -1;
		double d_cerca = 1e9;
		for (size_t o = 0; o < jugadores.size(); o++) {
			if (jugadores[o].equipo == j.equipo) {
				continue;
			}
			double e = hipot(jugadores[o].cuerpo.x - bola.x, jugadores[o].cuerpo.z - bola.z);
			if (e < d_cerca) {
				d_cerca = e;
				cerca = int(o);
			}
		}
		if (cerca >= 0 && d_cerca < 6.0 && d_cerca > 1e-6) {
			double peso = 1.5 * (6.0 - d_cerca) / 6.0;
			dx += (bola.x - jugadores[size_t(cerca)].cuerpo.x) / d_cerca * peso;
			dz += (bola.z - jugadores[size_t(cerca)].cuerpo.z) / d_cerca * peso;
		}
		double l0 = hipot(dx, dz);
		if (l0 > 1e-9) {
			dx /= l0;
			dz /= l0;
		}
	}
	// Hacia (ax, az), sin mandarla contra una raya.
	auto apuntar = [&](double ax, double az) {
		double qx = std::clamp(bola.x + ax * 5.0, -_medio_x() + 2.0, _medio_x() - 2.0);
		double qz = std::clamp(bola.z + az * 5.0, -_medio_z() + 2.0, _medio_z() - 2.0);
		double l = hipot(qx - bola.x, qz - bola.z);
		if (l > 1e-6) {
			j.dir_x = (qx - bola.x) / l;
			j.dir_z = (qz - bola.z) / l;
		} else {
			j.dir_x = _ataca(j.equipo);
			j.dir_z = 0.0;
		}
	};
	apuntar(dx, dz);
	// Más largo con espacio, más corto con mejor control (igual que el partidito).
	double presion = _rival_mas_cerca(i, bola.x, bola.z);
	double espacio = std::clamp((presion - 2.0) / 4.0, 0.0, 1.0);
	double largo = (param_toque.toque_corto_m + (param_toque.toque_largo_m - param_toque.toque_corto_m) * espacio)
			* (1.2 - 0.4 * j.control / 100.0);
	if (regatea) {
		largo = param_toque.regate_largo_m;
	}
	// Lo que corre HACIA donde la manda, no su rapidez: el que cambiaba de
	// dirección conduciendo (el carril nuevo, o alejarla del rival) la tocaba
	// como si ya corriera para ese lado, a 7 m/s. Él tenía que frenar y dar la
	// vuelta, y la pelota se le iba 3 m (169 veces en 20 partidos; de ahí
	// salían casi todas las pelotas a más de 2,5 m del que la lleva).
	// Tercera revisión visual de la etapa 7: seguían "adelantando la pelota
	// para correrla a fondo". De los toques de conducción, la pelota se iba a
	// más de 2 m en el 9%, y esos eran los que giraban 110 a 140 grados contra
	// lo que corría (a 6,5 m/s): la pelota salía a 5 m/s para atrás y él
	// tardaba un segundo en frenar y volver (tests/_diag_juego_v2.gd). La
	// rapidez del toque cuenta lo que corre hacia ahí CON signo (el que va
	// para el otro lado primero tiene que frenar) más lo que gana en
	// conduce_gana_seg, no en medio segundo: la media vuelta deja la pelota
	// casi quieta. Probado y descartado: que el toque no gire más de 70
	// grados por vez; la pelota no se alejaba, pero salía de la cancha 1,07
	// veces por partido conduciendo (0,12 sin el tope) y los quites al que
	// conduce bajaban de 6,8 a 2,4.
	double hacia = j.cuerpo.vx * j.dir_x + j.cuerpo.vz * j.dir_z;
	j.ritmo_conduce = d.tipo == DEC_CONDUCIR ? d.ritmo : 1.0;
	double tope = j.cuerpo.vel_max * j.cuerpo.cansancio * param_toque.conduccion_factor * j.ritmo_conduce;
	double corre = std::clamp(hacia + j.cuerpo.aceleracion * param_toque.conduce_gana_seg, 0.0, tope);
	if (gira_al_arco) {
		// Cerca del arco un toque largo se lo queda el arquero.
		largo = param_toque.toque_corto_m;
	}
	// La pelota acompaña al cuerpo hasta el toque siguiente. El cuerpo no
	// cambia de velocidad en el acto (Cuerpo::_moverse): lo que corre para
	// otro lado lo pierde a giro_acel por segundo. Hasta que puede volver a
	// tocarla (lo que dura el gesto de conducir) recorre `px, pz`. La pelota
	// sale hacia ahí, más el largo hacia donde quiere ir, y llega con él: el
	// giro termina en el toque siguiente. Sin esto el toque contaba solo lo
	// que corría hacia donde la mandaba: el que iba a 6,6 m/s y la tocaba a
	// 110 grados la dejaba casi quieta, seguía 1,8 m de largo y volvía a
	// buscarla (BUG-009, docs/bugs_pendientes.md). Reemplaza a
	// toque.frena_giro_*, que la tocaba a 34 grados de lo que corría, pero
	// solo girando más de 100 grados y sin un rival cerca; esta cuenta da
	// unos 30 grados en ese caso.
	// La pelota no va más rápido que el ritmo de conducción (`tope`): sumando
	// también lo que corre de más hacia adelante, el favorito conducía a
	// fondo (quinta contra octava, 4,11 goles; así 3,98; antes 3,32).
	double alcanza_m = 0.0, alcanza_seg = 0.0;
	if (regatea) {
		// El regate es el cambio de dirección: la pelota sale por la salida
		// entera, sin acompañar lo que el cuerpo sigue corriendo (eso la dejaba
		// a unos 30 grados y derecho al rival). Hasta que termina el clip y
		// llega el contacto del toque siguiente no la puede volver a tocar: la
		// pelota tiene que haber recorrido lo que él corre en ese tiempo.
		const Clip &kr = clips[size_t(param_toque.clips_regate[j.regate_elegido])];
		alcanza_seg = kr.duracion - std::max(kr.contacto_seg, 0.0)
				+ std::max(clips[size_t(param_toque.clip_conduce)].contacto_seg, 0.0);
		alcanza_m = corre * alcanza_seg;
	} else if (param_toque.conduce_inercia > 0.0 && param_toque.clip_conduce >= 0) {
		double t_sig = clips[size_t(param_toque.clip_conduce)].duracion;
		// Los segundos que pesa, hasta t_sig, una velocidad `resto` que el
		// cuerpo pierde a `a` por segundo.
		auto pesa = [&](double resto, double a) {
			double t = std::min(t_sig, resto / std::max(a, 0.1));
			return resto > 1e-9 ? (t - 0.5 * t * t * a / resto) * param_toque.conduce_inercia : 0.0;
		};
		double atras = std::min(hacia, 0.0);
		double gx = j.cuerpo.vx - j.dir_x * (hacia - atras), gz = j.cuerpo.vz - j.dir_z * (hacia - atras);
		double gira = hipot(gx, gz);
		if (gira > 0.1) {
			double sigue = corre * t_sig;
			double k = pesa(gira, param_cuerpo.giro_acel);
			double px = j.dir_x * sigue + gx * k, pz = j.dir_z * sigue + gz * k;
			double lp = hipot(px, pz);
			// El largo no la deja detrás de donde va a estar el cuerpo: el que
			// da la media vuelta la lleva hasta donde frena.
			double lx = j.dir_x * largo, lz = j.dir_z * largo;
			double contra = lp > 1e-6 ? (lx * px + lz * pz) / lp : 0.0;
			if (contra < 0.0) {
				lx -= contra * px / lp;
				lz -= contra * pz / lp;
			}
			double lt = hipot(px + lx, pz + lz);
			if (lt > 1e-6) {
				apuntar((px + lx) / lt, (pz + lz) / lt);
				alcanza_m = std::clamp(px * j.dir_x + pz * j.dir_z, 0.0, tope * t_sig);
				alcanza_seg = t_sig;
				corre = alcanza_m / t_sig;
				largo = std::max(lx * j.dir_x + lz * j.dir_z, 0.0);
			}
		}
	}
	j.toque = TOQUE_CONDUCE;
	j.regate = regatea ? j.regate_elegido : -1;
	j.rapidez_toque = _rapidez_conduce(corre, largo, alcanza_m, alcanza_seg);
}

// La rapidez con la que la pelota llega al punto cuando llega el receptor (o
// apenas después), todavía rodando: la más baja que llega a tiempo. Si él
// llega antes que un pase normal (_rapidez_raso), va el pase normal y la
// espera: apurando la pelota para que llegue con él salían pases a 16 m/s a
// 10 m que el receptor no alcanzaba a parar.
double Canchita::_rapidez_al_espacio(double d, double t_receptor, double t_patada) {
	int k_raso;
	double normal = _rapidez_raso(d, k_raso);
	if (normal > 0.0 && k_raso >= 0 && t_patada + double(k_raso + 1) * PASO_SEG >= t_receptor) {
		return normal;
	}
	int desde = int(param_toque.pase_min_ms / Perfiles::PASO_RAPIDEZ + 0.5);
	int hasta = int(param_toque.pase_max_ms / Perfiles::PASO_RAPIDEZ + 0.5);
	for (int iv = desde; iv <= hasta; iv++) {
		double v = Perfiles::rapidez_de(iv);
		const Perfil &p = _perfiles.de(v, false);
		int k = p.paso_a(d);
		if (k < 0 || p.rapidez[size_t(k)] < ESPACIO_RESTO_MS) {
			continue;
		}
		if (t_patada + double(k + 1) * PASO_SEG <= t_receptor + ESPACIO_TARDE_SEG) {
			return v;
		}
	}
	int k;
	return _rapidez_raso(d, k);
}

// El pase que pidió el cerebro, con la física del toque (etapa 3): a los pies
// o a una tangente del receptor, al espacio con la rapidez justa, o globo.
Canchita::Pase Canchita::_pase_a(int i, V3 bola, double t_patada, const Decision &d) {
	Pase r;
	int receptor = d.receptor;
	double tx, tz;
	if (d.tiene_punto) {
		tx = d.x;
		tz = d.z;
	} else if (receptor >= 0) {
		tx = jugadores[size_t(receptor)].cuerpo.x;
		tz = jugadores[size_t(receptor)].cuerpo.z;
	} else {
		return r;
	}
	if (d.tipo == DEC_DESPEJE) {
		// No busca a nadie; el receptor es el compañero más cerca de donde cae.
		double mejor = 1e18;
		for (size_t o = 0; o < jugadores.size(); o++) {
			if (int(o) == i || jugadores[o].equipo != jugadores[size_t(i)].equipo) {
				continue;
			}
			double e = hipot(jugadores[o].cuerpo.x - tx, jugadores[o].cuerpo.z - tz);
			if (e < mejor) {
				mejor = e;
				receptor = int(o);
			}
		}
	}
	double dx = tx - bola.x, dz = tz - bola.z;
	double dd = hipot(dx, dz);
	if (dd < 1.0) {
		return r;
	}
	bool globo = d.tipo == DEC_PASE_LARGO || d.tipo == DEC_CENTRO || d.tipo == DEC_DESPEJE;
	if (globo) {
		// Si ni el globo más fuerte llega, cae más cerca en la misma línea.
		int k;
		bool centro = d.tipo == DEC_CENTRO;
		double v = _rapidez_globo(dd, k, centro);
		while (v < 0.0 && dd > 8.0) {
			dd -= 3.0;
			v = _rapidez_globo(dd, k, centro);
		}
		if (v < 0.0) {
			return r;
		}
		r.hay = true;
		r.receptor = receptor;
		r.x = bola.x + dx / hipot(dx, dz) * dd;
		r.z = bola.z + dz / hipot(dx, dz) * dd;
		r.globo = true;
		return r;
	}
	if (!d.tiene_punto) {
		// A los pies o a una tangente de ese receptor, lo que mejor le gane a
		// los rivales; si ninguno sirve, a los pies igual (el softmax ya pesó
		// el riesgo de esa línea).
		Pase p = _planear_pase(i, bola, t_patada, receptor);
		if (p.hay) {
			return p;
		}
		r.hay = true;
		r.receptor = receptor;
		r.x = tx;
		r.z = tz;
		return r;
	}
	// Al espacio: el receptor sale apenas sale la pelota (le avisan).
	const Cuerpo &cr = jugadores[size_t(receptor)].cuerpo;
	double t_receptor = t_patada + tiempo_de_llegada(cr, tx, tz, ALCANCE_PLAN_M, 1.0);
	double v = _rapidez_al_espacio(dd, t_receptor, t_patada);
	if (v < 0.0) {
		return r;
	}
	r.hay = true;
	r.receptor = receptor;
	r.x = tx;
	r.z = tz;
	r.rapidez = v;
	return r;
}

double Canchita::margen_pase(int de, int a) {
	Pase p = _planear_pase(de, _plan_bola, _plan_t, a);
	return p.hay ? p.margen : -1e9;
}

double Canchita::margen_al_punto(int de, int a, double x, double z) {
	double dx = x - _plan_bola.x, dz = z - _plan_bola.z;
	double d = hipot(dx, dz);
	if (d < 1.0 || a < 0) {
		return -1e9;
	}
	const Cuerpo &cr = jugadores[size_t(a)].cuerpo;
	double t_receptor = _plan_t + tiempo_de_llegada(cr, x, z, ALCANCE_PLAN_M, 1.0);
	double v = _rapidez_al_espacio(d, t_receptor, _plan_t);
	if (v < 0.0) {
		return -1e9;
	}
	const Perfil &perfil = _perfiles.de(v, false);
	int k = perfil.paso_a(d);
	if (k < 0) {
		return -1e9;
	}
	double camino = _margen(de, _plan_bola, dx / d, dz / d, perfil, k, _plan_t);
	return std::min(camino, _margen_destino(de, x, z, std::max(t_receptor, _plan_t + double(k + 1) * PASO_SEG)));
}

// El pase al espacio y el globo no terminan cuando la pelota llega al punto:
// terminan cuando llega el receptor. Cuánto antes que el rival más cercano
// llegan los dos (segundos; < 0 es que el rival está antes). Mirando solo el
// camino de la pelota (_margen), un rival parado al lado del punto no contaba
// y cortaba el 46% de los pases al hueco y el 42% de los centros
// (tests/_diag_pases_v2.gd, 100 partidos de quinta, semilla 97000).
double Canchita::_margen_destino(int de, double x, double z, double t_juntos) const {
	int equipo = jugadores[size_t(de)].equipo;
	double margen = 1e9;
	for (const JugadorCanchita &jo : jugadores) {
		if (jo.equipo == equipo) {
			continue;
		}
		double to = tiempo_de_llegada(jo.cuerpo, x, z, ALCANCE_RIVAL_M) + param_toque.reaccion_seg;
		margen = std::min(margen, to - t_juntos);
	}
	return margen;
}

double Canchita::margen_globo(int de, int a, double x, double z) {
	double dx = x - _plan_bola.x, dz = z - _plan_bola.z;
	double d = hipot(dx, dz);
	if (d < 1.0) {
		return -1e9;
	}
	int k;
	double v = _rapidez_globo(d, k);
	while (v < 0.0 && d > 8.0) {
		d -= 3.0;
		v = _rapidez_globo(d, k);
	}
	if (v < 0.0 || k < 0) {
		return -1e9;
	}
	double l = hipot(dx, dz);
	double camino = _margen(de, _plan_bola, dx / l, dz / l, _perfiles.de(v, true), k, _plan_t);
	if (a < 0) {
		return camino;
	}
	// Donde cae: el punto que quedó después de acortar el globo.
	double cx = _plan_bola.x + dx / l * d, cz = _plan_bola.z + dz / l * d;
	double t_receptor = _plan_t + tiempo_de_llegada(jugadores[size_t(a)].cuerpo, cx, cz, ALCANCE_PLAN_M, 1.0);
	return std::min(camino, _margen_destino(de, cx, cz, std::max(t_receptor, _plan_t + double(k + 1) * PASO_SEG)));
}

// Sin reglas de verdad (etapa 6): la pelota que sale vuelve con un lateral, un
// córner o un saque de arco. Etapa 5: el gol lo decide la pelota al cruzar la
// línea; después del festejo se saca del medio. El arquero que la agarró la
// suelta para jugar. En el modo ARCO no hay reanudaciones: el test mira cómo
// terminó el remate.
bool Canchita::_reglas_partido() {
	bool con_reglas = reglas && modo == PARTIDO;
	if (con_reglas) {
		// Etapa 6: el reloj, la tanda y las paradas mandan sobre todo lo demás.
		if (periodo == TERMINADO || _reloj()) {
			return true;
		}
		if (periodo == TANDA && _avanzar_tanda()) {
			return true;
		}
		if (_parada.activa) {
			return _avanzar_parada();
		}
	}
	if (_saque_medio_en >= 0) {
		if (paso >= _saque_medio_en) {
			_sacar_del_medio();
			return true;
		}
		return false;
	}
	if (_en_manos >= 0) {
		if (con_reglas && _mano.activo) {
			// Etapa 6: la saca en el contacto del gesto.
			const Cuerpo &c = jugadores[size_t(_en_manos)].cuerpo;
			if ((c.eventos & ABRE_CONTACTO) || c.clip < 0) {
				_sacar_de_manos();
			}
		} else if (paso >= _suelta_en && modo == PARTIDO && !(con_reglas && _decidir_saque_de_manos())) {
			_soltar();
		}
		return false;
	}
	if (_remate.activo) {
		double v = std::sqrt(pelota.vel.x * pelota.vel.x + pelota.vel.y * pelota.vel.y + pelota.vel.z * pelota.vel.z);
		if (paso - _remate.paso > REMATE_MAX_PASOS || (v < REMATE_MUERTO_MS && pelota.en_piso)) {
			_cerrar_remate(_remate.toco_arquero ? REMATE_ATAJADO : (_remate.palo ? REMATE_PALO : REMATE_OTRO));
		}
	}
	// Gol: la pelota entera pasó la línea entre los palos y abajo del
	// travesaño. Detrás de la línea y adentro del arco solo se llega por la
	// boca: la red es de la física (pelota.h).
	const double r = param_pelota.radio;
	if (std::abs(pelota.pos.x) > param_pelota.medio_largo + r && std::abs(pelota.pos.z) < param_pelota.arco_medio_ancho
			&& pelota.pos.y < param_pelota.arco_alto) {
		// El equipo 1 defiende el arco de +x.
		int defiende = pelota.pos.x > 0.0 ? 1 : 0;
		_gol(1 - defiende);
		return true;
	}
	if (modo == PARTIDO && poseedor >= 0 && !_llegada_contada && paso >= _reinicio_hasta) {
		// Una llegada por posesión: controlarla en el área rival.
		const JugadorCanchita &j = jugadores[size_t(poseedor)];
		double ax = Cerebro::MEDIO_LARGO * _ataca(j.equipo);
		if (std::abs(ax - pelota.pos.x) <= Cerebro::AREA_LARGO && std::abs(pelota.pos.z) <= Cerebro::AREA_MEDIO_ANCHO) {
			cuenta.llegadas[j.equipo & 1]++;
			_llegada_contada = true;
		}
	}
	if (_adentro(pelota.pos.x, pelota.pos.z, param_pelota.radio)) {
		return false;
	}
	_salio_remate = _remate.activo;
	if (_remate.activo) {
		_cerrar_remate(_remate.toco_arquero ? REMATE_ATAJADO : (_remate.palo ? REMATE_PALO : REMATE_AFUERA));
	}
	if (modo == ARCO || (con_reglas && periodo == TANDA)) {
		// En la tanda la pelota que sale solo cierra el remate.
		return false;
	}
	cuenta.salidas++;
	_cerrar_separacion(-1);
	if (_entrada_de >= 0) {
		cuenta.entrada_afuera++;
		_entrada_de = -1;
	}
	if (_pase_activo) {
		cuenta.pases_afuera++;
	}
	if (_remate_reciente()) {
		cuenta.salidas_remate++;
	} else if (_rebote_equipo >= 0) {
		cuenta.salidas_rebote++;
	} else if (_pase_activo) {
		cuenta.salidas_pase++;
		if (_pase_reg >= 0) {
			registro_pases[size_t(_pase_reg)].afuera = true;
		}
	} else if (ultimo_tipo == TOQUE_CONDUCE) {
		cuenta.salidas_conduce++;
	} else if (ultimo_tipo == TOQUE_CONTROL) {
		cuenta.salidas_control++;
	} else {
		cuenta.salidas_otra++;
	}
	int toco = ultimo_toque >= 0 ? jugadores[size_t(ultimo_toque)].equipo : equipo_con_pelota;
	if (_rebote_equipo >= 0) {
		toco = _rebote_equipo;
	}
	if (std::abs(pelota.pos.x) > _medio_x() + param_pelota.radio) {
		// Por el fondo: el equipo 1 defiende el arco de +x.
		int defiende = pelota.pos.x > 0.0 ? 1 : 0;
		if (toco != defiende) {
			cuenta.saques_de_arco++;
			double x = -_ataca(defiende) * (Cerebro::MEDIO_LARGO - SAQUE_DE_ARCO_M);
			if (con_reglas) {
				// Del lado del área chica por donde salió.
				_parar(SAQUE_ARCO, defiende, x, pelota.pos.z >= 0.0 ? 4.0 : -4.0);
			} else {
				_reiniciar(defiende, x, 0.0);
			}
		} else {
			cuenta.corners++;
			double lado = pelota.pos.z >= 0.0 ? 1.0 : -1.0;
			double x = pelota.pos.x > 0.0 ? _medio_x() : -_medio_x();
			if (con_reglas) {
				_parar(CORNER, 1 - defiende, x - (x > 0.0 ? 0.3 : -0.3), lado * (_medio_z() - 0.3));
			} else {
				_reiniciar(1 - defiende, x, lado * _medio_z());
			}
		}
	} else {
		cuenta.laterales++;
		if (con_reglas) {
			double lado = pelota.pos.z >= 0.0 ? 1.0 : -1.0;
			_parar(LATERAL, 1 - toco, std::clamp(pelota.pos.x, -_medio_x() + 1.0, _medio_x() - 1.0), lado * _medio_z());
		} else {
			_reiniciar(1 - toco, pelota.pos.x, pelota.pos.z);
		}
	}
	return true;
}

void Canchita::_cerrar_posesion() {
	if (modo != PARTIDO) {
		return;
	}
	cuenta.posesiones++;
	cuenta.pases_en_posesiones += _pases_posesion;
	if (_pases_posesion >= 3) {
		cuenta.posesiones_3_pases++;
	}
	if (_pases_posesion >= 5) {
		cuenta.posesiones_5_pases++;
	}
	cuenta.max_pases_posesion = std::max<int64_t>(cuenta.max_pases_posesion, _pases_posesion);
	_pases_posesion = 0;
	_pase_al_espacio = false;
	_llegada_contada = false;
	for (JugadorCanchita &j : jugadores) {
		j.hay_decision = false;
	}
}

// --- Etapa 5: remates y arqueros ---

void Canchita::rematar(int i, int golpe, double alto, double lateral) {
	if (i < 0 || i >= int(jugadores.size())) {
		return;
	}
	JugadorCanchita &j = jugadores[size_t(i)];
	j.remata_prueba = true;
	j.golpe_remate = std::clamp(golpe, 0, TIPOS_REMATE - 1);
	j.meta_x = param_pelota.medio_largo * _ataca(j.equipo);
	j.meta_alto = alto;
	j.meta_z = lateral;
}

int Canchita::arquero_de(int equipo) const {
	for (size_t i = 0; i < jugadores.size(); i++) {
		if (jugadores[i].arquero && jugadores[i].equipo == equipo) {
			return int(i);
		}
	}
	return -1;
}

void Canchita::_nueva_trayectoria() {
	trayectoria.predecir(pelota, HORIZONTE);
	_tray_paso = paso;
	_buscar_cruces();
}

// Si la trayectoria va a algún arco: el primer punto detrás de la línea, si
// cruza entre los palos y abajo del travesaño (con CRUCE_MARGEN_M de más).
void Canchita::_buscar_cruces() {
	_k_cruce[0] = _k_cruce[1] = -1;
	if (!_con_arcos()) {
		return;
	}
	const double linea = param_pelota.medio_largo;
	for (size_t q = 0; q < trayectoria.pos.size(); q++) {
		const V3 &p = trayectoria.pos[q];
		if (std::abs(p.z) > _medio_z() + 1.0) {
			return;
		}
		if (std::abs(p.x) < linea) {
			continue;
		}
		if (std::abs(p.z) < param_pelota.arco_medio_ancho + CRUCE_MARGEN_M && p.y < param_pelota.arco_alto + CRUCE_MARGEN_M) {
			// El equipo 1 defiende el arco de +x.
			_k_cruce[p.x > 0.0 ? 1 : 0] = int(q);
		}
		return;
	}
}

bool Canchita::_es_mi_area(int i, double x, double z) const {
	double gx = -_ataca(jugadores[size_t(i)].equipo) * param_pelota.medio_largo;
	return std::abs(x - gx) <= Cerebro::AREA_LARGO && std::abs(z) <= Cerebro::AREA_MEDIO_ANCHO;
}

double Canchita::_reaccion_arquero(int i) const {
	return segun_atributo(jugadores[size_t(i)].reflejos, param_arquero.reaccion_lenta_seg, param_arquero.reaccion_rapida_seg);
}

double Canchita::_tolerancia(int i, int clip_arquero) const {
	(void)clip_arquero;
	return segun_atributo(jugadores[size_t(i)].estirada, param_arquero.tolerancia_min_m, param_arquero.tolerancia_max_m);
}

double Canchita::_tolerancia_alto(int clip_arquero, bool arriba) const {
	return param_arquero.tolerancia_alto_m + (arriba && _es_estirada(clip_arquero) ? param_arquero.salto_estirada_m : 0.0);
}

bool Canchita::_es_estirada(int clip_arquero) const {
	return clip_arquero >= ATAJA_VUELA_DER;
}

// Lo más bajo que llega la mano del clip. Atajar_Abajo y la estirada baja
// llegan al piso (la de la estirada va a la pelota que rueda al costado); las
// demás, su alto menos la tolerancia.
double Canchita::_alto_minimo(int clip_arquero, const Clip &k) const {
	if (clip_arquero == ATAJA_ABAJO || clip_arquero == ATAJA_VUELA_DER || clip_arquero == ATAJA_VUELA_IZQ) {
		return 0.0;
	}
	return k.punto_y - _tolerancia_alto(clip_arquero, false);
}

// Distancia en el piso de la pelota (el tramo a-b que recorrió) a lo que toca
// el arquero: la mano; en la estirada, el brazo entero, del hombro
// (brazo_desde del camino a la mano) a la mano. Con solo la mano, las
// pelotas que pasaban a 0,5-0,9 m del cuerpo no las tocaba ni parado ni
// tirado.
double Canchita::_distancia_al_brazo(const JugadorCanchita &j, const Cuerpo &c, V3 mano, V3 a, V3 b) const {
	if (!_es_estirada(j.clip_arquero)) {
		return distancia_al_tramo(mano.x, mano.z, a, b);
	}
	V3 hombro = { c.x + (mano.x - c.x) * param_arquero.brazo_desde, mano.y,
		c.z + (mano.z - c.z) * param_arquero.brazo_desde };
	// Dos tramos en el piso: se cruzan (0) o la distancia es la de alguna
	// punta al otro tramo.
	auto lado = [](V3 p, V3 q, V3 r) {
		return (q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x);
	};
	double d1 = lado(hombro, mano, a), d2 = lado(hombro, mano, b);
	double d3 = lado(a, b, hombro), d4 = lado(a, b, mano);
	if (((d1 > 0.0 && d2 < 0.0) || (d1 < 0.0 && d2 > 0.0)) && ((d3 > 0.0 && d4 < 0.0) || (d3 < 0.0 && d4 > 0.0))) {
		return 0.0;
	}
	return std::min(std::min(distancia_al_tramo(hombro.x, hombro.z, a, b), distancia_al_tramo(mano.x, mano.z, a, b)),
			std::min(distancia_al_tramo(a.x, a.z, hombro, mano), distancia_al_tramo(b.x, b.z, hombro, mano)));
}

double Canchita::_factor_acomodarse(const Cuerpo &c) const {
	return std::clamp(param_cuerpo.rapidez_para_girar * 0.95 / std::max(c.vel_max * c.cansancio, 0.1), 0.05, 1.0);
}

// Hacia dónde queda el cuerpo al tocarla. El de campo gira hacia la pelota
// (_rumbo_al_tocar). El arquero gira para que la MANO quede del lado de la
// pelota: en la estirada la mano va 1,4 m al costado, y girar hacia la pelota
// la alejaba.
double Canchita::_rumbo_contacto(const JugadorCanchita &j, const Cuerpo &c, int clip, double rumbo, double x,
		double z) const {
	if (j.toque != TOQUE_ATAJADA || clip < 0) {
		return _rumbo_al_tocar(c, rumbo, x, z);
	}
	double dx = x - c.x, dz = z - c.z;
	if (dx * dx + dz * dz < 1e-9) {
		return rumbo;
	}
	Cuerpo cero;
	V3 o = punto_de_contacto(cero, clips[size_t(clip)], 0.0);
	double desfase = o.x * o.x + o.z * o.z > 1e-9 ? rumbo_de(o.x, o.z) : 0.0;
	double dif = std::clamp(mate::envolver(rumbo_de(dx, dz) - (rumbo + desfase)), -param_arquero.giro_alcance_rad,
			param_arquero.giro_alcance_rad);
	return rumbo + dif;
}

// El arquero lee el remate (después de su reacción) y busca en la trayectoria
// el primer punto de su área donde una mano llega a tiempo: se corre hasta
// donde tiene que arrancar el clip y el gatillo lo tira. Prefiere atajar
// parado (agarra más) y la estirada si no llega. Si ningún clip llega, se
// tira igual con el que menos le falta: el gol sale de que no llegó.
bool Canchita::_plan_atajar(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	int kc = _k_cruce[j.equipo & 1];
	if (kc < 0 || _en_manos >= 0 || trayectoria.pos.empty()) {
		return false;
	}
	// Etapa 6: en el penal no espera a leerlo: elige un lado y se tira en la
	// patada. Esperando su reacción no llegaba a ninguno (11 de 11 adentro).
	bool penal = reglas && _remate.activo && _remate.penal && _remate.equipo != j.equipo;
	if (penal && !_remate.lado_elegido) {
		_remate.lado_elegido = true;
		_remate.adivina = _azar.uno() < param_reglas.penal_adivina;
	}
	if (!penal && paso < _tray_paso + int64_t(_reaccion_arquero(i) / PASO_SEG + 0.5)) {
		return false;
	}
	// El que no adivina se tira al otro lado: la pelota del lado contrario.
	double espejo = penal && !_remate.adivina ? -1.0 : 1.0;
	Cuerpo &c = j.cuerpo;
	int desde = std::max(0, _indice_tray(paso + 1));
	// Se acomoda sin darse vuelta: por debajo de rapidez_para_girar el cuerpo
	// sigue mirando la pelota (cuerpo.h). Corriendo a fondo giraba hacia
	// donde iba y la mano quedaba para otro lado.
	double factor = _factor_acomodarse(c);
	double mejor = 1e18;
	int mejor_a = -1;
	double mejor_x = c.x, mejor_z = c.z, mejor_t = 0.0;
	for (int q = desde; q <= kc && q < int(trayectoria.pos.size()); q++) {
		V3 p = trayectoria.pos[size_t(q)];
		p.z *= espejo;
		if (!_es_mi_area(i, p.x, p.z)) {
			continue;
		}
		double tq = double(_tray_paso + q + 1 - paso) * PASO_SEG;
		V3 vp = trayectoria.vel[size_t(q)];
		vp.z *= espejo;
		// De frente a la pelota que viene.
		double rumbo = hipot(vp.x, vp.z) > 1.0 ? rumbo_de(-vp.x, -vp.z) : rumbo_de(p.x - c.x, p.z - c.z);
		for (int a = 0; a < CLIPS_ARQUERO; a++) {
			int clip = param_arquero.clips[a];
			if (clip < 0) {
				continue;
			}
			const Clip &k = clips[size_t(clip)];
			double tc = std::max(k.contacto_seg, 0.0);
			// El clip que no llega a su contacto a tiempo cuenta como falta: si
			// nada llega, se tira igual (tarde) con el que menos le falta.
			double tarde = std::max(0.0, tc - tq);
			double abajo = _alto_minimo(a, k);
			if (p.y < abajo || p.y > k.punto_y + _tolerancia_alto(a, true)) {
				continue;
			}
			Cuerpo cero;
			V3 o = punto_de_contacto(cero, k, rumbo);
			double bx = p.x - o.x, bz = p.z - o.z;
			if (_es_estirada(a)) {
				// Con la pelota entre el hombro y la mano: el cuerpo en el tramo
				// de p - o (la mano) a p - brazo_desde·o (el hombro), lo más
				// cerca de donde está.
				double hx = p.x - o.x * param_arquero.brazo_desde, hz = p.z - o.z * param_arquero.brazo_desde;
				double ux = hx - bx, uz = hz - bz;
				double l2 = ux * ux + uz * uz;
				double f = l2 > 1e-9 ? std::clamp(((c.x - bx) * ux + (c.z - bz) * uz) / l2, 0.0, 1.0) : 0.0;
				bx += ux * f;
				bz += uz * f;
			}
			if (!_es_estirada(a) && hipot(bx - c.x, bz - c.z) > param_arquero.parada_max_m) {
				continue;
			}
			double falta = tarde + std::max(0.0, tiempo_de_llegada(c, bx, bz, _tolerancia(i, a) * 0.5, factor) - std::max(tq - tc, 0.0));
			// Parado antes que tirado; y cuanto antes, mejor (más lejos del arco).
			double costo = falta > 0.0 ? 100.0 + falta : (_es_estirada(a) ? 1.0 : 0.0) + 0.002 * double(q - desde);
			if (costo < mejor) {
				mejor = costo;
				mejor_a = a;
				mejor_x = bx;
				mejor_z = bz;
				mejor_t = tq;
			}
		}
	}
	if (mejor_a < 0) {
		return false;
	}
	j.toque = TOQUE_ATAJADA;
	j.clip_arquero = mejor_a;
	j.persigue = true;
	j.paso_meta = paso + int64_t(mejor_t / PASO_SEG + 0.5);
	if (_remate.activo && _remate.indice < registro.size() && registro[_remate.indice].paso_plan < 0) {
		registro[_remate.indice].paso_plan = paso;
	}
	c.ir_a(mejor_x, mejor_z, factor, true);
	c.mira = true;
	c.mira_x = pelota.pos.x;
	c.mira_z = pelota.pos.z;
	return true;
}

// Sin remate encima: sobre la bisectriz entre la pelota y el medio del arco,
// más adelante de la línea cuanto más lejos está la pelota. En el mano a mano
// sale a achicar (MotorEspacial.punto_de_achique, mismos pesos).
void Canchita::_ubicar_arquero(int i, double &qx, double &qz, double &factor) {
	const JugadorCanchita &j = jugadores[size_t(i)];
	int e = j.equipo;
	double gx = -_ataca(e) * param_pelota.medio_largo;
	V3 b = _bola_en(paso + PASOS_POR_TURNO);
	double ux = b.x - gx, uz = b.z;
	double db = hipot(ux, uz);
	// Lejos, o con la pelota de su equipo, se queda en el ancla del cerebro
	// (MotorEspacial._ancla_de_rol: el líbero de su área).
	if (db > 40.0 || db < 1e-6 || (equipo_con_pelota == e && poseedor >= 0)) {
		return;
	}
	ux /= db;
	uz /= db;
	double d = std::clamp(db * param_arquero.linea_por_metro, param_arquero.linea_m, param_arquero.linea_max_m);
	int rival = poseedor >= 0 && jugadores[size_t(poseedor)].equipo != e ? poseedor : -1;
	if (rival >= 0 && db <= param_arquero.achique_dist_rival) {
		// Mano a mano: ningún compañero cerca del camino del rival al arco.
		const Cuerpo &cr = jugadores[size_t(rival)].cuerpo;
		V3 arco = { gx, 0.0, 0.0 };
		V3 desde = { cr.x, 0.0, cr.z };
		bool solo = true;
		for (size_t o = 0; o < jugadores.size(); o++) {
			const JugadorCanchita &jo = jugadores[o];
			if (jo.equipo == e && !jo.arquero
					&& distancia_al_tramo(jo.cuerpo.x, jo.cuerpo.z, desde, arco) < param_arquero.achique_carril) {
				solo = false;
				break;
			}
		}
		if (solo) {
			double sale = segun_atributo(j.achique, param_arquero.achique_min, param_arquero.achique_max);
			d = std::max(d, std::min(sale, db - param_arquero.achique_margen_pelota));
		}
	}
	qx = gx + ux * d;
	qz = uz * d;
	factor = 1.0;
}

// La mano llegó. La agarra, la da en rebote o la roza (con la punta), según
// sus atributos, la rapidez de la pelota y qué tan justo llegó.
void Canchita::_atajar(int i, double distancia) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	int e = j.equipo;
	bool vuela = _es_estirada(j.clip_arquero);
	bool es_remate = _remate.activo && _remate.equipo != e;
	if (_pase_reg >= 0) {
		registro_pases[size_t(_pase_reg)].toca_id = _id(i);
		_cerrar_pase(PASE_ARQUERO);
	}
	double vin = std::sqrt(pelota.vel.x * pelota.vel.x + pelota.vel.y * pelota.vel.y + pelota.vel.z * pelota.vel.z);
	(void)distancia;
	// Qué tan justo llegó: la pasada más cercana de la pelota a la mano (o al
	// brazo), con el tramo de este paso más lo que va a recorrer en los
	// próximos. Con la distancia del primer paso que entra en la tolerancia,
	// la pelota rápida siempre llegaba por el borde y todo era un roce.
	V3 adelante = { pelota.pos.x + pelota.vel.x * PASO_SEG * PASOS_PASADA, pelota.pos.y,
		pelota.pos.z + pelota.vel.z * PASO_SEG * PASOS_PASADA };
	V3 mano = punto_de_contacto(c, clips[size_t(j.clip_toque)],
			_rumbo_contacto(j, c, j.clip_toque, c.rumbo, pelota.pos.x, pelota.pos.z));
	double pasada = _distancia_al_brazo(j, c, mano, pelota.previa, adelante);
	double borde = std::clamp(pasada / std::max(_tolerancia(i, j.clip_arquero), 1e-6), 0.0, 1.0);
	if (vuela) {
		cuenta.estiradas++;
	} else {
		cuenta.paradas++;
	}
	if (es_remate) {
		_remate.toco_arquero = true;
	} else {
		cuenta.salidas_arquero++;
	}
	bool agarra = false;
	V3 v = pelota.vel;
	if (borde > param_arquero.roce_desde && vin > param_arquero.rapidez_comoda_ms) {
		// Con la punta: sigue con parte de su rapidez, desviada hacia afuera
		// del arco (hacia el palo de su lado). Puede entrar igual.
		double afuera = pelota.pos.z >= 0.0 ? 1.0 : -1.0;
		double h = hipot(v.x, v.z);
		double rumbo = rumbo_de(v.x, v.z);
		// d(vz)/d(rumbo) = -vx: el signo que abre la pelota hacia `afuera`.
		double giro = (v.x >= 0.0 ? -1.0 : 1.0) * afuera * param_arquero.roce_desvio_rad;
		double s, co;
		mate::seno_coseno(rumbo + giro, s, co);
		double k = param_arquero.roce_conserva;
		v = { s * h * k, v.y * k + 0.1 * vin, co * h * k };
		cuenta.roces_arquero++;
		_rebote_arquero_en = paso;
	} else {
		double p = param_arquero.agarre_base + param_arquero.agarre_por_atributo * std::clamp(j.agarre / 100.0, 0.0, 1.0)
				- param_arquero.agarre_por_rapidez * std::max(0.0, vin - param_arquero.rapidez_comoda_ms)
				- (vuela ? param_arquero.castigo_estirada : 0.0) - param_arquero.castigo_borde * borde;
		agarra = _azar.uno() < std::clamp(p, 0.02, 0.98);
		if (!agarra) {
			// Rebote: hacia la cancha y hacia el costado de la pelota, lejos
			// del medio del arco; más prolijo con buena estirada.
			double lado = pelota.pos.z - c.z >= 0.0 ? 1.0 : -1.0;
			double angulo = rumbo_de(_ataca(e), lado * 1.2)
					+ _azar.normal() * param_arquero.rebote_dispersion_rad * (1.0 - 0.5 * std::clamp(j.estirada / 100.0, 0.0, 1.0));
			double rapidez = std::max(param_arquero.rebote_min_ms, vin * param_arquero.rebote_factor);
			double s, co;
			mate::seno_coseno(angulo, s, co);
			v = { s * rapidez, rapidez * (0.1 + 0.3 * _azar.uno()), co * rapidez };
			cuenta.rebotes_arquero++;
			_rebote_arquero_en = paso;
		}
	}
	if (agarra) {
		cuenta.agarres++;
		if (es_remate) {
			_cerrar_remate(REMATE_ATAJADO);
		}
		if (equipo_con_pelota != e && modo == PARTIDO) {
			_cerrar_posesion();
			cerebro.terminar_pared();
		}
		equipo_con_pelota = e;
		_en_manos = i;
		_suelta_en = paso + int64_t(param_arquero.retiene_seg / PASO_SEG + 0.5);
		// Los rivales no se la pueden disputar y se alejan hasta que juega.
		_reinicio_hasta = _suelta_en + REINICIO_PASOS;
		poseedor = i;
		_llevar_en_manos();
	} else {
		pelota.poner(pelota.pos, v, {});
		poseedor = -1;
	}
	_pase_activo = false;
	_receptor = -1;
	j.toque_pendiente = false;
	j.persigue = false;
	j.pensar_ya = true;
	j.hay_decision = false;
	j.inmune_hasta = paso + int64_t(param_toque.sin_rebote_seg / PASO_SEG + 0.5);
	_rebote_equipo = -1;
	ultimo_toque = i;
	ultimo_tipo = agarra ? TOQUE_CONTROL : TOQUE_ATAJADA;
	_desde_control = paso;
	_visto_paso = paso + _reaccion_pasos;
	_cambio = true;
}

// La estirada termina con el arquero tirado, 1,3 m al costado de su lugar
// (la cadera del clip; el cuerpo no se movió). Si la pelota no está en juego
// (gol, afuera, final) o la tiene en las manos, se levanta con
// Arquero_Levanta, que arranca en esa pose y termina parado en su lugar.
// Sin esto el modelo pasaba de tirado a parado en un cuadro (revisión del
// 2026-10-03: "cuando le meten gol se para instantáneamente"). Con la pelota
// suelta en juego se para enseguida, como antes: tirado 1,5 s no llegaría a
// ningún rebote y cambiaría cuántos goles hay.
void Canchita::_levantarse(int i, int clip_terminado) {
	const ParametrosArquero &a = param_arquero;
	if (clip_terminado < 0) {
		return;
	}
	int levanta = -1;
	if (clip_terminado == a.clips[ATAJA_VUELA_DER] || clip_terminado == a.clips[ATAJA_VUELA_ALTA_DER]) {
		levanta = a.clip_levanta_der;
	} else if (clip_terminado == a.clips[ATAJA_VUELA_IZQ] || clip_terminado == a.clips[ATAJA_VUELA_ALTA_IZQ]) {
		levanta = a.clip_levanta_izq;
	}
	bool fuera_de_juego = reglas && modo == PARTIDO && (_parada.activa || periodo == TERMINADO);
	if (levanta < 0 || !(fuera_de_juego || _en_manos == i)) {
		return;
	}
	if (!jugadores[size_t(i)].cuerpo.empezar(levanta)) {
		return;
	}
	if (_en_manos == i) {
		// No la suelta ni la saca hasta estar parado.
		int64_t parado = paso + int64_t(clips[size_t(levanta)].duracion / PASO_SEG + 0.5);
		_suelta_en = std::max(_suelta_en, parado);
		_reinicio_hasta = std::max(_reinicio_hasta, _suelta_en + REINICIO_PASOS);
	}
}

// Hasta qué alto cree el arquero que llegan sus manos (atajando arriba): lo
// que llegan de verdad (el gesto de atajar arriba, que es el más alto parado,
// más su tolerancia de alto) más el error del que calcula mal. Revisión del
// 2026-10-03: "salió a buscar un centro y le pasó por arriba; debería pasar
// cuando el golero es malo".
double Canchita::_alto_que_cree_alcanzar(int i) const {
	const ParametrosArquero &a = param_arquero;
	int clip = a.clips[ATAJA_ARRIBA];
	double llega = (clip >= 0 ? clips[size_t(clip)].punto_y : param_toque.pecho_hasta) + _tolerancia_alto(ATAJA_ARRIBA, true);
	return llega + segun_atributo(jugadores[size_t(i)].achique, a.salida_error_alto_m, 0.0);
}

// La pelota va en las manos, adelante del pecho y a la rapidez del arquero.
void Canchita::_llevar_en_manos() {
	const Cuerpo &c = jugadores[size_t(_en_manos)].cuerpo;
	double s, co;
	mate::seno_coseno(c.rumbo, s, co);
	pelota.poner({ c.x + s * MANOS_ADELANTE_M, MANOS_ALTO_M, c.z + co * MANOS_ADELANTE_M }, { c.vx, 0.0, c.vz }, {});
}

// La suelta adelante y la juega con el pie: la pelota cae con la física y él
// la controla como poseedor. Con reglas, solo si no la saca con la mano o de
// voleo (_decidir_saque_de_manos).
void Canchita::_soltar() {
	int i = _en_manos;
	JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	double s, co;
	mate::seno_coseno(c.rumbo, s, co);
	pelota.poner(pelota.pos, { c.vx + s * SUELTA_MS, 0.0, c.vz + co * SUELTA_MS }, {});
	_en_manos = -1;
	poseedor = i;
	ultimo_toque = i;
	ultimo_tipo = TOQUE_CONTROL;
	_desde_control = paso;
	j.pensar_ya = true;
	j.hay_decision = false;
	_visto_paso = paso;
	_cambio = true;
}

// El receptor (de un pase, un centro o un rebote) le pega de primera al arco
// si está en zona de tiro: de pie, de volea o de cabeza según la altura a la
// que le llega. En el modo ARCO lo que pidió rematar().
bool Canchita::_decidir_remate_de_primera(int i, V3 bola, double t) {
	JugadorCanchita &j = jugadores[size_t(i)];
	if (j.arquero) {
		return false;
	}
	Parte parte = parte_para(param_toque, bola.y);
	if (parte == NINGUNA) {
		return false;
	}
	if (modo == ARCO) {
		if (!j.remata_prueba) {
			return false;
		}
		j.toque = TOQUE_REMATE;
		return true;
	}
	// Amague de tiro libre: el socio le pega de primera sí o sí.
	bool amague = modo == PARTIDO && _amague_id >= 0 && _id(i) == _amague_id && paso <= _amague_hasta;
	// El centro de un compañero se juega de primera (volea o cabezazo) desde
	// más lejos que otra pelota: parándolo en el área, con los rivales
	// encima, la perdía la mitad de las veces (revisión del 2026-10-03:
	// "hacen centros y la pierden cuando la controlan o les rebotan").
	double geometria = param_remate.primera_geometria;
	if (_pase_activo && _pase_centro && _pateador >= 0 && _pateador != i
			&& jugadores[size_t(_pateador)].equipo == j.equipo) {
		geometria = std::min(geometria, param_remate.primera_geometria_centro);
	}
	if (modo != PARTIDO || (!amague && (!cerebro.alcanza_para_tirar(i, bola.x, bola.z)
			|| cerebro.factor_geometria(bola.x, bola.z, j.equipo) < geometria))) {
		return false;
	}
	// De espaldas al arco no le pega de primera con el pie: la controla (el
	// control lo deja de frente). De cabeza sí: la peina.
	if (!amague && parte != CABEZA && parte != PECHO
			&& _remate_de_espaldas(i, bola, param_pelota.medio_largo * _ataca(j.equipo), 0.0)) {
		cuenta.giros_al_arco++;
		return false;
	}
	_plan_bola = bola;
	_plan_t = t;
	cerebro.planeador = this;
	Decision d = cerebro.elegir_remate(_mundo, i, parte == CABEZA || parte == PECHO, _azar);
	cerebro.planeador = nullptr;
	j.toque = TOQUE_REMATE;
	j.meta_x = d.x;
	j.meta_alto = d.alto;
	j.meta_z = d.z;
	j.golpe_remate = d.golpe;
	return true;
}

// BUG-008 (revisión del usuario 2026-10-04: "le pegan de taco hacia el arco
// estando de espaldas"). El que patea va derecho a la pelota y la manda
// adonde sea (_perseguir): el remate salía también para atrás de adonde
// miraba. Devuelve true si este jugador, tocando la pelota en `bola`, queda
// de espaldas al punto y no le puede pegar de taco: tiene que darse vuelta.
bool Canchita::_remate_de_espaldas(int i, V3 bola, double meta_x, double meta_z) const {
	const ParametrosRemate &r = param_remate;
	if (r.taco_desde_rad <= 0.0) {
		return false;
	}
	const JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	// Al tocarla mira hacia la pelota (_perseguir); encima de ella, adonde ya mira.
	double fx = bola.x - c.x, fz = bola.z - c.z;
	double mira = fx * fx + fz * fz > 0.09 ? rumbo_de(fx, fz) : c.rumbo;
	if (std::abs(mate::envolver(rumbo_de(meta_x - bola.x, meta_z - bola.z) - mira)) <= r.taco_desde_rad) {
		return false;
	}
	bool en_area = std::abs(param_pelota.medio_largo * _ataca(j.equipo) - bola.x) <= Cerebro::AREA_LARGO
			&& std::abs(bola.z) <= Cerebro::AREA_MEDIO_ANCHO;
	return !(en_area && j.reglas.tiro >= r.taco_tiro);
}

double Canchita::_rapidez_remate(const JugadorCanchita &j, int golpe) const {
	const ParametrosRemate &r = param_remate;
	switch (golpe) {
		case REMATE_FUERTE:
			return segun_atributo(j.golpe, r.fuerte_min_ms, r.fuerte_max_ms);
		case REMATE_EFECTO:
			return segun_atributo(j.tiro, r.efecto_min_ms, r.efecto_max_ms);
		case REMATE_CABEZA:
			return segun_atributo(j.cabezazo, r.cabeza_min_ms, r.cabeza_max_ms);
		default:
			return segun_atributo(j.tiro, r.colocado_min_ms, r.colocado_max_ms);
	}
}

// El desvío estándar del ángulo del remate (rad).
double Canchita::_error_remate(const JugadorCanchita &j, int golpe, double de_lado, double alto_pelota, double llega_ms,
		double apretado, double cruce_pie_malo) const {
	const ParametrosRemate &r = param_remate;
	double atributo = std::clamp(golpe == REMATE_CABEZA ? j.cabezazo : j.tiro, 0.0, 100.0);
	double sigma = r.error_rad * (1.0 - 0.8 * atributo / 100.0) * r.error_tipo[std::clamp(golpe, 0, TIPOS_REMATE - 1)];
	sigma *= apretado * (1.0 + de_lado) * (1.0 + r.pie_malo * cruce_pie_malo);
	if (golpe == REMATE_CABEZA) {
		// El cabezazo con un rival encima sale peor que el remate de pie
		// apretado: salta chocando. `apretado` va de 1 (nadie a presion_m) a 1,5.
		sigma *= 1.0 + r.cabeza_marcado * (apretado - 1.0) * 2.0;
	}
	if (golpe != REMATE_CABEZA && alto_pelota > param_toque.pie_hasta) {
		sigma *= 1.0 + r.alto_factor;
	}
	if (llega_ms > 0.0) {
		sigma *= 1.0 + llega_ms / std::max(r.primera_ms, 1.0);
		// De primera y con un rival encima (el rebote en el área llena).
		if (golpe != REMATE_CABEZA) {
			sigma *= 1.0 + r.primera_marcado * (apretado - 1.0) * 2.0;
		}
	}
	return sigma;
}

// La patada al arco: `apuntar` busca con la física la que llega al punto
// elegido y después se le suma el error de ejecución. Nadie mira adónde va.
void Canchita::_patear_al_arco(int i, bool de_primera, double apretado) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	const ParametrosRemate &r = param_remate;
	int golpe = j.golpe_remate;
	V3 desde = pelota.pos;
	V3 meta = { j.meta_x, std::max(j.meta_alto, param_pelota.radio), j.meta_z };
	double rapidez = _rapidez_remate(j, golpe);
	double giro_lateral = 0.0;
	if (golpe == REMATE_EFECTO) {
		// La comba cierra hacia el medio del arco: el Magnus empuja hacia
		// -giro·vx (pelota.h), así que el signo sale del lado del punto.
		double lado = meta.z != 0.0 ? (meta.z > 0.0 ? 1.0 : -1.0) : (desde.z >= 0.0 ? -1.0 : 1.0);
		double hacia = meta.x >= desde.x ? 1.0 : -1.0;
		giro_lateral = r.giro_efecto * lado * hacia;
	}
	double elevacion = golpe == REMATE_GLOBO ? r.elevacion_globo : -1.0;
	V3 vel, giro;
	bool apunto = apuntar(param_pelota, desde, meta, rapidez, elevacion, giro_lateral, vel, giro);
	// Si a esa rapidez no llega en el aire (un colocado a 20 m/s desde 28 m
	// pica antes del arco), le pega más fuerte.
	for (int intento = 0; intento < 3 && !apunto && elevacion < 0.0; intento++) {
		rapidez *= 1.15;
		apunto = apuntar(param_pelota, desde, meta, rapidez, elevacion, giro_lateral, vel, giro);
	}
	if (!apunto) {
		// No hay patada exacta (demasiado cerca o demasiado lejos para ese
		// golpe): derecho al punto con la rapidez del golpe.
		double dx = meta.x - desde.x, dz = meta.z - desde.z;
		double l = std::max(hipot(dx, dz), 1e-6);
		double sube = std::clamp((meta.y - desde.y) / l, -0.2, 0.6);
		vel = { dx / l * rapidez, sube * rapidez, dz / l * rapidez };
		giro = { 0.0, giro_lateral, 0.0 };
	}
	// Error: según tiro (o cabezazo), el golpe, la presión, de costado a
	// adonde mira, el pie malo, la pelota alta y la que llega rápida.
	double h = hipot(vel.x, vel.z);
	double rumbo = rumbo_de(vel.x, vel.z);
	double elev = mate::arcotangente2(vel.y, h);
	double v = std::sqrt(h * h + vel.y * vel.y);
	double de_lado = std::abs(mate::envolver(rumbo - c.rumbo)) / mate::PI;
	double llega = de_primera ? std::sqrt(pelota.vel.x * pelota.vel.x + pelota.vel.y * pelota.vel.y + pelota.vel.z * pelota.vel.z)
							  : 0.0;
	if (_amague_id >= 0 && _id(i) == _amague_id) {
		// El amague está ensayado: el pase llega medido y él ya está
		// perfilado. Le pega como a una pelota quieta y de frente. Con el
		// error del remate de primera el amague rendía menos que patear
		// directo (8,3% contra 12,0% de 300 tiros libres,
		// tests/_diag_jugadas_v2.gd). Pateó: la jugada terminó.
		if (de_primera && paso <= _amague_hasta) {
			llega = 0.0;
			de_lado = 0.0;
		}
		_amague_id = -1;
	}
	double cruce = 0.0;
	if (j.pie_malo_lado != 0) {
		// Cruzarla hacia el lado de su pie malo (Cerebro::_cruce_al_pie_malo).
		double lateral = (meta.z - desde.z) / std::max(hipot(meta.x - desde.x, meta.z - desde.z), 1e-6) * _ataca(j.equipo);
		cruce = lateral * double(j.pie_malo_lado) >= 0.0 ? 0.0 : std::abs(lateral);
	}
	// El penal (también el de la tanda): con el tiro que le dan sus rasgos y
	// el ejercicio de penales.
	JugadorCanchita de_penal;
	const JugadorCanchita *patea = &j;
	if (reglas && _parada.activa && _parada.tipo == PENAL && i == _parada.ejecutor) {
		de_penal = j;
		de_penal.tiro = std::clamp(j.tiro * j.reglas.penal_factor + j.reglas.penal_puntos, 0.0, 100.0);
		patea = &de_penal;
	}
	double sigma = _error_remate(*patea, golpe, de_lado, desde.y, llega, apretado, cruce);
	if (patea != &j) {
		sigma *= param_reglas.penal_error;
	}
	rumbo += _azar.normal() * sigma;
	elev += _azar.normal() * sigma * r.error_vertical;
	double atributo = std::clamp(golpe == REMATE_CABEZA ? j.cabezazo : j.tiro, 0.0, 100.0);
	v *= 1.0 + _azar.normal() * r.error_rapidez * (1.0 - 0.7 * atributo / 100.0);
	double sr, cr, se, ce;
	mate::seno_coseno(rumbo, sr, cr);
	mate::seno_coseno(elev, se, ce);
	pelota.poner(desde, { sr * ce * v, se * v, cr * ce * v }, giro);

	cuenta.remates++;
	cuenta.remates_equipo[j.equipo & 1]++;
	cuenta.golpes[std::clamp(golpe, 0, TIPOS_REMATE - 1)]++;
	if (golpe == REMATE_CABEZA) {
		cuenta.remates_cabeza++;
	}
	if (de_primera) {
		cuenta.remates_primera++;
	}
	cuenta.distancia_remates += hipot(meta.x - desde.x, desde.z);
	RegistroRemate reg;
	reg.equipo = j.equipo;
	reg.pateador = i;
	reg.pateador_id = _id(i);
	_gol_de_id = reg.pateador_id;
	_gol_de_equipo = j.equipo;
	_gol_de_paso = paso;
	reg.minuto = reglas ? minuto() : double(paso) * PASO_SEG / 60.0;
	reg.golpe = golpe;
	reg.de_primera = de_primera;
	reg.de_lado = de_lado;
	reg.desde_x = desde.x;
	reg.desde_z = desde.z;
	reg.alto = meta.y;
	reg.lateral = meta.z;
	reg.rapidez = v;
	reg.presion_m = _rival_mas_cerca(i, desde.x, desde.z);
	int arquero = arquero_de(1 - j.equipo);
	reg.arquero_x = arquero >= 0 ? jugadores[size_t(arquero)].cuerpo.x : NAN;
	reg.arquero_z = arquero >= 0 ? jugadores[size_t(arquero)].cuerpo.z : NAN;
	reg.arquero_ocupado = arquero >= 0 && jugadores[size_t(arquero)].cuerpo.clip >= 0;
	reg.paso_remate = paso;
	registro.push_back(reg);
	_remate = Remate();
	_remate.indice = registro.size() - 1;
	_remate.activo = true;
	_remate.equipo = j.equipo;
	_remate.pateador = i;
	_remate.paso = paso;
	_remate.cabeza = golpe == REMATE_CABEZA;
	_remate.tras_rebote = paso - _rebote_arquero_en <= TRAS_REBOTE_PASOS;
	if (_remate.tras_rebote) {
		cuenta.remates_tras_rebote++;
	}
	_pase_activo = false;
	_receptor = -1;
	poseedor = -1;
	j.pateo_en = paso;
	j.remata_prueba = false;
	for (JugadorCanchita &o : jugadores) {
		o.quieto_seg = 0.0;
	}
}

void Canchita::_cerrar_remate(int resultado) {
	if (!_remate.activo) {
		return;
	}
	cuenta.resultados[std::clamp(resultado, 0, RESULTADOS_REMATE - 1)]++;
	_ultimo_resultado = resultado;
	_remate.activo = false;
	if (_remate.indice < registro.size()) {
		registro[_remate.indice].resultado = resultado;
	}
}

void Canchita::_gol(int marca) {
	if (reglas && modo == PARTIDO && periodo == TANDA) {
		// En la tanda el gol cierra el penal: lo anota _avanzar_tanda.
		_cerrar_remate(_remate.equipo == marca ? REMATE_GOL : REMATE_OTRO);
		_pase_activo = false;
		poseedor = -1;
		return;
	}
	cuenta.goles[marca & 1]++;
	int autor = -1;
	if (reglas && modo == PARTIDO) {
		autor = _remate.activo && _remate.equipo == marca ? _id(_remate.pateador) : -1;
		// El remate que se desvía en un rival (o da en el palo) y entra ya
		// cerró como remate, pero el gol es del que pateó. Sin esto quedaba
		// sin autor, como un gol en contra, y la tabla de goleadores no
		// cerraba con la de posiciones (tests/test_estadisticas_liga.gd).
		if (autor < 0 && _gol_de_id >= 0 && _gol_de_equipo == marca && paso - _gol_de_paso <= GOL_DEL_REMATE_PASOS) {
			autor = _gol_de_id;
		}
		// El pase o el centro que entra sin que lo toque un rival es gol del
		// que lo dio: quedaba como gol en contra (2 de cada 8 goles sin autor
		// en 300 partidos). Si la tocó último un rival, sí es en contra.
		if (autor < 0 && ultimo_toque >= 0 && ultimo_toque < int(jugadores.size())
				&& jugadores[size_t(ultimo_toque)].equipo == (marca & 1)) {
			autor = _id(ultimo_toque);
		}
		// `otro`: el que le dio el pase (la asistencia), -1 si no hubo.
		int asistente = autor >= 0 && autor == _asistido_id && !_remate.penal ? _asistente_id : -1;
		_anotar(EV_GOL, marca, autor, asistente, _remate.activo && _remate.penal ? 1 : 0, pelota.pos.x, pelota.pos.z);
		_adicion[lado() & 1] += param_reglas.adicion_gol_seg;
		if (_remate.activo && _remate.penal && _remate.equipo == marca) {
			cuenta.penales_gol++;
		}
	}
	if (_remate.activo) {
		if (_remate.equipo == marca) {
			if (_remate.cabeza) {
				cuenta.goles_cabeza++;
			}
			if (_remate.tras_rebote) {
				cuenta.goles_tras_rebote++;
			}
			_cerrar_remate(REMATE_GOL);
		} else {
			// En contra: el remate era del otro equipo.
			_cerrar_remate(REMATE_OTRO);
		}
	}
	_pase_activo = false;
	_receptor = -1;
	poseedor = -1;
	for (JugadorCanchita &j : jugadores) {
		j.toque_pendiente = false;
		j.persigue = false;
		j.pensar_ya = true;
	}
	if (modo != PARTIDO) {
		return;
	}
	_cerrar_posesion();
	cerebro.terminar_pared();
	if (reglas) {
		// Etapa 6: festejo y después el saque del medio, con el que saca
		// llegando a la pelota.
		_parar(SAQUE_MEDIO, 1 - (marca & 1), 0.0, 0.0, FESTEJO_PASOS);
		for (size_t i = 0; autor >= 0 && i < jugadores.size(); i++) {
			if (_id(int(i)) == autor && jugadores[i].equipo == (marca & 1)) {
				_empezar_festejo(int(i));
				break;
			}
		}
		return;
	}
	_saque_medio_en = paso + FESTEJO_PASOS;
	_saca_medio = 1 - (marca & 1);
}

// La pelota vuelve al medio (una reanudación, como el lateral: no es una
// corrección) y saca el que recibió el gol.
void Canchita::_sacar_del_medio() {
	_saque_medio_en = -1;
	_reiniciar(_saca_medio, 0.0, 0.0);
}

// Planeador: qué tan bueno es el remate de `de` al punto (alto, lateral) del
// arco rival con este golpe, con los mismos números que después lo ejecutan.
// Chance de ir adentro (el error de _error_remate a la distancia del arco)
// por chance de que el arquero no llegue (su reacción, su tolerancia y los
// clips de atajada, en una cuenta cerrada sin simular la pelota).
double Canchita::valor_remate(int de, int tipo, double alto, double lateral) {
	const JugadorCanchita &j = jugadores[size_t(de)];
	const Cuerpo &c = j.cuerpo;
	V3 bola = _plan_bola;
	double gx = param_pelota.medio_largo * _ataca(j.equipo);
	double dx = gx - bola.x, dz = lateral - bola.z;
	double d = hipot(dx, dz);
	if (d < 1.0) {
		return -1.0;
	}
	double g = param_pelota.gravedad;
	double t_vuelo;
	if (tipo == REMATE_GLOBO) {
		// Parábola sin aire con la elevación del globo.
		double s, co;
		mate::seno_coseno(param_remate.elevacion_globo, s, co);
		double abajo = 2.0 * co * co * (d * s / co - (alto - bola.y));
		if (abajo <= 1e-6) {
			return -1.0;
		}
		double v = std::sqrt(g * d * d / abajo);
		if (v > param_remate.fuerte_max_ms) {
			return -1.0;
		}
		t_vuelo = d / (v * co);
	} else {
		if (tipo == REMATE_CABEZA && alto > 1.2) {
			// De cabeza no se la manda arriba del arquero.
			return -1.0;
		}
		// El aire la frena: llega en ~10% más que a rapidez constante.
		t_vuelo = d / _rapidez_remate(j, tipo) * 1.1;
	}
	// Adentro: el error del ángulo a esta distancia, de costado y de alto.
	double de_lado = std::abs(mate::envolver(rumbo_de(dx, dz) - c.rumbo)) / mate::PI;
	double presion = _rival_mas_cerca(de, bola.x, bola.z);
	double apretado = 1.0 + 0.5 * std::clamp(1.0 - presion / param_toque.presion_m, 0.0, 1.0);
	double sigma = _error_remate(j, tipo, de_lado, bola.y, 0.0, apretado, 0.0);
	// El error de lado es perpendicular al remate: sobre la línea del arco se
	// estira con el ángulo (de frente, nada; a 60 grados, el doble). Sin esto
	// el remate desde el costado valía lo mismo que de frente.
	double de_frente = std::max(std::abs(dx) / d, 0.1);
	double sd_lado = std::max(d * sigma / de_frente, 0.02);
	double sd_alto = std::max(d * sigma * param_remate.error_vertical, 0.02);
	// Normal acumulada aproximada con la logística (1,702 x): sin erf.
	auto fi = [](double x) {
		return 1.0 / (1.0 + mate::exponencial(-1.702 * x));
	};
	double adentro = param_pelota.arco_medio_ancho - param_pelota.radio;
	double arriba = param_pelota.arco_alto - param_pelota.radio;
	double p_lado = fi((adentro - lateral) / sd_lado) - fi((-adentro - lateral) / sd_lado);
	double p_alto = fi((arriba - alto) / sd_alto);
	double p_adentro = std::clamp(p_lado * p_alto, 0.0, 1.0);
	// El arquero: cuánto se corre hasta que la pelota pasa por su altura.
	int k = arquero_de(1 - j.equipo);
	double p_pasa = 1.0;
	if (k >= 0) {
		const Cuerpo &ck = jugadores[size_t(k)].cuerpo;
		double frac = std::clamp((ck.x - bola.x) / (gx - bola.x), 0.0, 1.0);
		double pz = bola.z + dz * frac;
		double py = bola.y + (alto - bola.y) * frac;
		if (tipo == REMATE_GLOBO) {
			// La parábola: en la mitad del vuelo está g·t²/8 más arriba.
			py = std::max(py, 4.0 * frac * (1.0 - frac) * g * t_vuelo * t_vuelo / 8.0);
		}
		double hueco = std::abs(pz - ck.z);
		double tiene = t_vuelo * frac - _reaccion_arquero(k);
		double tol = _tolerancia(k, ATAJA_AGARRA);
		double alcance = 0.0;
		for (int a = 0; a < CLIPS_ARQUERO; a++) {
			int clip = param_arquero.clips[a];
			if (clip < 0) {
				continue;
			}
			const Clip &kc = clips[size_t(clip)];
			double tc = std::max(kc.contacto_seg, 0.0);
			double abajo = _alto_minimo(a, kc);
			if (tiene < tc || py < abajo || py > kc.punto_y + _tolerancia_alto(a, true)) {
				continue;
			}
			// La mano al costado del clip, más lo que se acomoda antes de
			// arrancarlo (sin darse vuelta, como en _plan_atajar); parado, hasta
			// parada_max_m.
			double corre = 0.5 * _factor_acomodarse(ck) * ck.vel_max * ck.cansancio * (tiene - tc);
			if (!_es_estirada(a)) {
				corre = std::min(corre, param_arquero.parada_max_m);
			}
			alcance = std::max(alcance, std::abs(kc.punto_x) + tol + corre);
		}
		p_pasa = fi((hueco - alcance) / 0.3);
	}
	return p_adentro * p_pasa;
}
