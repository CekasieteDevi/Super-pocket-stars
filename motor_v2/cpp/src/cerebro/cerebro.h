#pragma once

// El cerebro del Motor V2 (docs/motor_v2.md, etapa 4): la utility AI del motor
// espacial (core/motor_espacial.gd) pasada a C++. Lee el mundo y devuelve
// intenciones ("pase a 7 al punto P", "andá a Q"), nunca resultados: quién se
// queda la pelota lo sigue decidiendo el mundo (etapa 3).
//
// Qué se porta, con el nombre de la función de GDScript de donde sale:
// - La decisión del poseedor: evaluar_opciones, _ponderar_plan (estilo,
//   transición, ritmo, marcador y perfil), _premiar_descarga_util,
//   _aplicar_pie_preferido, temperatura y elegir_softmax.
// - Sin pelota: _ancla_de_rol, _objetivo_sin_pelota, _buscar_apoyo y los
//   desmarques (_planificar_desmarques, _candidatos_desmarque, tercer hombre).
// - Sin la pelota el equipo defiende con _planificar_defensa: presionante,
//   cobertura y cierre.
// - Ritmo (_planificar_ritmo), marcador (urgencia) y perfiles (_construir_perfil).
// - De las jugadas preparadas, las de juego abierto: Paredes y Contragolpe.
//   Las de pelota parada esperan a la etapa 6.
//
// Qué es nuevo (no existía en el motor espacial):
// - Grilla de apoyo (Simple Soccer): puntos puntuados por "se le puede pasar",
//   "se puede tirar desde ahí" y "distancia justa al poseedor". Los mejores
//   entran como candidatos de apoyo en los desmarques.
// - Línea defensiva: sin la pelota, centrales y laterales se paran a la misma
//   altura (la media de sus anclas), así suben y bajan juntos.
// - Offside en el cuadro del pase: `en_offside` mira la foto del momento en
//   que sale la pelota. Por ahora solo se cuenta; cobrarlo es la etapa 6.
//
// Etapa 5: el remate (la opción `tiro` del motor espacial, DEC_REMATE) y
// adónde y cómo patear (elegir_remate, con el valor que da el planeador). Lo
// que hace el arquero lo resuelve la canchita (canchita.h).
//
// Qué NO entra todavía: gambeta (faltan los clips de regate) y pelota parada
// (etapa 6).
//
// Unidades: el motor espacial contaba en ticks de 0,25 s. Acá todo va en
// segundos; los parámetros que vienen de data/utility_pesos.json en ticks se
// pasan con TICK_ESPACIAL_SEG. Ejes como el resto del V2: x a lo largo, z a lo
// ancho. El equipo 0 ataca hacia +x (el "local" de GDScript).
//
// Sin Godot: solo C++ y matematica_fija.h.

#include "azar.h"

#include <cstdint>
#include <vector>

