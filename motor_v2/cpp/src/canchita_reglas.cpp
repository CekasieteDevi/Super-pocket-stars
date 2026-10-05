// Etapa 6 del Motor V2 (docs/motor_v2.md, "Etapa 6 — Reglas y pelota
// parada"): lo que la canchita hace con las reglas activas (reglas.h). Es la
// misma clase que canchita.cpp, en otro archivo para que cada uno se lea solo.

#include "canchita.h"
#include "matematica_fija.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

namespace {
double hipot(double x, double z) {
	return std::sqrt(x * x + z * z);
}

double rumbo_de(double dx, double dz) {
	return mate::arcotangente2(dx, dz);
}

// Mientras dura la parada nadie del rival puede tocar la pelota: hasta el saque.
constexpr int64_t NUNCA = INT64_MAX / 4;

int64_t pasos_de(double segundos) {
	return int64_t(segundos / Canchita::PASO_SEG + 0.5);
}

// A esto del área chica (adentro del arco, sobre la línea) se para el arquero
// en una pelota parada.
constexpr double ARQUERO_EN_LA_LINEA_M = 0.5;
// La salida del que se va: pasando la línea, para que se lo vea salir.
constexpr double AFUERA_M = 3.0;
// El que entra espera en la línea, frente al banco (del lado de -z).
constexpr double BANCO_Z = -(Cerebro::MEDIO_ANCHO + 1.0);
// El que sale va corriendo, como el expulsado, y el lesionado al trote. Con
// todos al paso (0,35, como en el motor espacial) el saque esperaba hasta
// 17 s. Con 0,5 y 0,35 el lesionado tardaba 11 s en cruzar la cancha: en la
// tercera revisión visual de la etapa 7 se veía a los demás parados esperando.
constexpr double FACTOR_SALIR = 0.7;
constexpr double FACTOR_SALIR_EXPULSADO = 0.85;
constexpr double FACTOR_SALIR_LESIONADO = 0.5;
// Detector de la etapa 6: el ejecutor que, lejos de su lugar y ya arrancado,
// va a menos de esto, camina.
constexpr double CAMINA_MS = 3.0;
constexpr double ARRANCA_SEG = 0.8;
// En qué parte del clip de caer el jugador está en el piso (medido en
// jugador.glb: el pecho a 2 cm del piso entre el 30 y el 50% de Caer).
constexpr double EN_EL_PISO_DEL_CLIP = 0.4;
// Después del corte de la tarjeta, cuánto falta para el saque: los 3 ticks
// de VistaCancha3D._cortar_despues_de_tarjeta (LATERAL_PREPARA_TICKS).
constexpr double CORTE_ANTES_DEL_SAQUE_SEG = 0.75;
constexpr double CAMINA_SOSTENIDA_SEG = 0.5;
// El que saca con el pie y no puede patear en este tiempo deja que saque otro.
constexpr double SACANDO_MAX_SEG = 6.0;
// Lateral: en qué parte de Lateral_Prepara ya tiene la pelota arriba, y lo
// máximo que la sostiene ahí (el saque lo corta antes).
constexpr double LATERAL_ARRIBA_DEL_CLIP = 0.95;
// Lateral: cuánto puede faltarle girar hacia la cancha para levantar la pelota.
constexpr double LATERAL_DE_FRENTE_RAD = 0.5;
// Y lo máximo que se espera a que gire desde que llegó.
constexpr double LATERAL_GIRA_MAX_SEG = 2.0;
constexpr double SOSTEN_LATERAL_SEG = 30.0;
// Saque del medio: cuánto puede pasarse de la mitad de la cancha uno que ya
// está en su lado, y lo máximo que se espera a que todos vuelvan (cruzar la
// cancha entera al trote son unos 20 s).
constexpr double EN_SU_MITAD_M = 0.5;
constexpr double SAQUE_MEDIO_MAX_SEG = 30.0;
constexpr double LATERAL_LENTO_SEG = 17 * 0.25;
// El que va a su marca de una pelota parada trota firme; después del gol,
// caminando (festejo).
constexpr double FACTOR_MARCA = 0.9;
constexpr double FACTOR_FESTEJO = 0.5;
// Etapa 8: hasta qué distancia va a sacar el que eligió el club. Eran 80 m en
// el motor espacial: con los 22 m de cualquier ejecutor, el elegido llegaba
// el 10% de las veces y elegir pateador no servía.
constexpr double DESIGNADO_MAX_M = 80.0;
// Etapa 8, jugadas preparadas (core/jugadas.gd). Córner corto: a cuánto de
// las dos rayas espera el socio (queda a 7 m del banderín; los rivales, a
// 9,15). Córner en bloque: cuántos se juntan, dónde (metros del fondo y del
// medio del arco, del lado del segundo palo) y adónde arrancan y va el centro.
// Amague: a cuánto de la pelota se para el que le pega.
constexpr double CORTO_ADENTRO_M = 5.0;
constexpr int BLOQUE_CUANTOS = 5;
constexpr double BLOQUE_DEL_FONDO_M = 9.0;
constexpr double BLOQUE_DEL_MEDIO_M = 6.0;
constexpr double BLOQUE_LLEGA_DEL_FONDO_M = 8.0;
constexpr double BLOQUE_LLEGA_DEL_MEDIO_M = 3.0;
constexpr double AMAGUE_AL_COSTADO_M = 4.0;
constexpr double AMAGUE_SEG = 3.0;
// Córner corto: hasta cuándo después del saque el socio centra sí o sí.
constexpr double CORTO_SEG = 4.0;
// Segundos de más que el saque espera cuando hay jugada. Sin esto, en 8 de 8
// córners forzados el socio no llegaba a su lugar antes del saque
// (tests/_diag_jugadas_v2.gd).
constexpr double JUGADA_ESPERA_SEG = 4.0;
// A cuánto de su lugar el socio ya sirve para la jugada.
constexpr double SOCIO_EN_SU_LUGAR_M = 2.5;
// Córner en bloque: suben por lo menos estos.
constexpr int BLOQUE_MINIMO = 4;
// Etapa 8, el festejo en el banderín: a cuánto de las dos rayas se para el
// que hizo el gol y a cuánto de su lugar ya festeja.
constexpr double FESTEJO_DEL_BANDERIN_M = 2.5;
constexpr double FESTEJO_LLEGA_M = 1.0;
// Dónde se para cada uno del grupo respecto del goleador: metros hacia el
// medio de la cancha (a lo largo, a lo ancho).
constexpr double FESTEJO_RONDA[5][2] = { { 0.0, 0.0 }, { 1.6, 0.3 }, { 0.4, 1.7 }, { 1.9, 1.8 }, { 3.0, 0.9 } };
// Detrás de la pelota se para el ejecutor de un saque con el pie; en el
// penal, a esto para tomar carrera.
constexpr double DETRAS_DE_LA_PELOTA_M = 0.6;
constexpr double CARRERA_PENAL_M = 2.0;
// La tanda: más de esto y se termina (no pasa: hay 22 pateadores).
constexpr int TANDA_MAX = 60;
} // namespace

void Canchita::agregar_suplente(int equipo, const JugadorCanchita &j, const FichaCerebro &f) {
	Suplente s;
	s.jugador = j;
	s.jugador.equipo = equipo;
	s.ficha = f;
	s.ficha.equipo = equipo;
	banco.push_back(s);
}

// Segundos de verdad con la pelota en juego en este tiempo.
double Canchita::reloj_seg() const {
	return double(paso - _inicio_periodo - _pasos_parados) * PASO_SEG;
}

// Segundos del reloj mostrado por cada segundo de verdad (22,5 con dos
// minutos de verdad por tiempo).
double Canchita::escala_reloj() const {
	return param_reglas.minutos_tiempo * 60.0 / std::max(param_reglas.segundos_tiempo, 1.0);
}

// Un tiempo del alargue dura lo que le toca por sus minutos mostrados.
double Canchita::segundos_periodo() const {
	if (periodo == ALARGUE_1 || periodo == ALARGUE_2) {
		return param_reglas.segundos_tiempo * param_reglas.minutos_alargue / std::max(param_reglas.minutos_tiempo, 1.0);
	}
	return param_reglas.segundos_tiempo;
}

// En segundos del reloj mostrado.
double Canchita::adicion_seg() const {
	return std::clamp(_adicion[lado() & 1], param_reglas.adicion_min_seg, param_reglas.adicion_max_seg);
}

// El minuto que muestra el reloj (0 a 90 y el agregado).
double Canchita::minuto() const {
	double desde = 0.0;
	if (periodo == SEGUNDO_TIEMPO) {
		desde = param_reglas.minutos_tiempo;
	} else if (periodo == ALARGUE_1) {
		desde = param_reglas.minutos_tiempo * 2.0;
	} else if (periodo == ALARGUE_2) {
		desde = param_reglas.minutos_tiempo * 2.0 + param_reglas.minutos_alargue;
	} else if (periodo >= TANDA) {
		// La tanda y el final: el reloj queda donde terminó el juego.
		return _minuto_final;
	}
	return desde + reloj_seg() * escala_reloj() / 60.0;
}

void Canchita::_anotar(int tipo, int equipo, int jugador, int otro, int detalle, double x, double z) {
	EventoPartido e;
	e.paso = paso;
	e.minuto = minuto();
	e.tipo = tipo;
	e.equipo = equipo;
	e.jugador = jugador;
	e.otro = otro;
	e.detalle = detalle;
	e.x = x;
	e.z = z;
	eventos.push_back(e);
}

void Canchita::_empezar_reglas() {
	periodo = PRIMER_TIEMPO;
	eventos.clear();
	afuera.clear();
	energia_al_salir.clear();
	_entrando.clear();
	_adelantados.clear();
	_tarjeta_paso = -1;
	corte_paso = -1;
	_inicio_periodo = paso;
	_pasos_parados = 0;
	_adicion[0] = _adicion[1] = 0.0;
	goles_tanda[0] = goles_tanda[1] = 0;
	pateados_tanda[0] = pateados_tanda[1] = 0;
	_orden_tanda[0].clear();
	_orden_tanda[1].clear();
	_turno_tanda = 0;
	_tanda_pateo = false;
	for (JugadorCanchita &j : jugadores) {
		j.energia = j.reglas.energia;
		j.amarillas = 0;
		j.lesionado = false;
		j.en_el_piso_hasta = -1;
	}
	_desgastar();
	_saco_primero = 0;
	// La pelota ya está en el medio: sin esto arrancaba en el piso (y = 0) y
	// el primer paso la subía al radio (un SALTO_PELOTA).
	pelota.poner({ 0.0, param_pelota.radio, 0.0 }, {}, {});
	_parar(SAQUE_MEDIO, _saco_primero, 0.0, 0.0);
}

// --- Paradas ---

// Se corta el juego: la pelota se repone en (x, z) y la saca `equipo`. Cada
// uno va a su lugar corriendo o trotando: nadie se teletransporta.
void Canchita::_parar(int tipo, int equipo, double x, double z, int64_t demora) {
	if (modo == PARTIDO && equipo != equipo_con_pelota) {
		_cerrar_posesion();
	}
	cerebro.terminar_pared();
	// Los cambios entran en las paradas largas (no en el lateral ni en el
	// penal: ahí el saque es enseguida o el juego no puede esperar).
	if (periodo < TANDA && (tipo == SAQUE_ARCO || tipo == TIRO_LIBRE || tipo == SAQUE_MEDIO)) {
		_hacer_cambios(false);
	}
	const ParametrosReglas &r = param_reglas;
	_parada = Parada();
	_parada.activa = true;
	_parada.tipo = tipo;
	_parada.equipo = equipo;
	_parada.x = std::clamp(x, -_medio_x(), _medio_x());
	_parada.z = std::clamp(z, -_medio_z(), _medio_z());
	_parada.desde = paso;
	_parada.reponer_en = paso + demora + (tipo == SAQUE_MEDIO && demora == 0 ? 0 : pasos_de(r.reponer_seg));
	_parada.minimo = paso + demora + pasos_de(r.pausa_seg[tipo]);
	_parada.tope = paso + demora + pasos_de(r.espera_max_seg[tipo]);
	_parada.sin_offside = tipo == LATERAL || tipo == SAQUE_ARCO || tipo == CORNER;
	_parada.tanda = periodo == TANDA;
	if (tipo == LATERAL) {
		_parada.distancia = r.distancia_lateral_m;
	} else if (tipo == SAQUE_ARCO || tipo == PENAL) {
		_parada.distancia = 0.0;
	} else {
		_parada.distancia = r.distancia_libre_m;
	}
	if (tipo == TIRO_LIBRE) {
		_parada.tipo_libre = _tipo_de_libre(equipo, _parada.x, _parada.z);
		cuenta.tiros_libres[_parada.tipo_libre]++;
	}
	cuenta.paradas_tipo[tipo]++;
	equipo_con_pelota = equipo;
	poseedor = -1;
	_pase_activo = false;
	_receptor = -1;
	_pateador = -1;
	_en_manos = -1;
	_mano = SaqueMano();
	_saque_medio_en = -1;
	_adelantados.clear();
	_rebote_equipo = -1;
	_reinicio_hasta = NUNCA;
	for (JugadorCanchita &j : jugadores) {
		j.toque_pendiente = false;
		j.persigue = false;
		j.pensar_ya = true;
		j.hay_decision = false;
		j.toque = TOQUE_NADA;
	}
	_parada.ejecutor = _elegir_ejecutor(tipo, equipo, _parada.x, _parada.z, _parada.tipo_libre);
	_elegir_jugada();
	_lugar_del_ejecutor();
	_marcar_parada();
	_visto_paso = paso;
	_cambio = true;
}