namespace motor_v2 {

enum Rol : int {
	ARQ = 0,
	DFC = 1,
	LAT = 2,
	MC = 3,
	MCO = 4,
	EXT = 5,
	DC = 6,
	ROLES = 7,
};

// Atributos de Player que lee el cerebro.
enum Atributo : int {
	AT_PASES = 0,
	AT_VISION,
	AT_INTELIGENCIA,
	AT_CONTROL,
	AT_CENTROS,
	AT_FUERZA,
	AT_GOLPE,
	AT_VELOCIDAD,
	AT_ACELERACION,
	AT_ENERGIA,
	AT_AGILIDAD,
	AT_CABEZAZO,
	AT_TIRO,
	// Del arquero: la salida corta (atributo_pase).
	AT_PIES,
	// Del arquero (etapa 5): reacción, alcance de la estirada, retener la
	// pelota y salir a achicar.
	AT_REFLEJOS,
	AT_ESTIRADA,
	AT_AGARRE,
	AT_ACHIQUE,
	ATRIBUTOS,
};

// Los cinco gustos del perfil (MotorEspacial.RASGOS_PERFIL).
enum Rasgo : int {
	ASOCIACION = 0,
	RUPTURA,
	REGATE,
	DESCARGA,
	LLEGADA,
	RASGOS,
};

// Lo que el cerebro le pide al poseedor.
enum TipoDecision : int {
	DEC_NADA = 0,
	DEC_CONDUCIR,
	DEC_PASE,
	DEC_PASE_HUECO,
	DEC_PASE_LARGO,
	DEC_CENTRO,
	DEC_PARED,
	DEC_DESPEJE,
	// Etapa 5: tirar al arco. El punto y el tipo de golpe salen de
	// Cerebro::elegir_remate.
	DEC_REMATE,
	DECISIONES,
};

// Papel de un defensor en el plan de defensa.
enum PapelDefensa : int {
	SIN_PAPEL = 0,
	PRESIONANTE = 1,
	COBERTURA = 2,
	CIERRE = 3,
};

// Tipos de desmarque (MotorEspacial.TIPOS_DESMARQUE).
enum TipoDesmarque : int {
	DES_APOYO = 0,
	DES_RUPTURA,
	DES_ARRASTRE,
	DES_LLEGADA,
};

// Los pesos de data/utility_pesos.json que usa el cerebro, con los mismos
// nombres (sección_clave). Los valores de acá son los del JSON, para quien
// crea el cerebro sin configurarlo; tests/test_cerebro_v2.gd falla si se
// separan. Al final, los nuevos de data/fisica_v2.json ("cerebro").
struct PesosCerebro {
	// conducir
	double conducir_base = 0.3, conducir_espacio = 0.5, conducir_progreso = 0.3, conducir_camino = 0.15;
	// pase
	double pase_base = 0.25, pase_progreso = 1.0, pase_seguridad = 0.45, pase_distancia = 0.55, pase_retroceso_libre = 1.2;
	// despeje
	double despeje_base = 0.15, despeje_presion = 0.85, despeje_zona = 0.55;
	// centro
	double centro_base = 1.45, centro_punteria = 1.35, centro_progreso = 0.65;
	// pared
	double pared_base = 0.25, pared_progreso = 1.1, pared_seguridad = 0.5;
	// pase_largo
	double largo_base = 0.2, largo_progreso = 0.7, largo_presion = 0.55, largo_salida = 0.45;
	// tiro
	double tiro_base = 0.0, tiro_geometria = 8.5;
	// pase_hueco
	double hueco_base = 0.1, hueco_progreso = 1.3, hueco_seguridad = 0.3, hueco_distancia = 0.2;
	// temperatura
	double temp_base = 0.55, temp_k_vision = 0.25, temp_k_inteligencia = 0.15, temp_k_presion = 0.4;
	double temp_min = 0.08, temp_max = 1.2, temp_factor_metodico = 0.8;
	// presion
	double presion_radio = 7.0, presion_factor_frente = 1.5, presion_normalizador = 2.5;
	// sesgos_personalidad
	double creador_pase = 1.3, pie_preferido_penalizacion = 0.25, egoista_tiro = 1.4;
	// asociacion_colectiva
	double descarga_util = 0.35;
	// fisica
	double vel_min = 3.6, vel_max = 9.2, vel_pase_min = 11.0, vel_pase_max = 24.0;
	double hueco_min = 6.0, hueco_max = 15.0, vision_minima_hueco = 45.0, hueco_por_vision = 0.45;
	double pases_minimo_pared = 40.0, centros_minimo = 15.0, banda_para_centrar = 5.5, apego_a_la_banda = 0.5;
	double avance_para_centrar = 0.25, offside_margen_torpe = 5.5, avance_para_jugar_en_el_hombro = 0.2;
	double apoyo_del_delantero = 0.35, apoyo_del_nueve = 0.0, avance_para_acompanar = 0.5;
	double avance_acompanamiento_pleno = 0.75, desplazamiento_por_estilo = 16.0;
	double angulo_minimo_tiro_libre = 0.35, zona_despeje = 0.42, presion_despeje = 0.45;
	double despeje_corto = 30.0, despeje_largo = 55.0;
	double pared_muro_cerca = 6.0, pared_muro_lejos = 17.0, pared_avance_min = 5.0, pared_avance_max = 14.0;
	double max_dist_pase_malo = 16.0, max_dist_pase_bueno = 32.0;
	double max_pelotazo_debil = 11.0, max_pelotazo_fuerte = 62.0;
	double corredor_conduccion = 18.0, ticks_control_malo = 9.0, ticks_control_bueno = 2.0;
	double rango_tiro_medio = 24.0, tercio_propio_arquero = 30.0, dist_saque_largo = 28.0;
	double radio_tackle = 2.0, gambeta_cono_frontal = -0.1;
	double rango_tiro_malo = 16.0, rango_tiro_bueno = 36.0, mezcla_fisica_rango_tiro = 0.8;
	double geometria_minima_tiro = 0.03;
	// ritmo
	double ritmo_umbral_transicion = 0.7, ritmo_frente = 12.0, ritmo_espacio_para_acelerar = 0.62;
	double ritmo_apoyo_libre = 0.65, ritmo_apoyo_adelante = 4.0, ritmo_apoyo_alcance = 32.0, ritmo_carril_libre = 0.4;
	double ritmo_circulacion_apoyo = 0.35, ritmo_circulacion_cambio = 0.3, ritmo_circulacion_dist = 22.0;
	double ritmo_aceleracion_progreso = 0.35, ritmo_aceleracion_conducir = 0.25, ritmo_tope = 0.5;
	double ritmo_estancada_ticks = 12.0, ritmo_estancada_avance = 4.0, ritmo_estancada_presion = 0.35;
	double ritmo_devolucion_castigo = 0.3, ritmo_devolucion_max = 3.0;
	// marcador
	double marc_exponente = 3.0, marc_empate = 0.25, marc_dif_extra = 0.35, marc_dif_tope = 1.35;
	double marc_dt_loco = 1.35, marc_dt_conservador = 1.35, marc_altura_bloque = 6.0, marc_tope = 0.35;
	double marc_riesgo = 0.35, marc_seguridad = 0.3, marc_seguridad_dist = 22.0;
	double marc_urgencia_para_romper = 0.45, marc_urgencia_para_guardar = 0.45, marc_cierre = 0.3;
	double marc_cobertura_extra = 0.5;
	// perfil
	double perfil_reparto = 1.6, perfil_tope = 0.3, perfil_asociacion = 0.28, perfil_regate = 0.3;
	double perfil_descarga = 0.26, perfil_corto_dist = 24.0, perfil_desmarque = 0.35;
	// sin_pelota
	double sp_linea = 1.0, sp_espacio = 0.9, sp_progreso = 1.6, sp_distancia_util = 0.7, sp_viaje = 0.5;
	double sp_dist_ideal = 15.0, sp_dist_tolerancia = 13.0, sp_conflicto = 2.0, sp_minimo = 0.35;
	double sp_sesgo_apoyo = 0.3, sp_sesgo_ruptura = 0.1, sp_sesgo_arrastre = -0.1, sp_sesgo_llegada = 0.0;
	double sp_pared_riesgo_max = 0.55;
	// defensa
	double def_zona = 0.06, def_cansancio = 0.5, def_mejora_presionante = 0.2, def_cobertura_atras = 8.0;
	double def_cobertura_cerca = 0.6, def_cobertura_bloque = 1.6, def_enganche = 3.5, def_cierre_cerca = 4.0;
	double def_cierre_lejos = 24.0, def_cierre_carril = 0.55, def_banda_disparador = 8.0;
	double def_intensidad_para_cierre = 0.6;
	double def_radio_defensa = 12.0, def_radio_medio = 16.0, def_radio_ataque = 20.0;