// Jugadas.elegir_corner y Jugadas.se_usa: si el club sabe alguna jugada para
// esta pelota parada, esta vez la usa con su probabilidad. Tira el azar solo
// si sabe alguna: el partido de los que no saben ninguna no cambia.
void Canchita::_elegir_jugada() {
	Parada &p = _parada;
	p.jugada = JUGADA_NADA;
	p.socio = -1;
	if (p.tanda || periodo >= TANDA) {
		return;
	}
	const PlanEquipo &plan = cerebro.planes[p.equipo & 1];
	if (p.tipo == CORNER) {
		bool corto = plan.corner_corto > 0.0, bloque = plan.corner_bloque > 0.0;
		if (!corto && !bloque) {
			return;
		}
		bool elige_corto = corto && (!bloque || _azar.uno() < 0.5);
		if (_azar.uno() < (elige_corto ? plan.corner_corto : plan.corner_bloque)) {
			p.jugada = elige_corto ? JUGADA_CORNER_CORTO : JUGADA_CORNER_BLOQUE;
		}
	} else if (p.tipo == TIRO_LIBRE && p.tipo_libre == LIBRE_DIRECTO && plan.amague > 0.0) {
		if (_azar.uno() < plan.amague) {
			p.jugada = JUGADA_AMAGUE;
		}
	}
	// La jugada se arma: el saque espera un poco más a que lleguen.
	if (p.jugada != JUGADA_NADA) {
		p.tope += pasos_de(JUGADA_ESPERA_SEG);
	}
}

bool Canchita::_socio_valido() const {
	const Parada &p = _parada;
	return p.socio >= 0 && p.socio < int(jugadores.size()) && p.socio != p.ejecutor
			&& jugadores[size_t(p.socio)].equipo == p.equipo;
}

// Quién saca (MotorEspacial._elegir_ejecutor): el arquero el saque de arco;
// el mejor en lo suyo de los que están cerca el córner y el tiro libre que
// se cuelga o va al arco; el de más tiro el penal; el que antes llega, el
// lateral y el tiro libre corto. Nunca uno que está en el piso.
int Canchita::_elegir_ejecutor(int tipo, int equipo, double x, double z, int tipo_libre, int excluir) const {
	if (tipo == SAQUE_ARCO) {
		int a = arquero_de(equipo);
		if (a >= 0) {
			return a;
		}
	}
	if (tipo == PENAL && periodo == TANDA) {
		const std::vector<int> &orden = _orden_tanda[equipo & 1];
		if (!orden.empty()) {
			return orden[size_t(pateados_tanda[equipo & 1]) % orden.size()];
		}
	}
	// El que eligió el club para esta pelota parada (Equipo > Roles), si está
	// en la cancha. El penal lo patea esté donde esté; a las otras va si está
	// a menos de DESIGNADO_MAX_M (más lejos saca el que está cerca, como
	// cuando el especialista quedó en la otra punta).
	int marca = 0;
	if (tipo == PENAL) {
		marca = DESIGNADO_PENALES;
	} else if (tipo == CORNER) {
		marca = DESIGNADO_CORNERS;
	} else if (tipo == TIRO_LIBRE && tipo_libre == LIBRE_DIRECTO) {
		marca = DESIGNADO_LIBRES_CERCA;
	} else if (tipo == TIRO_LIBRE && tipo_libre == LIBRE_CENTRO) {
		marca = DESIGNADO_LIBRES_LEJOS;
	}
	for (size_t i = 0; marca != 0 && i < jugadores.size(); i++) {
		const JugadorCanchita &j = jugadores[i];
		if (j.equipo != equipo || j.arquero || paso < j.en_el_piso_hasta || int(i) == excluir
				|| !(j.reglas.designado & marca)) {
			continue;
		}
		if (tipo == PENAL || hipot(j.cuerpo.x - x, j.cuerpo.z - z) <= DESIGNADO_MAX_M) {
			return int(i);
		}
	}
	int mejor = -1, cerca = -1;
	double mejor_valor = -1e9, t_cerca = 1e18;
	for (size_t i = 0; i < jugadores.size(); i++) {
		const JugadorCanchita &j = jugadores[i];
		if (j.equipo != equipo || j.arquero || paso < j.en_el_piso_hasta || int(i) == excluir) {
			continue;
		}
		double d = hipot(j.cuerpo.x - x, j.cuerpo.z - z);
		double t = tiempo_de_llegada(j.cuerpo, x, z, param_reglas.llegada_m);
		if (tipo == SAQUE_MEDIO) {
			// El más cercano, no el que antes llega: todos están parados en
			// su casillero y el de punta queda justo entre el volante y la
			// pelota. Con el volante más rápido sacaba él, chocaba de atrás
			// con el de punta y el saque no salía nunca (8 de 300 partidos
			// desparejos, semilla 97000).
			t = d;
		}
		if (t < t_cerca) {
			t_cerca = t;
			cerca = int(i);
		}
		double valor;
		if (tipo == PENAL) {
			valor = j.tiro;
		} else if (tipo == CORNER || (tipo == TIRO_LIBRE && tipo_libre == LIBRE_CENTRO)) {
			valor = j.reglas.centros;
		} else if (tipo == TIRO_LIBRE && tipo_libre == LIBRE_DIRECTO) {
			valor = j.reglas.tiros_libres;
		} else {
			continue;
		}
		// El penal lo patea el de más tiro esté donde esté; los demás, si
		// llegan (MotorEspacial: el que estaba a 74 m del banderín aparecía
		// encima de la pelota).
		if (tipo != PENAL && d > param_reglas.ejecutor_max_m) {
			continue;
		}
		if (valor > mejor_valor) {
			mejor_valor = valor;
			mejor = int(i);
		}
	}
	return mejor >= 0 ? mejor : cerca;
}

// MotorEspacial.tipo_de_falta: al arco si el ángulo da y le da la pierna al
// que la patearía; si no, colgada al área si está cerca (o lejos, si el
// estilo cuelga de lejos); si no, corta.
int Canchita::_tipo_de_libre(int equipo, double x, double z) const {
	const ParametrosReglas &r = param_reglas;
	double gx = Cerebro::MEDIO_LARGO * _ataca(equipo);
	double d_arco = hipot(gx - x, z);
	int pateador = _elegir_ejecutor(TIRO_LIBRE, equipo, x, z, LIBRE_DIRECTO);
	if (pateador >= 0) {
		double alcance = segun_atributo(jugadores[size_t(pateador)].reglas.tiros_libres, r.rango_libre_malo,
				r.rango_libre_bueno);
		if (d_arco <= alcance && Cerebro::factor_angulo(x, z, equipo) >= r.angulo_minimo_tiro_libre) {
			return LIBRE_DIRECTO;
		}
	}
	if (d_arco <= r.dist_libre_al_area) {
		return LIBRE_CENTRO;
	}
	if (d_arco <= r.dist_para_colgar_lejos && r.cuelga_lejos[equipo & 1]) {
		return LIBRE_CENTRO;
	}
	return LIBRE_CORTO;
}

// Dónde espera el ejecutor: afuera de la línea con la pelota en las manos
// (lateral), tomando carrera (penal) o detrás de la pelota mirando adonde
// la va a jugar.
void Canchita::_lugar_del_ejecutor() {
	Parada &p = _parada;
	double s = _ataca(p.equipo);
	if (p.tipo == LATERAL) {
		double lado = p.z >= 0.0 ? 1.0 : -1.0;
		p.lugar_x = p.x;
		p.lugar_z = lado * (_medio_z() + param_reglas.llegada_m * 0.5);
		return;
	}
	double hacia_x = Cerebro::MEDIO_LARGO * s - p.x, hacia_z = -p.z;
	if (p.tipo == SAQUE_ARCO) {
		hacia_x = s;
		hacia_z = 0.0;
	} else if (p.tipo == SAQUE_MEDIO) {
		hacia_x = -s;
		hacia_z = 0.0;
	}
	double l = std::max(hipot(hacia_x, hacia_z), 1e-6);
	double atras = p.tipo == PENAL ? CARRERA_PENAL_M : DETRAS_DE_LA_PELOTA_M;
	if (p.tipo == SAQUE_MEDIO) {
		// En el saque del medio el que saca está en su mitad: detrás de la
		// pelota hacia su arco.
		p.lugar_x = p.x - s * DETRAS_DE_LA_PELOTA_M;
		p.lugar_z = p.z;
		return;
	}
	p.lugar_x = p.x - hacia_x / l * atras;
	p.lugar_z = p.z - hacia_z / l * atras;
}

// El casillero del saque del medio (MotorEspacial._reiniciar_desde_medio): la
// formación comprimida en su mitad, afuera del círculo y nunca del lado rival.
void Canchita::_ubicar_saque_del_medio(int i, double &x, double &z) const {
	const JugadorCanchita &j = jugadores[size_t(i)];
	const FichaCerebro &f = cerebro.fichas[size_t(i)];
	double s = _ataca(j.equipo);
	x = (-Cerebro::MEDIO_LARGO + (f.base_x + Cerebro::MEDIO_LARGO) * COMPRESION_SAQUE) * s;
	z = f.base_z;
	double radio = param_reglas.radio_circulo_m + 0.5;
	double l = hipot(x, z);
	if (l < radio) {
		// Se sale del círculo hacia atrás, nunca hacia adelante.
		double dx = l > 0.01 ? x / l : -s, dz = l > 0.01 ? z / l : 0.0;
		if (dx * s > 0.0) {
			dx = -dx;
		}
		x = dx * radio;
		z = dz * radio;
	}
	x = s > 0.0 ? std::min(x, -0.5) : std::max(x, 0.5);
}

void Canchita::_marcar_parada() {
	size_t n = jugadores.size();
	_marca_x.assign(n, 0.0);
	_marca_z.assign(n, 0.0);
	_tiene_marca.assign(n, 0);
	_bloque.clear();
	Parada &p = _parada;
	p.socio = -1;
	const ParametrosReglas &r = param_reglas;
	int ataca = p.equipo, defiende = 1 - p.equipo;
	double s = _ataca(ataca);
	double gx = Cerebro::MEDIO_LARGO * s;
	auto marcar = [&](size_t i, double x, double z) {
		_marca_x[i] = x;
		_marca_z[i] = z;
		_tiene_marca[i] = 1;
	};
	switch (p.tipo) {
		case SAQUE_MEDIO:
			for (size_t i = 0; i < n; i++) {
				if (int(i) == p.ejecutor) {
					continue;
				}
				double x, z;
				_ubicar_saque_del_medio(int(i), x, z);
				marcar(i, x, z);
			}
			return;
		case CORNER:
			_marcar_area(ataca, r.suben_corner[ataca & 1]);
			if (p.jugada == JUGADA_CORNER_CORTO) {
				// Córner corto: de los que esperan afuera del área, el que está
				// más cerca se acerca al banderín, más acá de los 9,15 de los
				// rivales. Con el de mejor pase, el saque salía antes de que
				// llegara (venía de 40 m) y el pase se iba largo.
				double sx = p.x - s * CORTO_ADENTRO_M, sz = p.z - (p.z >= 0.0 ? 1.0 : -1.0) * CORTO_ADENTRO_M;
				int mejor = -1;
				double cerca = 1e18;
				for (size_t i = 0; i < n; i++) {
					const JugadorCanchita &j = jugadores[i];
					if (j.equipo != ataca || j.arquero || int(i) == p.ejecutor || !_tiene_marca[i]
							|| std::abs(gx - _marca_x[i]) <= Cerebro::AREA_LARGO) {
						continue;
					}
					double d = hipot(j.cuerpo.x - sx, j.cuerpo.z - sz);
					if (d < cerca) {
						cerca = d;
						mejor = int(i);
					}
				}
				if (mejor >= 0) {
					p.socio = mejor;
					marcar(size_t(mejor), sx, sz);
				} else {
					p.jugada = JUGADA_NADA;
				}
			}
			break;
		case TIRO_LIBRE:
			if (p.tipo_libre == LIBRE_DIRECTO) {
				// Barrera (MotorEspacial._marca_en_tiro_libre): los defensores más
				// cerca de su puesto, a 9,15 en la línea de la pelota al arco,
				// hombro con hombro. Cuantos más cuanto más de frente y cerca.
				double hx = gx - p.x, hz = -p.z;
				double l = std::max(hipot(hx, hz), 1e-6);
				hx /= l;
				hz /= l;
				double px = p.x + hx * r.distancia_libre_m, pz = p.z + hz * r.distancia_libre_m;
				int tam = std::clamp(2 + int(cerebro.factor_geometria(p.x, p.z, ataca) * 6.0 + 0.5), 2, 5);
				for (int k = 0; k < tam; k++) {
					int mejor = -1;
					double d_mejor = 1e18;
					for (size_t i = 0; i < n; i++) {
						const JugadorCanchita &j = jugadores[i];
						if (j.equipo != defiende || j.arquero || _tiene_marca[i]) {
							continue;
						}
						double d = hipot(j.cuerpo.x - px, j.cuerpo.z - pz);
						if (d < d_mejor) {
							d_mejor = d;
							mejor = int(i);
						}
					}
					if (mejor < 0) {
						break;
					}
					double lado = (double(k) - double(tam - 1) * 0.5) * 0.8;
					marcar(size_t(mejor), px - hz * lado, pz + hx * lado);
				}
				_marcar_area(ataca, std::max(r.suben_corner[ataca & 1] - r.menos_en_directo, 2));
				if (p.jugada == JUGADA_AMAGUE) {
					// Amague: el de más tiro se para al costado de la pelota,
					// del lado del medio de la cancha, donde la barrera no tapa.
					int mejor = -1;
					double tiro = -1.0;
					for (size_t i = 0; i < n; i++) {
						const JugadorCanchita &j = jugadores[i];
						if (j.equipo != ataca || j.arquero || int(i) == p.ejecutor || paso < j.en_el_piso_hasta) {
							continue;
						}
						if (j.tiro > tiro) {
							tiro = j.tiro;
							mejor = int(i);
						}
					}
					if (mejor >= 0) {
						double nx = -hz, nz = hx;
						double lado = (p.z + nz * AMAGUE_AL_COSTADO_M) * (p.z + nz * AMAGUE_AL_COSTADO_M)
								<= (p.z - nz * AMAGUE_AL_COSTADO_M) * (p.z - nz * AMAGUE_AL_COSTADO_M) ? 1.0 : -1.0;
						p.socio = mejor;
						marcar(size_t(mejor), p.x + nx * lado * AMAGUE_AL_COSTADO_M - hx * 0.5,
								p.z + nz * lado * AMAGUE_AL_COSTADO_M - hz * 0.5);
					} else {
						p.jugada = JUGADA_NADA;
					}
				}
			} else if (p.tipo_libre == LIBRE_CENTRO) {
				_marcar_area(ataca, std::max(r.suben_corner[ataca & 1] - r.menos_en_centro, 2));
			}
			break;
		case PENAL:
			for (size_t i = 0; i < n; i++) {
				const JugadorCanchita &j = jugadores[i];
				if (int(i) == p.ejecutor) {
					continue;
				}
				if (j.arquero && j.equipo == defiende) {
					marcar(i, gx - s * ARQUERO_EN_LA_LINEA_M * 0.4, 0.0);
					continue;
				}
				if (p.tanda) {
					// Los que no patean miran desde el círculo central, repartidos.
					double ang = _azar.uno() * 2.0 * mate::PI;
					double rad = r.radio_circulo_m * 0.8 * std::sqrt(_azar.uno());
					double sn, cs;
					mate::seno_coseno(ang, sn, cs);
					marcar(i, sn * rad, cs * rad);
					continue;
				}
				// Afuera del área y a 9,15 del punto, del lado de la cancha.
				double x = j.cuerpo.x, z = j.cuerpo.z;
				double borde = gx - s * Cerebro::AREA_LARGO;
				if (std::abs(gx - x) <= Cerebro::AREA_LARGO + 0.5 && std::abs(z) <= Cerebro::AREA_MEDIO_ANCHO + 0.5) {
					x = borde - s * (0.5 + 3.0 * _azar.uno());
					z = std::clamp(z, -Cerebro::AREA_MEDIO_ANCHO, Cerebro::AREA_MEDIO_ANCHO);
				}
				double dx = x - p.x, dz = z - p.z;
				double d = hipot(dx, dz);
				if (d < r.distancia_libre_m) {
					x = p.x + (d > 0.1 ? dx / d : -s) * r.distancia_libre_m;
					z = p.z + (d > 0.1 ? dz / d : 0.0) * r.distancia_libre_m;
				}
				marcar(i, x, z);
			}
			return;
		case SAQUE_ARCO:
			// Los rivales, afuera del área.
			for (size_t i = 0; i < n; i++) {
				const JugadorCanchita &j = jugadores[i];
				if (j.equipo != defiende) {
					continue;
				}
				double propio = -Cerebro::MEDIO_LARGO * s;
				if (std::abs(j.cuerpo.x - propio) <= Cerebro::AREA_LARGO + 0.5
						&& std::abs(j.cuerpo.z) <= Cerebro::AREA_MEDIO_ANCHO + 0.5) {
					marcar(i, propio + s * (Cerebro::AREA_LARGO + 1.0 + 2.0 * _azar.uno()), j.cuerpo.z * 0.9);
				}
			}
			return;
		default:
			return;
	}
	// Los rivales respetan la distancia (menos la barrera, que está justo ahí).
	for (size_t i = 0; i < n; i++) {
		const JugadorCanchita &j = jugadores[i];
		if (j.equipo != defiende || !_tiene_marca[i] || j.arquero) {
			continue;
		}
		double dx = _marca_x[i] - p.x, dz = _marca_z[i] - p.z;
		double d = hipot(dx, dz);
		if (d < p.distancia - 0.05) {
			_marca_x[i] = p.x + (d > 0.1 ? dx / d : -s) * p.distancia;
			_marca_z[i] = p.z + (d > 0.1 ? dz / d : 0.0) * p.distancia;
		}
	}
}

// El área en un córner o un tiro libre que se cuelga (MotorEspacial.
// _repartir_para_el_corner y _marcar_posiciones): suben los de más amenaza
// aérea según el estilo, uno queda siempre atrás, los demás esperan el
// rebote al borde del área. Cada defensor toma a uno que subió, del lado del
// arco; los que sobran cuidan los palos y el punto penal. El arquero, en su
// línea.
void Canchita::_marcar_area(int ataca, int suben) {
	const ParametrosReglas &r = param_reglas;
	size_t n = jugadores.size();
	int defiende = 1 - ataca;
	double s = _ataca(ataca);
	double gx = Cerebro::MEDIO_LARGO * s;
	std::vector<int> candidatos;
	for (size_t i = 0; i < n; i++) {
		const JugadorCanchita &j = jugadores[i];
		if (j.equipo == ataca && !j.arquero && int(i) != _parada.ejecutor) {
			candidatos.push_back(int(i));
		}
	}
	std::stable_sort(candidatos.begin(), candidatos.end(), [&](int a, int b) {
		return jugadores[size_t(a)].reglas.amenaza > jugadores[size_t(b)].reglas.amenaza;
	});
	if (_parada.tipo == CORNER && _parada.jugada == JUGADA_CORNER_BLOQUE) {
		suben = std::max(suben, BLOQUE_MINIMO);
	}
	int tope = std::min(suben, std::max(int(candidatos.size()) - 1, 0));
	std::vector<int> arriba;
	for (int k = 0; k < int(candidatos.size()); k++) {
		size_t i = size_t(candidatos[size_t(k)]);
		if (k < tope && _parada.tipo == CORNER && _parada.jugada == JUGADA_CORNER_BLOQUE && k < BLOQUE_CUANTOS) {
			// Córner en bloque: se juntan en el segundo palo.
			double lejos = _parada.z >= 0.0 ? -1.0 : 1.0;
			_marca_x[i] = gx - s * (BLOQUE_DEL_FONDO_M + double(k % 2));
			_marca_z[i] = lejos * (BLOQUE_DEL_MEDIO_M + 0.9 * double(k / 2));
			_tiene_marca[i] = 1;
			arriba.push_back(int(i));
			_bloque.push_back(int(i));
		} else if (k < tope) {
			_marca_x[i] = gx - s * (r.area_desde_m + (r.area_hasta_m - r.area_desde_m) * _azar.uno());
			_marca_z[i] = (_azar.uno() - 0.5) * r.area_ancho_m;
			_tiene_marca[i] = 1;
			arriba.push_back(int(i));
		} else if (k < int(candidatos.size()) - 1) {
			_marca_x[i] = gx - s * (Cerebro::AREA_LARGO + 2.0 + 6.0 * _azar.uno());
			_marca_z[i] = (_azar.uno() - 0.5) * 30.0;
			_tiene_marca[i] = 1;
		}
	}
	// Los defensores: uno a cada uno de los que subieron, el más cercano.
	std::vector<char> tomado(arriba.size(), 0);
	const double zonas[4][2] = { { 1.5, 3.5 }, { 1.5, -3.5 }, { 11.0, 0.0 }, { 6.0, 0.0 } };
	int zona = 0;
	for (size_t i = 0; i < n; i++) {
		const JugadorCanchita &j = jugadores[i];
		if (j.equipo != defiende || _tiene_marca[i]) {
			continue;
		}
		if (j.arquero) {
			_marca_x[i] = gx - s * ARQUERO_EN_LA_LINEA_M;
			_marca_z[i] = 0.0;
			_tiene_marca[i] = 1;
			continue;
		}
		int mejor = -1;
		double d_mejor = 1e18;
		for (size_t a = 0; a < arriba.size(); a++) {
			if (tomado[a]) {
				continue;
			}
			size_t k = size_t(arriba[a]);
			double d = hipot(_marca_x[k] - j.cuerpo.x, _marca_z[k] - j.cuerpo.z);
			if (d < d_mejor) {
				d_mejor = d;
				mejor = int(a);
			}
		}
		if (mejor >= 0) {
			tomado[size_t(mejor)] = 1;
			size_t k = size_t(arriba[size_t(mejor)]);
			_marca_x[i] = _marca_x[k] + s * 1.0;
			_marca_z[i] = _marca_z[k] * 0.95;
			_tiene_marca[i] = 1;
		} else if (zona < 4) {
			_marca_x[i] = gx - s * zonas[zona][0];
			_marca_z[i] = zonas[zona][1];
			_tiene_marca[i] = 1;
			zona++;
		}
	}
}

// El festejo del gol: el goleador y los compañeros más cercanos van al
// banderín del lado por donde fue el gol. La parada dura festejo_seg en vez
// de FESTEJO_PASOS y termina con un corte al saque del medio.
void Canchita::_empezar_festejo(int autor) {
	const ParametrosReglas &r = param_reglas;
	_festejan.clear();
	if (autor < 0 || r.festejo_seg <= 0.0) {
		return;
	}
	Parada &p = _parada;
	int64_t extra = pasos_de(r.festejo_seg) - FESTEJO_PASOS;
	if (extra > 0) {
		p.reponer_en += extra;
		p.minimo += extra;
		p.tope += extra;
	}
	const JugadorCanchita &a = jugadores[size_t(autor)];
	p.festeja = true;
	p.festejo_x = _ataca(a.equipo) * (_medio_x() - FESTEJO_DEL_BANDERIN_M);
	p.festejo_z = (a.cuerpo.z >= 0.0 ? 1.0 : -1.0) * (_medio_z() - FESTEJO_DEL_BANDERIN_M);
	_festejan.push_back(_id(autor));
	int cuantos = std::clamp(int(r.festejo_grupo), 1, 5);
	std::vector<char> va(jugadores.size(), 0);
	va[size_t(autor)] = 1;
	for (int k = 1; k < cuantos; k++) {
		int mejor = -1;
		double d_mejor = 1e18;
		for (size_t i = 0; i < jugadores.size(); i++) {
			const JugadorCanchita &j = jugadores[i];
			if (va[i] || j.equipo != a.equipo || j.arquero || paso < j.en_el_piso_hasta) {
				continue;
			}
			double d = hipot(j.cuerpo.x - a.cuerpo.x, j.cuerpo.z - a.cuerpo.z);
			if (d < d_mejor) {
				d_mejor = d;
				mejor = int(i);
			}
		}
		if (mejor < 0) {
			break;
		}
		va[size_t(mejor)] = 1;
		_festejan.push_back(_id(mejor));
	}
}

int Canchita::_puesto_en_festejo(int i) const {
	int id = _id(i);
	for (size_t k = 0; k < _festejan.size(); k++) {
		if (_festejan[k] == id) {
			return int(k);
		}
	}
	return -1;
}

int Canchita::festeja() const {
	if (!(reglas && _parada.activa && _parada.festeja) || _festejan.empty()) {
		return -1;
	}
	for (size_t i = 0; i < jugadores.size(); i++) {
		if (_id(int(i)) == _festejan[0]) {
			return int(i);
		}
	}
	return -1;
}

double Canchita::_distancia_parada(int i) const {
	if (!(reglas && _parada.activa)) {
		return jugadores[size_t(i)].equipo != equipo_con_pelota ? 5.0 : 0.0;
	}
	return jugadores[size_t(i)].equipo != _parada.equipo ? _parada.distancia : 0.0;
}