	// Nuevos (data/fisica_v2.json, "cerebro"; ahí está el porqué de cada uno).
	int grilla_columnas = 12;
	int grilla_filas = 8;
	double grilla_rapidez_pase = 15.0;
	double grilla_peso_pase = 1.0;
	double grilla_peso_tiro = 0.6;
	double grilla_peso_distancia = 0.5;
	double grilla_candidatos = 3.0;
	double grilla_bono = 0.35;
	double linea_mezcla = 1.0;
	double decision_vigencia_seg = 1.0;
	double riesgo_por_tiempos = 1.0;
	double riesgo_rapidez_pase = 8.5;
	double riesgo_margen_seguro = 0.5;
	double entrada_ventaja_seg = 0.5;
	double castigo_corte = 1.0;
	double remate_temperatura = 0.05;
	// No sale de ningún JSON: es toque.reaccion_seg, que la canchita le copia
	// al empezar (una sola fuente de verdad).
	double reaccion_seg = 0.2;
};

// El plan de juego del estilo del club (Estilos.plan y compañía), ya armado
// por GDScript.
struct PlanEquipo {
	double asociacion = 0.5, verticalidad = 0.5, amplitud = 0.5, transicion = 0.5;
	// Estilos.retroceso_sin_pelota(estilo) - Estilos.RETROCESO_DEFAULT.
	double retroceso = 0.0;
	// Estilos.acompanamiento(estilo) / Estilos.ACOMPANAMIENTO_DEFAULT.
	double acompanamiento = 1.0;
	double intencion_centro = 1.0;
	bool contragolpe = false;
	bool presion_alta = false;
	bool defensivo = false;
	// Jugadas.UTILIDAD_PARED * Jugadas.factor(..., PAREDES).
	double extra_pared = 0.0;
	// Jugadas.EXTRA_CONTRAGOLPE * Jugadas.factor(..., CONTRAGOLPE).
	double extra_contragolpe = 0.0;
	// 0 sin rasgo, 1 Loco, 2 Conservador (Team.dt["rasgo"]).
	int rasgo_dt = 0;
};

// Un jugador para el cerebro: lo que no cambia en el partido.
struct FichaCerebro {
	int equipo = 0;
	int rol = MC;
	// Casillero de la formación para el que ataca hacia +x (Formaciones.slots).
	double base_x = 0.0, base_z = 0.0;
	double bruto[ATRIBUTOS] = {};
	// MatchEngine.relativo_al_nivel de cada atributo.
	double relativo[ATRIBUTOS] = {};
	bool creador = false;
	bool metodico = false;
	bool egoista = false;
	// Pie preferido: 0 si no tiene el rasgo; si no, +1 derecho o -1 zurdo.
	int pie_malo_lado = 0;
	// Enfocado: MotorEspacial.FACTOR_OFFSIDE_ENFOCADO y TOLERANCIA_OFFSIDE_ENFOCADO.
	double margen_offside = 1.0;
	double perfil[RASGOS] = { 0.5, 0.5, 0.5, 0.5, 0.5 };
};

// Lo que el cerebro ve de un jugador en este momento.
struct JugadorVisto {
	double x = 0.0, z = 0.0;
	double vx = 0.0, vz = 0.0;
	// Ya con el cansancio del partido.
	double vel_max = 7.5;
	double aceleracion = 3.8;
	double resistencia = 1.0;
	// Hacia dónde mira (orientacion_de).
	double mira_x = 1.0, mira_z = 0.0;
};

// La foto del partido que el cerebro lee.
struct Mundo {
	std::vector<JugadorVisto> jugadores;
	double pelota_x = 0.0, pelota_z = 0.0;
	// El que la tiene controlada (-1 si va suelta o viajando).
	int poseedor = -1;
	int equipo_con_pelota = 0;
	// Segundos que lleva el poseedor con la pelota (ticks_con_pelota).
	double con_pelota_seg = 0.0;
	double segundos = 0.0;
	// Minutos jugados (para la urgencia) y goles de cada equipo.
	double minuto = 0.0;
	int goles[2] = { 0, 0 };
	// Hay un saque: el juego está parado.
	bool detenido = false;
};

// El mundo que planea los pases con su propia física (la canchita, etapa 3).
// El cerebro le pregunta cuánto margen tiene un pase: el mismo cálculo con
// que después sale la pelota (docs/motor_v2.md, "Todos planean con la misma
// física"). Solo vale mientras el cerebro decide (el mundo sabe desde dónde y
// cuándo va a patear).
class Planeador {
public:
	virtual ~Planeador() = default;
	// Segundos que le lleva la pelota al rival que mejor corta el pase raso de
	// `de` a `a` (a los pies o a una tangente, el mejor); < 0 = alguien llega
	// antes. -1e9 si no hay pase.
	virtual double margen_pase(int de, int a) = 0;
	// Lo mismo para un pase al punto (x, z) con la rapidez para que `a` llegue.
	virtual double margen_al_punto(int de, int a, double x, double z) = 0;
	// Lo mismo para un globo que cae en (x, z): solo cuenta donde vuela a la
	// altura de la cabeza o menos.
	virtual double margen_globo(int de, double x, double z) = 0;
	// Etapa 5: qué tan bueno es un remate de `de` al punto (alto, lateral) del
	// arco rival con el golpe `tipo` (remate.h): la chance de que vaya adentro
	// y el arquero no llegue, con el mismo error y el mismo arquero que
	// después juegan. -1 si ese golpe no llega.
	virtual double valor_remate(int de, int tipo, double alto, double lateral) = 0;
};

struct Decision {
	int tipo = DEC_NADA;
	int receptor = -1;
	bool tiene_punto = false;
	double x = 0.0, z = 0.0;
	// Pared: quién sale a buscar la devolución y adónde.
	int corredor = -1;
	double retorno_x = 0.0, retorno_z = 0.0;
	double utilidad = 0.0;
	double probabilidad = 1.0;
	// Conducir: hacia dónde.
	double dir_x = 1.0, dir_z = 0.0;
	// Viene de un desmarque preparado (pase al espacio que "sale solo").
	bool corrida_preparada = false;
	// Remate: el golpe (TipoRemate de remate.h) y el alto del punto del arco
	// (x, z es el punto sobre la línea).
	int golpe = 0;
	double alto = 0.0;
};

// Adónde va uno que no tiene la pelota.
struct Objetivo {
	double x = 0.0, z = 0.0;
	double factor = 1.0;
	bool frenar = true;
	int papel = SIN_PAPEL;
	bool desmarque = false;
};

struct PlanDesmarque {
	bool vivo = false;
	int tipo = DES_APOYO;
	double x = 0.0, z = 0.0;
	int companero = -1;
	double hasta = 0.0;
	bool pase_atras = false;
	bool doblamiento = false;
	bool nueve_baja = false;
	bool relevo_nueve = false;
	// Sale de la grilla de apoyo (nuevo, Simple Soccer).
	bool de_grilla = false;
	double espacio_x = 0.0, espacio_z = 0.0;
};

// Una opción que pesó el poseedor, con su utilidad final (para ver por qué
// eligió lo que eligió: §7 del motor espacial).
struct OpcionVista {
	int tipo = DEC_NADA;
	int receptor = -1;
	double x = 0.0, z = 0.0;
	double utilidad = 0.0;
};

// Lo que cuenta el cerebro (para los tests y el diagnóstico).
struct ContadoresCerebro {
	int64_t decisiones[DECISIONES] = {};
	int64_t corridas_preparadas = 0;
	int64_t desmarques[4] = {};
	int64_t fases_ritmo[3] = {};
	int64_t apoyos_de_grilla = 0;
};

class Cerebro {
public:
	static constexpr double LARGO = 105.0;
	static constexpr double ANCHO = 68.0;
	static constexpr double MEDIO_LARGO = 52.5;
	static constexpr double MEDIO_ANCHO = 34.0;
	static constexpr double AREA_LARGO = 16.5;
	static constexpr double AREA_MEDIO_ANCHO = 20.16;
	static constexpr double LIMITE_X = 43.5;
	// Un tick del motor espacial: los pesos que vienen contados en ticks.
	static constexpr double TICK_ESPACIAL_SEG = 0.25;