// Lo que hace cada uno durante la parada. Devuelve false si sigue el juego
// normal (el ejecutor que ya va a patear).
bool Canchita::_pensar_en_parada(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	Cuerpo &c = j.cuerpo;
	const Parada &p = _parada;
	if (paso < j.en_el_piso_hasta || p.corte_en >= 0) {
		// En el piso, o con tarjeta: la jugada queda cortada. Cada uno se
		// queda donde está hasta el corte al saque. Yendo a sus lugares, el
		// que saca y la barrera tapaban al árbitro y al de la tarjeta.
		j.persigue = false;
		j.toque = TOQUE_NADA;
		c.ir_a(c.x, c.z, 0.3, true);
		return true;
	}
	int puesto = p.festeja ? _puesto_en_festejo(i) : -1;
	if (puesto >= 0) {
		// Al banderín, y ahí festeja de cara a la tribuna.
		j.persigue = false;
		j.toque = TOQUE_NADA;
		double sx = p.festejo_x >= 0.0 ? 1.0 : -1.0, sz = p.festejo_z >= 0.0 ? 1.0 : -1.0;
		double tx = p.festejo_x - sx * FESTEJO_RONDA[puesto][0], tz = p.festejo_z - sz * FESTEJO_RONDA[puesto][1];
		if (hipot(c.x - tx, c.z - tz) <= FESTEJO_LLEGA_M) {
			c.ir_a(c.x, c.z, 0.3, true);
			if (c.clip < 0 && param_reglas.clip_festejar >= 0 && c.rapidez() < 0.5) {
				c.empezar(param_reglas.clip_festejar);
			}
		} else {
			c.ir_a(tx, tz, 1.0, true);
		}
		c.mira = true;
		c.mira_x = p.festejo_x + sx * 10.0;
		c.mira_z = p.festejo_z + sz * 10.0;
		return true;
	}
	if (i == p.ejecutor) {
		if (p.sacando) {
			return false;
		}
		j.persigue = false;
		j.toque = TOQUE_NADA;
		// Va corriendo: el que saca no se hace esperar.
		c.ir_a(p.lugar_x, p.lugar_z, 1.0, true);
		c.mira = true;
		if (p.tipo == LATERAL) {
			c.mira_x = p.x;
			c.mira_z = 0.0;
		} else {
			c.mira_x = p.x;
			c.mira_z = p.z;
		}
		return true;
	}
	if (p.sacando && p.jugada == JUGADA_CORNER_BLOQUE) {
		for (size_t k = 0; k < _bloque.size(); k++) {
			if (_bloque[k] != i) {
				continue;
			}
			// El bloque arranca a la vez hacia el área chica.
			double s = _ataca(p.equipo), lejos = p.z >= 0.0 ? -1.0 : 1.0;
			j.persigue = false;
			j.toque = TOQUE_NADA;
			c.ir_a(Cerebro::MEDIO_LARGO * s - s * (BLOQUE_LLEGA_DEL_FONDO_M + double(k % 2)),
					lejos * (BLOQUE_LLEGA_DEL_MEDIO_M - 0.9 * double(k / 2)), 1.0, false);
			return true;
		}
	}
	if (size_t(i) < _tiene_marca.size() && _tiene_marca[size_t(i)]) {
		j.persigue = false;
		j.toque = TOQUE_NADA;
		bool festejo = p.tipo == SAQUE_MEDIO && paso < p.reponer_en;
		// El socio de la jugada va corriendo: el saque lo espera a él.
		bool socio = p.jugada != JUGADA_NADA && i == p.socio;
		c.ir_a(_marca_x[size_t(i)], _marca_z[size_t(i)], festejo ? FACTOR_FESTEJO : (socio ? 1.0 : FACTOR_MARCA), true);
		c.mira = true;
		c.mira_x = p.x;
		c.mira_z = p.z;
		return true;
	}
	if (p.sacando) {
		return false;
	}
	j.persigue = false;
	j.toque = TOQUE_NADA;
	_ubicar(i);
	return true;
}

// Cada paso de la parada: repone la pelota, espera al ejecutor y a los
// demás, y saca. Devuelve true (mientras hay parada no se mira nada más).
bool Canchita::_avanzar_parada() {
	Parada &p = _parada;
	const ParametrosReglas &r = param_reglas;
	if (!p.repuesta && paso >= p.reponer_en) {
		pelota.poner({ p.x, param_pelota.radio, p.z }, {}, {});
		p.repuesta = true;
		_cambio = true;
	}
	if (p.festeja && paso >= p.reponer_en) {
		// Terminó el festejo: corte al saque del medio (desde el banderín son
		// 50 m hasta su mitad).
		p.festeja = false;
		_festejan.clear();
		_cortar_al_saque();
	}
	if (p.corte_en >= 0 && paso >= p.corte_en) {
		// Con roja, el corte espera a que el expulsado cruce la línea.
		bool saliendo = false;
		for (const Saliente &s : afuera) {
			saliendo = saliendo || (s.expulsado && std::abs(s.cuerpo.z) < _medio_z());
		}
		if (!saliendo) {
			p.corte_en = -1;
			_cortar_al_saque();
		}
	}
	if (p.sacando) {
		// El que falla el gesto vuelve a intentar; si en SACANDO_MAX_SEG no
		// pudo, saca otro (que una parada no quede sin terminar).
		if (paso - p.sacando_desde > pasos_de(SACANDO_MAX_SEG)) {
			JugadorCanchita &je = jugadores[size_t(p.ejecutor)];
			je.toque_pendiente = false;
			je.persigue = false;
			je.hay_decision = false;
			p.sacando = false;
			poseedor = -1;
			p.ejecutor = -1;
			p.repuesta = false;
			p.reponer_en = paso;
			p.minimo = paso;
			p.tope = paso + pasos_de(r.espera_max_seg[p.tipo]);
		}
		return true;
	}
	if (p.lanzando) {
		const Cuerpo &c = jugadores[size_t(p.ejecutor)].cuerpo;
		if ((c.eventos & ABRE_CONTACTO) || c.clip < 0) {
			_lanzar_lateral();
		}
		return true;
	}
	// El que no llega (lo trabaron, se lesionó): pasado el tope, otro.
	// Solo si no llegó: el que ya está en su lugar espera a los demás (al que
	// sale en un cambio, a los que vuelven a su mitad).
	bool no_llega = p.ejecutor >= 0 && paso > p.tope + pasos_de(10.0) && !p.en_manos
			&& hipot(jugadores[size_t(p.ejecutor)].cuerpo.x - p.lugar_x, jugadores[size_t(p.ejecutor)].cuerpo.z - p.lugar_z)
					> r.llegada_m;
	if (p.ejecutor < 0 || no_llega) {
		// Otro, no el mismo: si lo traba un cuerpo, lo va a seguir trabando.
		p.ejecutor = _elegir_ejecutor(p.tipo == SAQUE_ARCO ? TIRO_LIBRE : p.tipo, p.equipo, p.x, p.z, LIBRE_CORTO,
				p.ejecutor);
		p.tope = paso + pasos_de(r.espera_max_seg[p.tipo]);
		_lugar_del_ejecutor();
		// El que dejó de sacar necesita su lugar: sin marca se iba a atacar.
		_marcar_parada();
		if (p.ejecutor < 0) {
			return true;
		}
	}
	JugadorCanchita &je = jugadores[size_t(p.ejecutor)];
	const Cuerpo &c = je.cuerpo;
	double falta = hipot(c.x - p.lugar_x, c.z - p.lugar_z);
	bool llego = p.repuesta && falta <= r.llegada_m;
	if (falta > 2.0 && paso > p.desde + pasos_de(ARRANCA_SEG) && c.rapidez() < CAMINA_MS && c.clip < 0
			&& paso >= je.en_el_piso_hasta && (p.tipo != SAQUE_MEDIO || paso >= p.reponer_en)) {
		// Camina si sigue así medio segundo: frenar o darse vuelta en el
		// camino no es caminar.
		if (++p.lento_pasos == pasos_de(CAMINA_SOSTENIDA_SEG)) {
			cuenta.ejecutor_camina[p.tipo]++;
		}
	} else {
		p.lento_pasos = 0;
	}
	// De frente a la cancha: el que llegaba corriendo hacia la línea levantaba
	// la pelota de espaldas (el gesto no deja girar) y el lateral salía para
	// atrás de adonde miraba (revisión visual de la etapa 7).
	bool de_frente = std::abs(mate::envolver(rumbo_de(p.x - c.x, -c.z) - c.rumbo)) <= LATERAL_DE_FRENTE_RAD;
	if (llego && p.llego_en < 0) {
		p.llego_en = paso;
	}
	if (p.tipo == LATERAL && llego && !p.en_manos && (de_frente || paso > p.llego_en + pasos_de(LATERAL_GIRA_MAX_SEG))) {
		// Levanta la pelota y se prepara.
		p.en_manos = true;
		p.en_manos_desde = paso;
		if (r.clip_lateral_prepara >= 0 && je.cuerpo.empezar(r.clip_lateral_prepara)) {
			// Se queda con la pelota arriba hasta que la lanza. Lateral_Prepara
			// dura 0,75 s y la espera 1,5 s: al terminar el clip los brazos
			// bajaban y la pelota, que la vista dibuja entre las manos, quedaba
			// en la panza hasta el saque (revisión visual de la etapa 7).
			Cuerpo &ce = je.cuerpo;
			ce.sosten_en = clips[size_t(r.clip_lateral_prepara)].duracion * LATERAL_ARRIBA_DEL_CLIP;
			ce.sosten_seg = SOSTEN_LATERAL_SEG;
		}
	}
	bool ubicados = true;
	if (paso < p.tope) {
		for (size_t k = 0; k < jugadores.size() && ubicados; k++) {
			if (k < _tiene_marca.size() && _tiene_marca[k]
					&& hipot(jugadores[k].cuerpo.x - _marca_x[k], jugadores[k].cuerpo.z - _marca_z[k]) > r.ubicado_m) {
				ubicados = false;
			}
		}
	}
	// El saque del medio espera a que cada uno esté en su mitad, aunque pase
	// el tope: con el tope de 6 s se sacaba con los delanteros todavía
	// volviendo del área rival (revisión visual de la etapa 7). El reloj
	// espera en las paradas, así que no cuesta tiempo de juego.
	if (p.tipo == SAQUE_MEDIO && paso < p.desde + pasos_de(SAQUE_MEDIO_MAX_SEG)) {
		for (size_t k = 0; k < jugadores.size() && ubicados; k++) {
			const JugadorCanchita &jk = jugadores[k];
			// El lesionado no vuelve: queda en el piso hasta que lo cambian.
			if (int(k) != p.ejecutor && !jk.lesionado && jk.cuerpo.x * _ataca(jk.equipo) > EN_SU_MITAD_M) {
				ubicados = false;
			}
		}
	}
	// El que entra en un cambio tiene que pisar la cancha antes del saque.
	for (size_t k = 0; k < _entrando.size();) {
		const Cuerpo &ce = jugadores[size_t(_entrando[k])].cuerpo;
		if (std::abs(ce.z) < _medio_z() - 0.5) {
			_entrando.erase(_entrando.begin() + int64_t(k));
		} else {
			ubicados = false;
			k++;
		}
	}
	// El que se va (expulsado, lesionado o cambiado) sale de la cancha antes
	// del saque. Con el juego andando mientras caminaba hacia afuera, en la
	// revisión visual no se veía que se iba.
	if (periodo < TANDA) {
		for (const Saliente &s : afuera) {
			if (std::abs(s.cuerpo.z) < _medio_z()) {
				ubicados = false;
			}
		}
	}
	// El lateral: con la pelota en las manos busca a quién dársela.
	if (p.tipo == LATERAL && (!p.en_manos || paso < p.en_manos_desde + pasos_de(r.lateral_espera_seg))) {
		ubicados = false;
	}
	// Con la pelota ya en las manos saca desde donde quedó: el que llegaba
	// rápido frenaba 1,7 m más allá de su lugar con el gesto empezado, dejaba
	// de "haber llegado" y el lateral no salía.
	if ((llego || p.en_manos) && paso >= p.minimo && ubicados) {
		_ejecutar_parada();
	}
	return true;
}

void Canchita::_ejecutar_parada() {
	Parada &p = _parada;
	JugadorCanchita &j = jugadores[size_t(p.ejecutor)];
	double espera = double(paso - p.desde) * PASO_SEG;
	cuenta.espera_parada_suma[p.tipo] += espera;
	cuenta.espera_parada_max[p.tipo] = std::max(cuenta.espera_parada_max[p.tipo], espera);
	if (p.tipo == LATERAL && espera > LATERAL_LENTO_SEG) {
		cuenta.laterales_lentos++;
	}
	if (hipot(j.cuerpo.x - p.x, j.cuerpo.z - p.z) > param_reglas.llegada_m + DETRAS_DE_LA_PELOTA_M + CARRERA_PENAL_M) {
		cuenta.saques_de_lejos++;
	}
	if (p.tipo == LATERAL) {
		Cuerpo &c = j.cuerpo;
		c.clip = -1;
		c.fase = SIN_ACCION;
		if (param_reglas.clip_lateral >= 0) {
			c.empezar(param_reglas.clip_lateral);
		}
		p.lanzando = true;
		return;
	}
	p.sacando = true;
	p.sacando_desde = paso;
	poseedor = p.ejecutor;
	ultimo_toque = p.ejecutor;
	ultimo_tipo = TOQUE_CONTROL;
	_desde_control = paso;
	j.pensar_ya = true;
	j.hay_decision = false;
	_visto_paso = paso;
	_analizar();
}