	PesosCerebro pesos;
	PlanEquipo planes[2];
	// Si hay, el riesgo de los pases sale de su física (ver Planeador).
	Planeador *planeador = nullptr;
	std::vector<FichaCerebro> fichas;
	ContadoresCerebro cuenta;
	// La última decisión: quién, con qué temperatura y entre qué opciones.
	int ultimo_decisor = -1;
	double ultima_temperatura = 0.0;
	std::vector<OpcionVista> ultimas_opciones;

	void agregar(const FichaCerebro &f);
	// Arma los perfiles y deja los planes en cero.
	void empezar();
	// Lo que cambia el plan de todos: transición, ritmo, marcador, línea de
	// offside, línea defensiva, defensa, desmarques y grilla de apoyo. Cada
	// cosa con su propio reloj, como en el motor espacial.
	void planificar(const Mundo &m);
	// La decisión del poseedor. `puede_pasar` = ya aguantó la demora de
	// control (cadencia): antes solo conduce.
	Decision decidir(const Mundo &m, int i, bool puede_pasar, Azar &azar);
	// Adónde va el que no tiene la pelota ni va a buscarla.
	Objetivo objetivo(const Mundo &m, int i) const;
	// Etapa 5: adónde y cómo remata `i` (el golpe, el punto y su valor), entre
	// los puntos del arco que le pregunta al planeador. `solo_cabeza`: la
	// pelota le llega alta y solo la puede cabecear.
	Decision elegir_remate(const Mundo &m, int i, bool solo_cabeza, Azar &azar) const;
	// Si le da el alcance para tirar desde (x, z) (factor_geometria con su
	// rango de tiro, rango_tiro_malo a rango_tiro_bueno).
	bool alcanza_para_tirar(int i, double x, double z) const;
	// El que sale a presionar al poseedor (-1 si nadie).
	int presionante(int equipo_defensor) const {
		return _defensa[equipo_defensor & 1].presionante;
	}
	int papel(int i) const;
	// Segundos que el poseedor aguanta antes de decidir (cadencia_de_decision).
	double cadencia_seg(int i) const;