// El lateral: con las dos manos desde arriba de la cabeza, a un compañero
// libre. Sale en una parábola sin aire con el ángulo fijo; el aire la acorta
// un poco y el receptor la va a buscar como a cualquier pase.
void Canchita::_lanzar_lateral() {
	Parada &p = _parada;
	int e = p.ejecutor;
	JugadorCanchita &j = jugadores[size_t(e)];
	const ParametrosReglas &r = param_reglas;
	// Sale desde la línea: con las manos afuera, la pelota que se suelta
	// contaba como otro lateral (en un partido, 297 seguidos).
	V3 desde = pelota.pos;
	double borde = _medio_z() - param_pelota.radio - 0.01;
	desde.z = std::clamp(desde.z, -borde, borde);
	double s = _ataca(j.equipo);
	int mejor = -1;
	double mejor_valor = -1e18;
	int cerca = -1;
	double d_cerca = 1e18;
	for (size_t k = 0; k < jugadores.size(); k++) {
		const JugadorCanchita &o = jugadores[k];
		if (int(k) == e || o.equipo != j.equipo || o.arquero || paso < o.en_el_piso_hasta) {
			continue;
		}
		double d = hipot(o.cuerpo.x - desde.x, o.cuerpo.z - desde.z);
		if (d < d_cerca) {
			d_cerca = d;
			cerca = int(k);
		}
		if (d < 4.0 || d > r.lateral_alcance_m) {
			continue;
		}
		double valor = _claridad(desde, o.cuerpo.x, o.cuerpo.z, j.equipo) - 0.03 * d
				+ 0.02 * (o.cuerpo.x - desde.x) * s;
		if (valor > mejor_valor) {
			mejor_valor = valor;
			mejor = int(k);
		}
	}
	int receptor = mejor >= 0 ? mejor : cerca;
	double tx = desde.x + s * 8.0, tz = desde.z * 0.7;
	if (receptor >= 0) {
		const Cuerpo &cr = jugadores[size_t(receptor)].cuerpo;
		tx = cr.x + cr.vx * 0.5;
		tz = cr.z + cr.vz * 0.5;
	}
	cuenta.saques[LATERAL]++;
	_anotar(EV_SAQUE, j.equipo, _id(e), -1, LATERAL, desde.x, desde.z);
	_parada = Parada();
	_reinicio_hasta = paso;
	_lanzar_a(e, desde, tx, tz, r.lateral_elevacion_rad, segun_atributo(j.reglas.fuerza, r.lateral_min_ms, r.lateral_max_ms),
			receptor);
}

void Canchita::_lanzar_a(int e, V3 desde, double tx, double tz, double elevacion, double rapidez_max, int receptor) {
	JugadorCanchita &j = jugadores[size_t(e)];
	tz = std::clamp(tz, -_medio_z() + 1.0, _medio_z() - 1.0);
	double dx = tx - desde.x, dz = tz - desde.z;
	double d = std::max(hipot(dx, dz), 1.0);
	// Llega a la altura de la cintura: v² = g d² / (2 cos² θ (h - y + d tan θ)).
	double sn, cs;
	mate::seno_coseno(elevacion, sn, cs);
	double abajo = 2.0 * cs * cs * (desde.y - 0.8 + d * sn / cs);
	double v = abajo > 1e-6 ? std::sqrt(param_pelota.gravedad * d * d / abajo) * 1.05 : rapidez_max;
	v = std::clamp(v, 4.0, rapidez_max);
	double angulo = rumbo_de(dx, dz) + _azar.normal() * param_toque.error_pase_rad * (1.0 - 0.8 * j.pases / 100.0);
	v *= 1.0 + _azar.normal() * param_toque.error_pase_rapidez * (1.0 - 0.7 * j.pases / 100.0);
	double sa, ca;
	mate::seno_coseno(angulo, sa, ca);
	pelota.poner(desde, { sa * v * cs, v * sn, ca * v * cs }, {});
	cuenta.pases++;
	j.meta_x = tx;
	j.meta_z = tz;
	j.receptor = receptor;
	_pase_activo = receptor >= 0;
	_pateador = e;
	_receptor = receptor;
	_pase_al_espacio = false;
	if (_pase_activo) {
		_avisar_receptor(e);
	}
	j.pateo_en = paso;
	j.inmune_hasta = paso + int64_t(param_toque.sin_rebote_seg / PASO_SEG + 0.5);
	ultimo_toque = e;
	ultimo_tipo = TOQUE_PASE;
	poseedor = -1;
	_visto_paso = paso + _reaccion_pasos;
	_cambio = true;
}

// El arquero con la pelota en las manos: a un compañero libre con la mano; si
// no hay y tiene rivales cerca, de voleo bien lejos; si están lejos, la suelta
// y la juega con el pie (devuelve false).
bool Canchita::_decidir_saque_de_manos() {
	const ParametrosReglas &r = param_reglas;
	int i = _en_manos;
	const JugadorCanchita &j = jugadores[size_t(i)];
	const Cuerpo &c = j.cuerpo;
	double s = _ataca(j.equipo);
	int mejor = -1;
	double mejor_valor = -1e18;
	for (size_t k = 0; k < jugadores.size(); k++) {
		const JugadorCanchita &o = jugadores[k];
		if (int(k) == i || o.equipo != j.equipo || o.arquero) {
			continue;
		}
		double d = hipot(o.cuerpo.x - c.x, o.cuerpo.z - c.z);
		if (d < 8.0 || d > r.mano_alcance_m || _rival_mas_cerca(i, o.cuerpo.x, o.cuerpo.z) < r.mano_libre_m) {
			continue;
		}
		double valor = _claridad({ c.x, 0.0, c.z }, o.cuerpo.x, o.cuerpo.z, j.equipo) + 0.03 * (o.cuerpo.x - c.x) * s;
		if (valor > mejor_valor) {
			mejor_valor = valor;
			mejor = int(k);
		}
	}
	_mano = SaqueMano();
	if (mejor >= 0 && r.clip_arquero_lanza >= 0) {
		_mano.receptor = mejor;
		_mano.x = jugadores[size_t(mejor)].cuerpo.x;
		_mano.z = jugadores[size_t(mejor)].cuerpo.z;
	} else if (_rival_mas_cerca(i, c.x, c.z) < r.juega_m && r.clip_arquero_voleo >= 0) {
		// De voleo, hacia el compañero más adelantado de la banda que menos
		// rivales tiene, a voleo_m.
		_mano.voleo = true;
		_mano.x = std::clamp(c.x + s * r.voleo_m, -_medio_x() + 5.0, _medio_x() - 5.0);
		_mano.z = c.z * 0.5;
		double d_mejor = 1e18;
		for (size_t k = 0; k < jugadores.size(); k++) {
			const JugadorCanchita &o = jugadores[k];
			if (int(k) != i && o.equipo == j.equipo && !o.arquero) {
				double d = hipot(o.cuerpo.x - _mano.x, o.cuerpo.z - _mano.z);
				if (d < d_mejor) {
					d_mejor = d;
					_mano.receptor = int(k);
				}
			}
		}
	} else {
		cuenta.arquero_pie++;
		return false;
	}
	if (_mano.voleo) {
		cuenta.arquero_voleo++;
	} else {
		cuenta.arquero_mano++;
	}
	_mano.activo = true;
	// Corta el gesto del agarre, que le traba el rumbo, y mira adonde la
	// manda. El gesto del saque arranca cuando quedó de frente (avanzar); el
	// tope es lo que tarda en dar media vuelta, por si no llega a girar.
	Cuerpo &ca = jugadores[size_t(i)].cuerpo;
	ca.clip = -1;
	ca.fase = SIN_ACCION;
	ca.mira = true;
	ca.mira_x = _mano.x;
	ca.mira_z = _mano.z;
	_mano.gira_hasta = paso + int64_t(mate::PI / std::max(ca.giro, 0.1) / PASO_SEG) + 1;
	return true;
}

void Canchita::_sacar_de_manos() {
	int i = _en_manos;
	SaqueMano m = _mano;
	_mano = SaqueMano();
	_en_manos = -1;
	// Suelta, la pelota es de cualquiera (con la pelota en las manos los
	// rivales esperaban lejos).
	_reinicio_hasta = paso;
	V3 desde = pelota.pos;
	desde.y = m.voleo ? 0.5 : 1.2;
	if (m.voleo) {
		_lanzar_a(i, desde, m.x, m.z, 0.75, param_remate.fuerte_max_ms, m.receptor);
	} else {
		_lanzar_a(i, desde, m.x, m.z, 0.2, 18.0, m.receptor);
	}
	_offside_al_patear(i);
}

// El ejecutor de un saque con el pie tocó la pelota: se juega.
void Canchita::_termina_saque(int i) {
	Parada p = _parada;
	cuenta.saques[p.tipo]++;
	_anotar(EV_SAQUE, p.equipo, _id(i), -1, p.tipo, p.x, p.z);
	if (p.jugada != JUGADA_NADA) {
		bool con_socio = p.socio >= 0 && p.socio < int(jugadores.size());
		_anotar(EV_JUGADA, p.equipo, _id(i), con_socio ? _id(p.socio) : -1, p.jugada, p.x, p.z);
		if (p.jugada == JUGADA_AMAGUE && con_socio) {
			_amague_id = _id(p.socio);
			_amague_hasta = paso + pasos_de(AMAGUE_SEG);
		}
		if (p.jugada == JUGADA_CORNER_CORTO && con_socio) {
			_corto_id = _id(p.socio);
			_corto_hasta = paso + pasos_de(CORTO_SEG);
		}
	}
	_parada = Parada();
	_reinicio_hasta = paso;
	if (p.tipo == PENAL) {
		_remate.penal = true;
		if (p.tanda) {
			_tanda_pateo = true;
			_tanda_id = _id(i);
		}
	}
}

// Qué hace el que saca con el pie: el penal y el tiro libre directo, al arco
// (elegir_remate); el córner y el tiro libre que se cuelga, un centro al que
// más cabecea de los que subieron; los demás, lo que pida el cerebro menos
// conducir (un saque se juega, no se lleva: MotorEspacial._tocar_corto).
void Canchita::_decidir_saque(int i, V3 bola, double t_patada) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const Parada &p = _parada;
	if (!j.hay_decision) {
		_plan_bola = bola;
		_plan_t = t_patada;
		cerebro.planeador = this;
		Decision d;
		bool al_arco = p.tipo == PENAL || (p.tipo == TIRO_LIBRE && p.tipo_libre == LIBRE_DIRECTO);
		bool centro = p.tipo == CORNER || (p.tipo == TIRO_LIBRE && p.tipo_libre == LIBRE_CENTRO);
		bool con_socio = (p.jugada == JUGADA_CORNER_CORTO || p.jugada == JUGADA_AMAGUE) && _socio_valido();
		if (con_socio) {
			// El socio tiene que estar en su lugar: si no llegó, se saca normal.
			const Cuerpo &cs = jugadores[size_t(p.socio)].cuerpo;
			if (hipot(cs.x - _marca_x[size_t(p.socio)], cs.z - _marca_z[size_t(p.socio)]) > SOCIO_EN_SU_LUGAR_M) {
				con_socio = false;
				_parada.jugada = JUGADA_NADA;
			}
		}
		if (con_socio) {
			// Córner corto o amague: al socio, al pie.
			d.tipo = DEC_PASE;
			d.receptor = p.socio;
		} else if (al_arco) {
			d = cerebro.elegir_remate(_mundo, i, false, _azar);
		} else if (centro) {
			int mejor = -1;
			double amenaza = -1e9;
			for (size_t k = 0; k < jugadores.size(); k++) {
				const JugadorCanchita &o = jugadores[k];
				if (o.equipo != j.equipo || int(k) == i || o.arquero || k >= _tiene_marca.size() || !_tiene_marca[k]) {
					continue;
				}
				bool en_area = std::abs(Cerebro::MEDIO_LARGO * _ataca(j.equipo) - _marca_x[k]) <= Cerebro::AREA_LARGO;
				if (en_area && o.reglas.amenaza > amenaza) {
					amenaza = o.reglas.amenaza;
					mejor = int(k);
				}
			}
			d.tipo = DEC_CENTRO;
			d.receptor = mejor;
			d.tiene_punto = true;
			if (mejor >= 0) {
				d.x = jugadores[size_t(mejor)].cuerpo.x;
				d.z = jugadores[size_t(mejor)].cuerpo.z;
			} else {
				d.x = Cerebro::MEDIO_LARGO * _ataca(j.equipo) - _ataca(j.equipo) * 9.0;
				d.z = 0.0;
			}
			if (p.jugada == JUGADA_CORNER_BLOQUE && !_bloque.empty()) {
				// Al borde del área chica del segundo palo, adonde arranca el bloque.
				d.x = Cerebro::MEDIO_LARGO * _ataca(j.equipo) - _ataca(j.equipo) * BLOQUE_LLEGA_DEL_FONDO_M;
				d.z = (p.z >= 0.0 ? -1.0 : 1.0) * BLOQUE_LLEGA_DEL_MEDIO_M;
			}
		} else {
			d = cerebro.decidir(_mundo, i, true, _azar);
		}
		cerebro.planeador = nullptr;
		if (d.tipo == DEC_CONDUCIR || d.tipo == DEC_REGATE || d.tipo == DEC_NADA || (d.tipo == DEC_REMATE && !al_arco)) {
			// El pase más seguro; si no hay, a la otra mitad.
			Pase pase = _planear_pase(i, bola, t_patada);
			if (pase.hay) {
				d = Decision();
				d.tipo = pase.globo ? DEC_PASE_LARGO : DEC_PASE;
				d.receptor = pase.receptor;
			} else {
				d = Decision();
				d.tipo = DEC_DESPEJE;
				d.tiene_punto = true;
				d.x = std::clamp(bola.x + _ataca(j.equipo) * 40.0, -_medio_x() + 5.0, _medio_x() - 5.0);
				d.z = bola.z * 0.5;
			}
		}
		j.decision = d;
		j.hay_decision = true;
		j.decision_hasta = NUNCA;
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
	Pase pase = _pase_a(i, bola, t_patada, d);
	if (!pase.hay) {
		// Ni eso: la tira adelante, a la otra mitad.
		Decision lejos;
		lejos.tipo = DEC_DESPEJE;
		lejos.tiene_punto = true;
		lejos.x = std::clamp(bola.x + _ataca(j.equipo) * 35.0, -_medio_x() + 5.0, _medio_x() - 5.0);
		lejos.z = bola.z * 0.5;
		pase = _pase_a(i, bola, t_patada, lejos);
	}
	j.toque = TOQUE_PASE;
	j.meta_x = pase.hay ? pase.x : bola.x + _ataca(j.equipo) * 20.0;
	j.meta_z = pase.hay ? pase.z : bola.z;
	j.receptor = pase.receptor;
	j.globo = pase.hay ? pase.globo : true;
	j.rapidez_pase = pase.rapidez;
	j.tipo_pase = d.tipo;
}

// --- Laboratorio de reanudaciones ---

bool Canchita::forzar_parada(int tipo, int equipo, double x, double z) {
	if (!reglas || modo != PARTIDO || periodo >= TANDA || (equipo != 0 && equipo != 1)) {
		return false;
	}
	double lado_z = z >= 0.0 ? 1.0 : -1.0;
	double gx = Cerebro::MEDIO_LARGO * _ataca(equipo);
	if (tipo == CORNER) {
		// El mismo lugar que usa el partido: 0,3 m adentro del banderín.
		x = _ataca(equipo) * (_medio_x() - 0.3);
		z = lado_z * (_medio_z() - 0.3);
		cuenta.corners++;
	} else if (tipo == PENAL) {
		x = gx - _ataca(equipo) * param_reglas.distancia_penal_m;
		z = 0.0;
		cuenta.penales++;
	} else if (tipo == LATERAL) {
		x = std::clamp(x, -_medio_x() + 1.0, _medio_x() - 1.0);
		z = lado_z * _medio_z();
		cuenta.laterales++;
	} else if (tipo != TIRO_LIBRE) {
		return false;
	}
	if (_remate.activo) {
		_cerrar_remate(REMATE_OTRO);
	}
	_parar(tipo, equipo, x, z);
	return true;
}

bool Canchita::forzar_falta(int tarjeta, bool lesion) {
	if (!reglas || modo != PARTIDO || periodo >= TANDA || _parada.activa) {
		return false;
	}
	auto cercano = [this](int equipo, double x, double z) {
		int mejor = -1;
		double d_mejor = 1e18;
		for (size_t i = 0; i < jugadores.size(); i++) {
			const JugadorCanchita &j = jugadores[i];
			if (j.equipo != equipo || j.arquero || j.lesionado) {
				continue;
			}
			double d = hipot(j.cuerpo.x - x, j.cuerpo.z - z);
			if (d < d_mejor) {
				d_mejor = d;
				mejor = int(i);
			}
		}
		return mejor;
	};
	// Espera un cruce de verdad: el que lleva la pelota con un rival a la
	// distancia de la entrada. Forzada con el rival a 4 m, el que la recibía
	// caía solo y no se veía ninguna falta.
	if (poseedor < 0 || jugadores[size_t(poseedor)].arquero) {
		return false;
	}
	int victima = poseedor;
	const JugadorCanchita &jv = jugadores[size_t(victima)];
	int infractor = cercano(1 - jv.equipo, jv.cuerpo.x, jv.cuerpo.z);
	if (infractor < 0) {
		return false;
	}
	Cuerpo &ci = jugadores[size_t(infractor)].cuerpo;
	if (hipot(ci.x - jv.cuerpo.x, ci.z - jv.cuerpo.z) > param_reglas.entrada_dist_m) {
		return false;
	}
	// El que la hace se tira (el gesto de la entrada), como en una falta del partido.
	if (param_reglas.clip_entrada >= 0 && ci.clip < 0) {
		ci.empezar(param_reglas.clip_entrada);
	}
	_falta(infractor, victima, 1.0, true, std::clamp(tarjeta, 0, 2), lesion ? 1 : 0);
	return true;
}

bool Canchita::forzar_fin_de_tiempo() {
	if (!reglas || modo != PARTIDO || periodo >= TANDA) {
		return false;
	}
	_fin_de_tiempo();
	return true;
}

// --- Reloj ---

// Terminó el tiempo (con su agregado): se cierra cuando la pelota no está en
// una jugada de gol, y a los 30 s del final pase lo que pase.
bool Canchita::_reloj() {
	if (periodo >= TANDA) {
		return false;
	}
	double fin = segundos_periodo() + adicion_seg() / escala_reloj();
	double t = reloj_seg();
	if (t < fin) {
		return false;
	}
	bool tranquilo;
	if (_parada.activa) {
		tranquilo = !_parada.sacando && !_parada.lanzando && _parada.tipo != PENAL;
	} else {
		tranquilo = !_remate.activo && _en_manos < 0 && std::abs(pelota.pos.x) < Cerebro::MEDIO_LARGO - 30.0;
	}
	if (!tranquilo && t < fin + param_reglas.cierre_max_seg) {
		return false;
	}
	_fin_de_tiempo();
	return true;
}

void Canchita::_fin_de_tiempo() {
	_anotar(EV_FIN_TIEMPO, 0, -1, -1, periodo, pelota.pos.x, pelota.pos.z);
	_minuto_final = minuto();
	if (_remate.activo) {
		_cerrar_remate(REMATE_OTRO);
	}
	// Etapa 8: el cruce empatado a los 90 juega el alargue; después, la tanda.
	bool empate = cuenta.goles[0] == cuenta.goles[1];
	bool sigue = periodo == PRIMER_TIEMPO || (periodo == SEGUNDO_TIEMPO && param_reglas.alargue && empate)
			|| periodo == ALARGUE_1;
	if (sigue) {
		bool entretiempo = periodo == PRIMER_TIEMPO;
		periodo = periodo + 1;
		_inicio_periodo = paso;
		_pasos_parados = 0;
		// Cambian de lado. El motor sigue con el equipo 0 atacando hacia +x y
		// la vista gira la cancha (lado()); lo único que no gira es el viento:
		// para el motor da la vuelta.
		ParametrosPelota pp = pelota.param;
		pp.viento = { -pp.viento.x, pp.viento.y, -pp.viento.z };
		pelota.configurar(pp);
		// MotorEspacial._recuperar_entretiempo: recupera parte de lo perdido
		// (solo en el entretiempo, no en los descansos del alargue).
		for (JugadorCanchita &j : jugadores) {
			if (entretiempo) {
				double perdida = std::max(j.reglas.energia - j.energia, 0.0);
				j.energia += std::min(perdida * param_reglas.recuperacion_entretiempo, param_reglas.tope_entretiempo);
			}
			j.en_el_piso_hasta = -1;
		}
		_parada = Parada();
		_hacer_cambios(true);
		// Los que salieron ya no están: es el entretiempo.
		afuera.clear();
		_entrando.clear();
		_en_manos = -1;
		_remate = Remate();
		// Vuelven del vestuario: cada uno aparece en su lugar del saque.
		// Saca el que no sacó el tiempo anterior.
		int saca = periodo == SEGUNDO_TIEMPO || periodo == ALARGUE_2 ? 1 - _saco_primero : _saco_primero;
		for (size_t i = 0; i < jugadores.size(); i++) {
			JugadorCanchita &j = jugadores[i];
			Cuerpo &c = j.cuerpo;
			double x, z;
			_ubicar_saque_del_medio(int(i), x, z);
			if (j.equipo == saca && !j.arquero) {
				// El que saca, ya pegado a la pelota: lo elige _parar.
			}
			c.x = c.previa_x = x;
			c.z = c.previa_z = z;
			c.vx = c.vz = 0.0;
			c.clip = -1;
			c.fase = SIN_ACCION;
			c.rumbo = rumbo_de(_ataca(j.equipo), 0.0);
			c.reserva = 1.0;
			c.tiene_objetivo = false;
		}
		pelota.poner({ 0.0, param_pelota.radio, 0.0 }, {}, {});
		_desgastar();
		_parar(SAQUE_MEDIO, saca, 0.0, 0.0);
		return;
	}
	if ((periodo == SEGUNDO_TIEMPO || periodo == ALARGUE_2) && param_reglas.tanda && empate) {
		_empezar_tanda();
		return;
	}
	periodo = TERMINADO;
	_parada = Parada();
	_pase_activo = false;
	poseedor = -1;
	for (JugadorCanchita &j : jugadores) {
		j.persigue = false;
		j.toque_pendiente = false;
		j.cuerpo.ir_a(j.cuerpo.x, j.cuerpo.z, 0.3, true);
	}
}

// El lateral: la pelota en las manos. El motor la lleva donde las manos la
// sueltan (el punto de contacto del clip Lateral): de ahí sale, y la vista la
// dibuja entre las manos mientras suben. Con 2,1 m fijos quedaba a 1 m de la
// cabeza: las manos del modelo llegan a 0,99 m y la sueltan a 0,71 m.
void Canchita::_llevar_lateral() {
	const Cuerpo &c = jugadores[size_t(_parada.ejecutor)].cuerpo;
	V3 manos;
	if (param_reglas.clip_lateral >= 0) {
		manos = punto_de_contacto(c, clips[size_t(param_reglas.clip_lateral)], c.rumbo);
	} else {
		double s, co;
		mate::seno_coseno(c.rumbo, s, co);
		manos = { c.x + s * 0.1, param_reglas.lateral_alto_m, c.z + co * 0.1 };
	}
	pelota.poner(manos, { c.vx, 0.0, c.vz }, {});
}

// --- Energía ---

// MotorEspacial: el desgaste por minutos jugados (Cansancio.desgaste_por_
// minuto) cobrado según cuánto corre cada uno; con la energía baja la franja
// de Cansancio le baja la punta y la aceleración (cuerpo.cansancio). Los que
// salen caminan hasta afuera.
void Canchita::_desgastar() {
	const ParametrosReglas &r = param_reglas;
	// El desgaste es por minuto del reloj mostrado, como en el motor espacial:
	// con el reloj parado (una pelota parada) nadie se cansa.
	bool corre_reloj = periodo < TANDA && !_parada.activa;
	double por_paso = escala_reloj() / 60.0 * PASO_SEG;
	for (JugadorCanchita &j : jugadores) {
		Cuerpo &c = j.cuerpo;
		if (corre_reloj) {
			double f = c.rapidez() / std::max(c.vel_max, 0.1);
			j.energia -= j.reglas.desgaste_minuto * por_paso * (r.esfuerzo_base + r.esfuerzo_carrera * f * f);
			j.energia = std::max(j.energia, r.energia_minima);
		}
		int franja = 3;
		for (int k = 0; k < 4; k++) {
			if (j.energia >= r.franja_piso[k] - 1e-9) {
				franja = k;
				break;
			}
		}
		c.cansancio = r.factor_franja[franja] * (j.lesionado ? 0.5 : 1.0);
	}
	for (size_t k = 0; k < afuera.size();) {
		Saliente &s = afuera[k];
		if (!s.saliendo && paso >= s.espera_hasta) {
			s.saliendo = true;
			s.cuerpo.ir_a(s.x, s.z, s.factor, true);
			// Mira adonde va. Seguía mirando la jugada (el `mira` que traía
			// del partido) y salía de espaldas.
			s.cuerpo.mira = true;
			s.cuerpo.mira_x = s.x;
			s.cuerpo.mira_z = s.z;
		}
		s.cuerpo.paso(param_cuerpo, clips, PASO_SEG);
		if (hipot(s.cuerpo.x - s.x, s.cuerpo.z - s.z) < 0.5) {
			afuera.erase(afuera.begin() + int64_t(k));
		} else {
			k++;
		}
	}
}

// --- Faltas, tarjetas, lesiones ---