	// Avisos del mundo.
	void anotar_pase(const Mundo &m, int de, int a);
	void anotar_pared(const Mundo &m, int muro, int corredor, double x, double z);
	// El muro de la pared activa (-1 si no hay) y adónde la devuelve.
	int muro_de_pared(const Mundo &m, int &corredor, double &x, double &z) const;
	void terminar_pared() {
		_pared.vivo = false;
	}

	// Offside en el cuadro del pase: `receptor` está adelantado respecto de la
	// pelota y del último defensor de campo, en campo rival.
	bool en_offside(const Mundo &m, int receptor) const;
	double linea_offside(int equipo) const {
		return _linea_offside[equipo & 1];
	}
	double linea_defensiva(int equipo) const {
		return _linea_defensiva[equipo & 1];
	}
	const PlanDesmarque &desmarque(int i) const {
		return _desmarques[size_t(i)];
	}
	double urgencia(int equipo) const {
		return _urgencia[equipo & 1];
	}
	int fase_ritmo() const {
		return _ritmo.fase;
	}

	// Geometría (las mismas del motor espacial; públicas para los tests).
	static double signo(int equipo) {
		return equipo == 0 ? 1.0 : -1.0;
	}
	static double valor_posicion(double x, double z, int equipo);
	static double factor_angulo(double x, double z, int equipo);
	double factor_geometria(double x, double z, int equipo) const;
	double presion_normalizada(const Mundo &m, double x, double z, int equipo, int excluir = -1) const;
	double riesgo_linea(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const;
	static double dist_a_segmento(double px, double pz, double ax, double az, double bx, double bz);

private:
	struct Defensa {
		int presionante = -1;
		int cobertura = -1;
		int cierre = -1;
		double hasta = -1.0;
		bool enganchado = false;
		double cierre_x = 0.0, cierre_z = 0.0;
		bool hay_cierre = false;
		double intensidad = 0.0;
	};
	struct Ritmo {
		bool hay = false;
		int equipo = 0;
		int fase = 2;
		double hasta = -1.0;
		double x_inicio = 0.0;
		double mejor = 0.0;
		double mejor_premiado = 0.0;
		double t_avance = 0.0;
		int toques_circulacion = 0;
		std::vector<int> participantes;
		// Pases entre cada pareja desde el último avance (a * n + b, a < b).
		std::vector<int> pares;
	};
	struct Corredor {
		double x = 0.0, z = 0.0;
		double hasta = -1.0;
	};
	struct Apoyo {
		double x = 0.0, z = 0.0;
		double hasta = -1.0;
		int poseedor = -2;
	};
	struct Casilla {
		double x = 0.0, z = 0.0;
		double puntaje = -1e9;
	};
	struct Pared {
		bool vivo = false;
		int muro = -1;
		int corredor = -1;
		double x = 0.0, z = 0.0;
		double hasta = 0.0;
	};
	struct Opcion {
		int tipo = DEC_NADA;
		double utilidad = 0.0;
		int receptor = -1;
		bool tiene_punto = false;
		double x = 0.0, z = 0.0;
		int corredor = -1;
		bool pase_atras_al_area = false;
		bool corrida_preparada = false;
	};

	Defensa _defensa[2];
	Ritmo _ritmo;
	std::vector<PlanDesmarque> _desmarques;
	mutable std::vector<Corredor> _corredores;
	mutable std::vector<Apoyo> _apoyos;
	std::vector<Casilla> _grilla;
	std::vector<Casilla> _mejores_casillas;
	Pared _pared;
	double _linea_offside[2] = { LIMITE_X, -LIMITE_X };
	double _linea_defensiva[2] = { -30.0, 30.0 };
	double _urgencia[2] = { 0.0, 0.0 };
	double _desmarques_hasta = -1.0;
	int _desmarques_equipo = -1;
	// Transición: el equipo que recuperó y hasta cuándo dura.
	int _transicion_equipo = -1;
	double _transicion_hasta = -1.0;
	int _ultimo_equipo = -1;
	// El último pase (de, a) y de qué equipo.
	int _ultimo_de = -1, _ultimo_a = -1;

	double _radio_zona(int rol) const;
	double _por_atributo(int i, int atributo, double en_0, double en_100, double mezcla_absoluta = 0.0) const;
	double _presion_sobre(const Mundo &m, double x, double z, int equipo, int excluir) const;
	// Riesgo de la línea de pase para decidir: mezcla riesgo_linea (qué tan
	// cerca pasa cada rival) con el pase seguro por tiempos de Simple Soccer.
	double _riesgo_pase(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const;
	// Con planeador: el riesgo que da el margen de su física.
	double _riesgo_de_margen(double margen) const;
	double _riesgo_de_salida(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const;
	void _destino_de_conduccion(double x, double z, int equipo, double &dx, double &dz) const;
	void _corredor_elegido(const Mundo &m, int i, double &cx, double &cz) const;
	bool _corredor_de_desborde(const Mundo &m, int i, double &cx, double &cz) const;
	double _transicion(const Mundo &m, int equipo) const;
	double _temperatura(int i, double presion) const;
	bool _zona_de_desborde(double x, double z, int equipo) const;
	bool _en_el_area(double x, double z, int equipo) const;
	bool _solo_frente_al_arco(const Mundo &m, int i) const;
	bool _arquero_encerrado(const Mundo &m, int equipo) const;
	int _rival_a_encarar(const Mundo &m, int i) const;
	double _ventaja_cambio_frente(const Mundo &m, double ax, double az, double bx, double bz, int equipo) const;
	void _punto_al_hueco(const Mundo &m, int r, double &x, double &z) const;
	void _punto_retorno_pared(double x, double z, int equipo, double avance, double &rx, double &rz) const;
	bool _encuentro_pase_atras(const Mundo &m, int pasador, int receptor, double px, double pz, double alcance,
			double &ex, double &ez) const;
	bool _buscar_tercer_hombre(const Mundo &m, int pasador, int apoyo, int &clave, double &x, double &z,
			double &riesgo) const;
	int _fallback_centro(const Mundo &m, int equipo, int excluir) const;
	double _cruce_al_pie_malo(int i, double ax, double az, double bx, double bz) const;

	void _evaluar(const Mundo &m, int i, std::vector<Opcion> &opciones) const;
	void _ponderar(const Mundo &m, int i, std::vector<Opcion> &opciones, double presion, double camino);
	void _premiar_descarga(const Mundo &m, int i, std::vector<Opcion> &opciones) const;
	int _ventana_tras_circular(const Mundo &m, int i, const std::vector<Opcion> &opciones) const;
	double _ajuste_de_ritmo(int fase, int tipo, double adelante, double dist, double libertad, bool cambio,
			double camino) const;
	double _ajuste_de_marcador(double urg, int tipo, double adelante, double dist, double libertad) const;
	double _ajuste_de_perfil(int i, int receptor, int tipo, double adelante, double dist, double libertad,
			double presion, double camino) const;
	double _gusto(int i, int rasgo) const;
	int _veces_de_la_pareja(int a, int b) const;
	bool _posesion_estancada(const Mundo &m, double presion) const;

	void _actualizar_transicion(const Mundo &m);
	void _planificar_ritmo(const Mundo &m);
	void _planificar_marcador(const Mundo &m);
	void _calcular_lineas(const Mundo &m);
	void _planificar_defensa(const Mundo &m, int defiende);
	double _tiempo_de_llegada(const Mundo &m, int i, double x, double z) const;
	void _recortar_a_la_zona(int i, double &x, double &z) const;
	double _intensidad_de_presion(const Mundo &m, int defiende) const;
	void _punto_de_cobertura(const Mundo &m, int presionante_, double intensidad, double &x, double &z) const;
	bool _punto_de_cierre(const Mundo &m, int defiende, double evitar_x, double evitar_z, double &x, double &z) const;
	bool _presion_superada(const Mundo &m, int defiende) const;

	void _planificar_grilla(const Mundo &m);
	void _planificar_desmarques(const Mundo &m, int ataca);
	bool _desmarque_sigue_vivo(const Mundo &m, int i);
	void _destino_legal(double x, double z, int equipo, double &lx, double &lz) const;
	double _valor_de_desmarque(const Mundo &m, int i, int poseedor, double x, double z, int tipo) const;
	struct Candidato {
		PlanDesmarque plan;
		double valor = 0.0;
	};
	void _candidatos_desmarque(const Mundo &m, int i, int poseedor, double ancla_x, double ancla_z,
			std::vector<Candidato> &salida) const;
	bool _diagonal_extremo(const Mundo &m, int i, int poseedor, Candidato &c) const;
	void _anotar_desmarque(const Mundo &m, int i, const PlanDesmarque &p);
	int _cupo_de_rupturas(int equipo) const;

	// _ancla_de_rol: devuelve true si el punto ya es el definitivo ("listo").
	bool _ancla(const Mundo &m, int i, bool tiene_mi_equipo, double &x, double &z) const;
	void _buscar_apoyo(const Mundo &m, int i, double base_x, double base_z, double &x, double &z) const;
	void _objetivo_sin_pelota(const Mundo &m, int i, bool tiene_mi_equipo, double &x, double &z) const;
};

} // namespace motor_v2