// El que contiene la pelota del rival se tira a quitarla: va al punto de
// encuentro con el gesto de la entrada (Barrida). Si su pie llega a la
// pelota se la saca; si llega a las piernas del rival, es falta.
bool Canchita::_plan_entrada(int i) {
	if (param_reglas.clip_entrada < 0 || poseedor < 0) {
		return false;
	}
	JugadorCanchita &j = jugadores[size_t(i)];
	if (j.arquero || jugadores[size_t(poseedor)].equipo == j.equipo) {
		return false;
	}
	if (hipot(pelota.pos.x - j.cuerpo.x, pelota.pos.z - j.cuerpo.z) > param_reglas.entrada_dist_m) {
		return false;
	}
	double quite = std::clamp((j.reglas.quite + j.reglas.barrida) * 0.5 / 100.0, 0.0, 1.0);
	double cuidado = j.amarillas > 0 ? param_reglas.entrada_amonestado : 1.0;
	// De atrás no se tira: va hacia donde mira el que lleva la pelota (la
	// misma cuenta que la gravedad de la falta). El favorito, más rápido,
	// alcanzaba de atrás al que conducía y se barría: en quinta contra octava
	// hacía 3,3 faltas por partido y el otro 0,3 (el motor espacial, 1,2 cada
	// uno), con 0,3 rojas.
	const Cuerpo &cp = jugadores[size_t(poseedor)].cuerpo;
	double sp, cp_;
	mate::seno_coseno(cp.rumbo, sp, cp_);
	double v = j.cuerpo.rapidez();
	double atras = v > 0.1 ? std::clamp((j.cuerpo.vx * sp + j.cuerpo.vz * cp_) / v, 0.0, 1.0) : 0.0;
	cuidado *= 1.0 - param_reglas.entrada_de_atras * atras;
	// El que es más rápido que el que lleva la pelota no necesita tirarse. En
	// un partido desparejo el favorito hacía 3,3 faltas y el otro 0,3 (el
	// motor espacial: 1,2 cada uno).
	double sobra = j.cuerpo.vel_max / std::max(cp.vel_max, 0.1) - 1.0;
	cuidado *= std::clamp(1.0 - param_reglas.entrada_sobrado * sobra, 0.1, 1.0);
	// En su área se cuida: la falta es penal.
	double gx = Cerebro::MEDIO_LARGO * _ataca(1 - j.equipo);
	if (std::abs(gx - pelota.pos.x) <= Cerebro::AREA_LARGO && std::abs(pelota.pos.z) <= Cerebro::AREA_MEDIO_ANCHO) {
		cuidado *= param_reglas.entrada_en_area;
	}
	// Cuánto pesa el quite en las ganas de tirarse: con 1 el bueno se tira más
	// (0,5 + quite); con 0 todos igual; con menos de 0 se tira más el torpe.
	if (_azar.uno() >= param_reglas.entrada_prob * (1.0 + param_reglas.entrada_por_quite * (quite - 0.5)) * cuidado) {
		return false;
	}
	j.entra = true;
	_plan_tocar(i);
	j.entra = false;
	if (j.toque == TOQUE_ENTRADA) {
		j.entrada_hasta = paso + pasos_de(1.0);
		return true;
	}
	return false;
}

// La falta: el que la recibe cae, se sortean la tarjeta y la lesión con la
// gravedad del contacto, y se para el juego: tiro libre, o penal si fue en el
// área del que la hizo.
void Canchita::_falta(int infractor, int victima, double gravedad, bool de_entrada, int tarjeta, int lesion) {
	const JugadorCanchita &jv = jugadores[size_t(victima)];
	int eq_inf = jugadores[size_t(infractor)].equipo;
	int eq_vic = jv.equipo;
	double x = std::clamp(jv.cuerpo.x, -_medio_x() + 1.0, _medio_x() - 1.0);
	double z = std::clamp(jv.cuerpo.z, -_medio_z() + 1.0, _medio_z() - 1.0);
	double gx = Cerebro::MEDIO_LARGO * _ataca(eq_vic);
	bool penal = std::abs(gx - x) <= Cerebro::AREA_LARGO && std::abs(z) <= Cerebro::AREA_MEDIO_ANCHO;
	cuenta.faltas[eq_inf & 1]++;
	cuenta.gravedad_suma += gravedad;
	cuenta.gravedad_max = std::max(cuenta.gravedad_max, gravedad);
	if (de_entrada) {
		cuenta.faltas_entrada++;
	} else {
		cuenta.faltas_cruce++;
	}
	_anotar(EV_FALTA, eq_inf, _id(infractor), _id(victima), penal ? 1 : 0, x, z);
	if (_remate.activo) {
		_cerrar_remate(REMATE_OTRO);
	}
	_caer(victima, param_reglas.clip_caer, param_reglas.caido_seg);
	if (lesion < 0) {
		_lesion(victima, gravedad);
	} else if (lesion > 0) {
		_lesionar(victima);
	}
	// La tarjeta puede sacar al infractor de la cancha: los índices cambian.
	if (tarjeta < 0) {
		_tarjeta(infractor, gravedad);
	} else if (tarjeta > 0) {
		_sacar_tarjeta(infractor, tarjeta >= 2);
	}
	if (penal) {
		cuenta.penales++;
		_parar(PENAL, eq_vic, gx - _ataca(eq_vic) * param_reglas.distancia_penal_m, 0.0);
	} else {
		_parar(TIRO_LIBRE, eq_vic, x, z);
	}
	if (_tarjeta_paso == paso) {
		// El árbitro llega y la muestra; después la jugada se corta al saque.
		_parada.corte_en = paso + pasos_de(param_reglas.tarjeta_seg);
		_parada.minimo = std::max(_parada.minimo, _parada.corte_en + pasos_de(CORTE_ANTES_DEL_SAQUE_SEG));
		_parada.tope = std::max(_parada.tope, _parada.minimo);
	}
}

// Después de la tarjeta la jugada se corta al saque, como en la tele y como
// en el motor espacial (VistaCancha3D._cortar_despues_de_tarjeta): cada uno
// aparece en su lugar del saque. Con roja, el corte espera a que el expulsado
// salga corriendo de la cancha. Es el único corte del partido, junto con el
// entretiempo: en el resto nadie se teletransporta. Sin el corte, después de
// la tarjeta se miraba a todos yendo a su lugar.
void Canchita::_cortar_al_saque() {
	_parada.minimo = std::max(_parada.minimo, paso + pasos_de(CORTE_ANTES_DEL_SAQUE_SEG));
	_parada.tope = std::max(_parada.tope, _parada.minimo);
	for (size_t i = 0; i < jugadores.size(); i++) {
		JugadorCanchita &j = jugadores[i];
		Cuerpo &c = j.cuerpo;
		if (j.lesionado && paso < j.en_el_piso_hasta) {
			// El lesionado sigue en el piso donde cayó.
			continue;
		}
		j.en_el_piso_hasta = -1;
		if (!_pensar_en_parada(int(i)) || !c.tiene_objetivo) {
			continue;
		}
		// previa = actual: el detector de teletransportes no cuenta el corte.
		c.x = c.previa_x = c.objetivo_x;
		c.z = c.previa_z = c.objetivo_z;
		c.vx = c.vz = 0.0;
		c.clip = -1;
		c.fase = SIN_ACCION;
		double dx = (c.mira ? c.mira_x : _parada.x) - c.x, dz = (c.mira ? c.mira_z : _parada.z) - c.z;
		if (dx * dx + dz * dz > 1e-6) {
			c.rumbo = mate::arcotangente2(dx, dz);
		}
	}
	// Los lugares del saque pueden encimar a dos (la barrera): se separan
	// acá, adentro del corte. Si no, se empujaban hasta 0,47 m en el paso
	// siguiente, a la vista.
	for (int k = 0; k < 8; k++) {
		_separar_cuerpos();
	}
	for (JugadorCanchita &j : jugadores) {
		j.cuerpo.previa_x = j.cuerpo.x;
		j.cuerpo.previa_z = j.cuerpo.z;
	}
	corte_paso = paso;
	_cambio = true;
}

// MatchEngine._chequear_tarjeta: una tirada sobre el que hizo la falta. La
// gravedad sube la amarilla y, más, la roja. Dos amarillas, roja.
void Canchita::_tarjeta(int i, double gravedad) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const ParametrosReglas &r = param_reglas;
	double g = std::clamp(gravedad, 0.2, 4.0);
	double p_roja = r.roja_por_falta * j.reglas.factor_roja * g * g;
	double p_amarilla = r.amarilla_por_falta * j.reglas.factor_amarilla * g;
	// ponytail: el arquero no se va expulsado, ni por roja ni por la segunda
	// amarilla. El equipo sin arquero no está resuelto (nadie se pone los
	// guantes): resolverlo antes de sacar esto.
	if (j.arquero) {
		p_roja = 0.0;
		p_amarilla = j.amarillas > 0 ? 0.0 : p_amarilla;
	}
	double tirada = _azar.uno();
	if (tirada < p_roja) {
		_sacar_tarjeta(i, true);
	} else if (tirada < p_roja + p_amarilla) {
		_sacar_tarjeta(i, false);
	}
}

// Amarilla o roja directa. La segunda amarilla es roja.
void Canchita::_sacar_tarjeta(int i, bool roja) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const ParametrosReglas &r = param_reglas;
	_tarjeta_paso = paso;
	bool doble = false;
	if (!roja) {
		j.amarillas++;
		if (j.amarillas >= 2) {
			roja = doble = true;
		} else {
			cuenta.amarillas[j.equipo & 1]++;
			_adicion[lado() & 1] += r.adicion_tarjeta_seg;
			_anotar(EV_AMARILLA, j.equipo, _id(i), -1, 0, j.cuerpo.x, j.cuerpo.z);
		}
	}
	if (roja) {
		cuenta.rojas[j.equipo & 1]++;
		if (!doble) {
			cuenta.rojas_directas++;
		}
		_adicion[lado() & 1] += r.adicion_tarjeta_seg;
		_anotar(EV_ROJA, j.equipo, _id(i), -1, doble ? 1 : 0, j.cuerpo.x, j.cuerpo.z);
		_quitar(i, true);
	}
}

// Lesiones.evaluar_riesgo: el riesgo del jugador descansado, por el cansancio
// del partido (1 + lo que perdió, y la franja), por el contacto.
void Canchita::_lesion(int i, double factor) {
	JugadorCanchita &j = jugadores[size_t(i)];
	if (j.lesionado) {
		return;
	}
	const ParametrosReglas &r = param_reglas;
	int franja = 3;
	for (int k = 0; k < 4; k++) {
		if (j.energia >= r.franja_piso[k] - 1e-9) {
			franja = k;
			break;
		}
	}
	double fatiga = 1.0 + (1.0 - std::clamp(j.energia, 0.0, 1.0));
	double p = j.reglas.riesgo_lesion * fatiga * r.riesgo_franja[franja] * r.lesion_por_contacto * std::max(factor, 0.0);
	if (_azar.uno() >= p) {
		return;
	}
	_lesionar(i);
}

void Canchita::_lesionar(int i) {
	JugadorCanchita &j = jugadores[size_t(i)];
	const ParametrosReglas &r = param_reglas;
	j.lesionado = true;
	cuenta.lesiones++;
	_adicion[lado() & 1] += r.adicion_lesion_seg;
	_anotar(EV_LESION, j.equipo, _id(i), -1, 0, j.cuerpo.x, j.cuerpo.z);
	_caer(i, r.clip_lesionado >= 0 ? r.clip_lesionado : r.clip_caer, r.lesionado_seg);
}

void Canchita::_caer(int i, int clip, double segundos) {
	JugadorCanchita &j = jugadores[size_t(i)];
	Cuerpo &c = j.cuerpo;
	c.clip = -1;
	c.fase = SIN_ACCION;
	if (clip >= 0) {
		c.empezar(clip);
		// El clip cae y se levanta de corrido (Caer: en el piso del 30 al 50%
		// de sus 1,25 s). Se detiene en el piso lo que sobra de `segundos`: sin
		// eso estaba 0,25 s tirado y en la revisión visual no se lo veía caer.
		double dura = clips[size_t(clip)].duracion;
		if (segundos > dura) {
			c.sosten_en = dura * EN_EL_PISO_DEL_CLIP;
			c.sosten_seg = segundos - dura;
		}
	}
	j.toque_pendiente = false;
	j.persigue = false;
	j.en_el_piso_hasta = std::max(j.en_el_piso_hasta, paso + pasos_de(segundos));
}

// Se va de la cancha (expulsado, o lesionado sin cambio): deja de jugar y
// camina hasta el lateral más cercano. Los índices de los que siguen bajan uno.
void Canchita::_quitar(int i, bool expulsado) {
	if (i < 0 || i >= int(jugadores.size())) {
		return;
	}
	JugadorCanchita &j = jugadores[size_t(i)];
	Saliente s;
	s.cuerpo = j.cuerpo;
	s.equipo = j.equipo;
	s.id = j.reglas.id;
	s.expulsado = expulsado;
	energia_al_salir.push_back({ j.reglas.id, j.energia });
	s.x = j.cuerpo.x;
	s.z = (j.cuerpo.z >= 0.0 ? 1.0 : -1.0) * (_medio_z() + AFUERA_M);
	// El lesionado termina de caer (el gesto sigue) y después camina.
	if (!j.lesionado) {
		s.cuerpo.clip = -1;
		s.cuerpo.fase = SIN_ACCION;
	}
	if (expulsado) {
		// El expulsado se va al vestuario: por el medio de la banda de la
		// cámara (+z en el primer tiempo; en el segundo la vista gira la
		// cancha y es -z).
		s.x = 0.0;
		s.z = (lado() == 0 ? 1.0 : -1.0) * (_medio_z() + AFUERA_M);
	}
	s.factor = expulsado ? FACTOR_SALIR_EXPULSADO : (j.lesionado ? FACTOR_SALIR_LESIONADO : FACTOR_SALIR);
	if (expulsado && _tarjeta_paso == paso) {
		// Se queda donde está hasta que el árbitro llega y le muestra la roja,
		// y después sale corriendo. Saliendo enseguida, se iba antes de que
		// se viera la tarjeta.
		s.espera_hasta = paso + pasos_de(param_reglas.tarjeta_seg);
		s.cuerpo.ir_a(s.cuerpo.x, s.cuerpo.z, 0.3, true);
	}
	afuera.push_back(s);
	jugadores.erase(jugadores.begin() + i);
	cerebro.quitar(i);
	_k_llega.erase(_k_llega.begin() + i);
	_t_llega.erase(_t_llega.begin() + i);
	auto ajustar = [i](int &v) {
		if (v == i) {
			v = -1;
		} else if (v > i) {
			v--;
		}
	};
	ajustar(poseedor);
	ajustar(ultimo_toque);
	ajustar(_receptor);
	ajustar(_pateador);
	ajustar(_perseguidor[0]);
	ajustar(_perseguidor[1]);
	_segundo[0] = _segundo[1] = -1;
	ajustar(_en_manos);
	ajustar(_remate.pateador);
	ajustar(_parada.ejecutor);
	for (JugadorCanchita &o : jugadores) {
		ajustar(o.receptor);
		ajustar(o.marca);
		ajustar(o.decision.receptor);
		ajustar(o.decision.corredor);
	}
	auto ajustar_lista = [&](std::vector<int> &lista) {
		for (int &v : lista) {
			ajustar(v);
		}
		lista.erase(std::remove(lista.begin(), lista.end(), -1), lista.end());
	};
	ajustar_lista(_adelantados);
	ajustar_lista(_entrando);
	ajustar_lista(_orden_tanda[0]);
	ajustar_lista(_orden_tanda[1]);
	if (size_t(i) < _tiene_marca.size()) {
		_marca_x.erase(_marca_x.begin() + i);
		_marca_z.erase(_marca_z.begin() + i);
		_tiene_marca.erase(_tiene_marca.begin() + i);
	}
	if (_pase_activo && _receptor < 0) {
		_pase_activo = false;
	}
	// Con menos de siete no se juega (reglamento): el partido se suspende.
	int quedan = 0;
	for (const JugadorCanchita &o : jugadores) {
		quedan += o.equipo == s.equipo ? 1 : 0;
	}
	if (quedan < 7 && periodo < TERMINADO) {
		_suspendido = true;
		_anotar(EV_FIN_TIEMPO, s.equipo, -1, -1, TERMINADO, s.x, s.z);
		periodo = TERMINADO;
		_parada = Parada();
	}
}

// MatchEngine._procesar_cambios_equipo: sale el lesionado y, desde
// cambio_desde_min (o en el entretiempo), el que bajó del umbral de energía
// del club (nunca el arquero sano); entra el de más media del banco en su
// puesto, si viene más fresco. Hasta cambios_max por partido.
void Canchita::_hacer_cambios(bool entretiempo) {
	if (!reglas || periodo >= TANDA) {
		return;
	}
	const ParametrosReglas &r = param_reglas;
	double minuto = this->minuto();
	for (int e = 0; e < 2; e++) {
		std::vector<char> probado(jugadores.size(), 0);
		while (cuenta.cambios[e] < r.cambios_max) {
			int sale = -1;
			for (size_t i = 0; i < jugadores.size(); i++) {
				const JugadorCanchita &j = jugadores[i];
				if (j.equipo != e || probado[i]) {
					continue;
				}
				bool cansado = (entretiempo || minuto >= r.cambio_desde_min) && !j.arquero
						&& j.energia <= r.umbral_cambio[e];
				if (!j.lesionado && !cansado) {
					continue;
				}
				if (sale < 0) {
					sale = int(i);
					continue;
				}
				const JugadorCanchita &js = jugadores[size_t(sale)];
				if (j.lesionado != js.lesionado ? j.lesionado : j.energia < js.energia) {
					sale = int(i);
				}
			}
			if (sale < 0) {
				break;
			}
			probado[size_t(sale)] = 1;
			const JugadorCanchita &js = jugadores[size_t(sale)];
			int rol = cerebro.fichas[size_t(sale)].rol;
			int entra = -1;
			for (int vuelta = 0; vuelta < 2 && entra < 0; vuelta++) {
				for (size_t k = 0; k < banco.size(); k++) {
					const Suplente &su = banco[k];
					if (su.jugador.equipo != e) {
						continue;
					}
					// Primero su puesto; el lesionado, si no hay, cualquiera de
					// campo (el arquero solo por arquero).
					bool puesto = su.jugador.reglas.rol == rol;
					if (vuelta == 0 ? !puesto : (!js.lesionado || rol == ARQ || su.jugador.reglas.rol == ARQ)) {
						continue;
					}
					if (!js.lesionado && su.jugador.reglas.energia <= js.energia) {
						continue;
					}
					if (entra < 0 || su.jugador.reglas.media > banco[size_t(entra)].jugador.reglas.media) {
						entra = int(k);
					}
				}
			}
			if (entra >= 0) {
				_cambiar(sale, size_t(entra));
				probado.assign(jugadores.size(), 0);
			} else if (js.lesionado) {
				// Sin nadie para entrar, el lesionado sale igual: juegan con uno menos.
				_quitar(sale, false);
				probado.assign(jugadores.size(), 0);
			}
		}
	}
}

// El que entra ocupa el lugar (el casillero y el rol) del que sale: un cambio
// no inventa un puesto nuevo. Sale caminando por el lateral más cercano y el
// que entra arranca frente al banco.
void Canchita::_cambiar(int sale, size_t entra) {
	const ParametrosReglas &r = param_reglas;
	Suplente su = banco[entra];
	banco.erase(banco.begin() + int64_t(entra));
	JugadorCanchita &j = jugadores[size_t(sale)];
	int e = j.equipo;
	Saliente s;
	s.cuerpo = j.cuerpo;
	s.equipo = e;
	s.id = j.reglas.id;
	s.x = j.cuerpo.x;
	s.z = (j.cuerpo.z >= 0.0 ? 1.0 : -1.0) * (_medio_z() + AFUERA_M);
	if (!j.lesionado) {
		s.cuerpo.clip = -1;
		s.cuerpo.fase = SIN_ACCION;
	}
	s.factor = j.lesionado ? FACTOR_SALIR_LESIONADO : FACTOR_SALIR;
	energia_al_salir.push_back({ j.reglas.id, j.energia });
	afuera.push_back(s);
	cuenta.cambios[e & 1]++;
	_adicion[lado() & 1] += r.adicion_cambio_seg;
	_anotar(EV_CAMBIO, e, j.reglas.id, su.jugador.reglas.id, j.lesionado ? 1 : 0, j.cuerpo.x, j.cuerpo.z);
	FichaCerebro f = su.ficha;
	const FichaCerebro &vieja = cerebro.fichas[size_t(sale)];
	f.equipo = e;
	f.rol = vieja.rol;
	f.base_x = vieja.base_x;
	f.base_z = vieja.base_z;
	JugadorCanchita nuevo = su.jugador;
	nuevo.equipo = e;
	nuevo.puesto = j.puesto;
	nuevo.arquero = j.arquero;
	nuevo.energia = nuevo.reglas.energia;
	nuevo.amarillas = 0;
	nuevo.lesionado = false;
	nuevo.en_el_piso_hasta = -1;
	Cuerpo &c = nuevo.cuerpo;
	// Si entran dos juntos, uno al lado del otro: en el mismo punto el choque
	// entre cuerpos los separaba de golpe (un salto de 0,6 m).
	double al_lado = 1.2 * double(_entrando.size());
	c.x = c.previa_x = (_entrando.size() % 2 == 0 ? 1.0 : -1.0) * al_lado;
	c.z = c.previa_z = BANCO_Z;
	c.vx = c.vz = 0.0;
	c.rumbo = 0.0;
	c.clip = -1;
	c.fase = SIN_ACCION;
	c.tiene_objetivo = false;
	nuevo.pensar_ya = true;
	jugadores[size_t(sale)] = nuevo;
	cerebro.cambiar(sale, f);
	if (std::find(_entrando.begin(), _entrando.end(), sale) == _entrando.end()) {
		_entrando.push_back(sale);
	}
}

// --- Offside ---

// En el cuadro del pase (o del remate): los compañeros adelantados quedan
// anotados. Si uno de ellos juega la pelota antes de que la toque otro, es
// offside (Cerebro::en_offside mira esa foto).
void Canchita::_offside_al_patear(int pateador) {
	_adelantados.clear();
	if (!reglas || periodo >= TANDA || modo != PARTIDO) {
		return;
	}
	_armar_mundo();
	int e = jugadores[size_t(pateador)].equipo;
	for (size_t k = 0; k < jugadores.size(); k++) {
		if (int(k) != pateador && jugadores[k].equipo == e && !jugadores[k].arquero && cerebro.en_offside(_mundo, int(k))) {
			_adelantados.push_back(int(k));
		}
	}
}

bool Canchita::_offside_al_tocar(int i) {
	if (std::find(_adelantados.begin(), _adelantados.end(), i) == _adelantados.end()) {
		return false;
	}
	const JugadorCanchita &j = jugadores[size_t(i)];
	cuenta.offsides_cobrados[j.equipo & 1]++;
	_anotar(EV_OFFSIDE, j.equipo, _id(i), -1, 0, j.cuerpo.x, j.cuerpo.z);
	if (cerebro.planes[(1 - j.equipo) & 1].paso_defensa > 0.0) {
		_anotar(EV_JUGADA, 1 - j.equipo, -1, -1, JUGADA_DEFENSA_ADELANTADA, j.cuerpo.x, j.cuerpo.z);
	}
	_adelantados.clear();
	jugadores[size_t(i)].toque_pendiente = false;
	jugadores[size_t(i)].persigue = false;
	// Tiro libre indirecto donde estaba: siempre se juega corto.
	_parar(TIRO_LIBRE, 1 - j.equipo, j.cuerpo.x, j.cuerpo.z);
	if (_parada.tipo_libre != LIBRE_CORTO) {
		cuenta.tiros_libres[_parada.tipo_libre]--;
		cuenta.tiros_libres[LIBRE_CORTO]++;
		_parada.tipo_libre = LIBRE_CORTO;
		_parada.ejecutor = _elegir_ejecutor(TIRO_LIBRE, _parada.equipo, _parada.x, _parada.z, LIBRE_CORTO);
		_lugar_del_ejecutor();
		_marcar_parada();
	}
	return true;
}

// --- Tanda de penales ---

// Penales.orden_de_pateo, simplificado: los de campo de más tiro primero y el
// arquero al final. Patean de a uno, alternados, cada equipo en el arco que
// atacó; los demás miran desde el círculo central.
void Canchita::_empezar_tanda() {
	periodo = TANDA;
	_parada = Parada();
	_remate = Remate();
	for (int e = 0; e < 2; e++) {
		std::vector<int> &orden = _orden_tanda[e];
		orden.clear();
		for (size_t i = 0; i < jugadores.size(); i++) {
			if (jugadores[i].equipo == e && !jugadores[i].arquero) {
				orden.push_back(int(i));
			}
		}
		std::stable_sort(orden.begin(), orden.end(),
				[&](int a, int b) { return jugadores[size_t(a)].tiro > jugadores[size_t(b)].tiro; });
		int a = arquero_de(e);
		if (a >= 0) {
			orden.push_back(a);
		}
	}
	_turno_tanda = 0;
	_tanda_pateo = false;
	_siguiente_penal();
}

void Canchita::_siguiente_penal() {
	int e = _turno_tanda & 1;
	double s = _ataca(e);
	_tanda_pateo = false;
	_en_manos = -1;
	_parar(PENAL, e, Cerebro::MEDIO_LARGO * s - s * param_reglas.distancia_penal_m, 0.0);
}

// Devuelve true si se ocupó del paso (la parada del penal, o anotar el que se
// acaba de patear y armar el que sigue).
bool Canchita::_avanzar_tanda() {
	if (_parada.activa) {
		_avanzar_parada();
		return true;
	}
	if (!_tanda_pateo) {
		// El penal todavía no salió (el gesto falló): se vuelve a armar.
		_siguiente_penal();
		return true;
	}
	if (_remate.activo) {
		return false;
	}
	int e = _turno_tanda & 1;
	bool gol = _ultimo_resultado == REMATE_GOL;
	pateados_tanda[e]++;
	if (gol) {
		goles_tanda[e]++;
	}
	_anotar(EV_PENAL_TANDA, e, _tanda_id, -1, gol ? 1 : 0, pelota.pos.x, pelota.pos.z);
	_turno_tanda++;
	int n = param_reglas.tanda_pateadores;
	bool fin = false;
	if (pateados_tanda[0] <= n && pateados_tanda[1] <= n) {
		int quedan0 = n - pateados_tanda[0], quedan1 = n - pateados_tanda[1];
		fin = goles_tanda[0] > goles_tanda[1] + quedan1 || goles_tanda[1] > goles_tanda[0] + quedan0;
	}
	if (!fin && pateados_tanda[0] >= n && pateados_tanda[0] == pateados_tanda[1]) {
		fin = goles_tanda[0] != goles_tanda[1];
	}
	if (fin || _turno_tanda >= TANDA_MAX) {
		periodo = TERMINADO;
		_parada = Parada();
		_en_manos = -1;
		return true;
	}
	_siguiente_penal();
	return true;
}
