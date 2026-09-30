#pragma once

// Banco de la etapa 3 del Motor V2 (docs/motor_v2.md): una canchita sin
// arcos con pelota, cuerpos y cerebros sencillos. Dos juegos:
// - RONDO: 4 contra 2 en un cuadrado de RONDO_LADO m. Los cuatro de afuera
//   se la pasan; si un defensor la toca, es corte y se vuelve a empezar.
// - PARTIDITO: 5 contra 5 en una cancha de PARTIDITO_LARGO × PARTIDITO_ANCHO
//   m. El que la gana se la queda.
//
// Lo que prueba es tocar la pelota: conducción por toques, recepción según la
// altura (pie, muslo, pecho, cabeza), pase al punto de encuentro con los
// tiempos de llegada de cada rival, e intercepción = el primero que la
// alcanza. Nadie corrige la pelota: el cuerpo arranca un gesto, y si en la
// ventana de contacto su pie (o su pecho, o su frente) está en la pelota, la
// toca. Los cerebros son del banco: los de verdad llegan en la etapa 4.
//
// Etapa 4 suma un tercer juego:
// - PARTIDO: 11 contra 11 en la cancha entera, sin arqueros que atajen ni
//   reglas (etapa 5 y 6). Los cerebros son los de verdad (cerebro/cerebro.h):
//   el poseedor decide con la utility AI del motor espacial y los demás van
//   adonde el cerebro les pide. Si un equipo controla la pelota en el área
//   rival, cuenta como llegada y el otro saca del arco.
//
// Etapa 5 suma el arco (docs/motor_v2.md, "Etapa 5 — Remates y arqueros"):
// en el PARTIDO el poseedor puede rematar (el cerebro elige punto y golpe) y
// cada equipo tiene un arquero que lee la trayectoria, elige parado o
// estirada y la agarra, la da en rebote o no llega. El gol lo decide la
// pelota al cruzar la línea: nadie lo adjudica. Después del gol se saca del
// medio. Las demás reglas siguen siendo las del banco (etapa 6). La llegada
// ya no termina la jugada: se cuenta una por posesión.
//
// Sin Godot: solo C++ y matematica_fija.h.

#include "azar.h"
#include "cerebro/cerebro.h"
#include "cuerpo.h"
#include "pelota.h"
#include "remate.h"
#include "toque.h"

#include <cstdint>
#include <vector>

namespace motor_v2 {

enum ModoCanchita : int {
	RONDO = 0,
	PARTIDITO = 1,
	// Para los tests: cada uno se queda en su lugar (poner_jugador) y solo va
	// a la pelota que se lanza (lanzar). El que la controla no sigue.
	PRUEBA = 2,
	PARTIDO = 3,
	// Etapa 5, para los tests y el laboratorio de remates: como PRUEBA pero en
	// la cancha entera, con los arcos y el arquero (rematar()).
	ARCO = 4,
};

enum TipoToque : int {
	TOQUE_NADA = 0,
	TOQUE_PASE = 1,
	TOQUE_CONDUCE = 2,
	TOQUE_CONTROL = 3,
	// Etapa 5: al arco, y el arquero con las manos.
	TOQUE_REMATE = 4,
	TOQUE_ATAJADA = 5,
};

// Cómo terminó un remate (el mundo lo decide, ver Canchita::_cerrar_remate).
enum ResultadoRemate : int {
	REMATE_GOL = 0,
	REMATE_ATAJADO = 1,
	REMATE_PALO = 2,
	REMATE_BLOQUEADO = 3,
	REMATE_AFUERA = 4,
	// Se quedó corto o lo desvió un compañero.
	REMATE_OTRO = 5,
	RESULTADOS_REMATE = 6,
};

// Lo que miden los detectores de la etapa 3 (docs/motor_v2.md, "Pasa si").
struct ContadoresCanchita {
	int64_t pases = 0;
	int64_t pases_globo = 0;
	int64_t completados = 0;
	// Lo recibió un compañero que no era el buscado.
	int64_t completados_otro = 0;
	// Pases que el receptor mandó de primera, sin pararla.
	int64_t de_primera = 0;
	int64_t cortes = 0;
	int64_t desvios = 0;
	int64_t quites = 0;
	int64_t pases_afuera = 0;
	int64_t salidas = 0;
	int64_t reinicios = 0;
	int64_t conducciones = 0;
	int64_t controles = 0;
	int64_t recepciones[4] = { 0, 0, 0, 0 };
	// Gestos que abrieron la ventana y no llegaron a la pelota.
	int64_t fallos = 0;
	// Tenía la ventana abierta pero otro la tocó primero.
	int64_t cruces_perdidos = 0;
	int64_t rebotes_cuerpo = 0;
	// La pelota cambió de velocidad sin que la tocara nadie ni la física:
	// tiene que dar 0 siempre (docs/motor_v2.md, "Pasa si").
	int64_t correcciones = 0;
	// El corte más lejano: distancia en el piso del pie del defensor a la
	// pelota en el toque. Un pase solo se corta si un defensor llega.
	double corte_mas_lejos_m = 0.0;
	// Receptores: segundos quietos (< RAPIDEZ_QUIETO) con el pase viniendo,
	// desde que reaccionan hasta que la tocan.
	int64_t recepciones_medidas = 0;
	double espera_suma = 0.0;
	double espera_max = 0.0;
	int64_t esperas_largas = 0;
	// Algún cuerpo bajó su rapidez más que la frenada en un paso.
	int64_t frenadas_en_seco = 0;
	// Peor paso de un cuerpo más allá de lo que da su velocidad (lo empujan
	// los choques entre cuerpos).
	double peor_salto_cuerpo_m = 0.0;
	double posesion_seg[2] = { 0.0, 0.0 };

	// PARTIDO (etapa 4, docs/motor_v2.md "Pasa si").
	// Posesiones: cada vez que la pelota cambia de equipo. Los pases son los
	// completados entre compañeros durante esa posesión.
	int64_t posesiones = 0;
	int64_t pases_en_posesiones = 0;
	int64_t posesiones_3_pases = 0;
	int64_t posesiones_5_pases = 0;
	int64_t max_pases_posesion = 0;
	// Pases a un punto por delante del receptor (al hueco o al desmarque).
	int64_t pases_al_espacio = 0;
	int64_t pases_al_espacio_completos = 0;
	// Salieron hacia la corrida que el cerebro ya había preparado.
	int64_t pases_a_corrida = 0;
	int64_t offsides = 0;
	int64_t llegadas[2] = { 0, 0 };
	int64_t saques_de_arco = 0;
	int64_t laterales = 0;
	int64_t corners = 0;
	int64_t paredes_devueltas = 0;
	// De dónde salen los quites: la pelota venía de una conducción, de un
	// control, o suelta (rebote, pelota que nadie tenía).
	int64_t quites_conduccion = 0;
	int64_t quites_control = 0;
	int64_t quites_suelta = 0;

	// Etapa 5 (docs/motor_v2.md, "Pasa si"): el embudo de remates, con los
	// mismos cortes que tests/_diag_embudo_remates.gd. Al arco = gol + atajado.
	int64_t remates = 0;
	int64_t remates_equipo[2] = { 0, 0 };
	int64_t remates_cabeza = 0;
	int64_t remates_primera = 0;
	int64_t resultados[RESULTADOS_REMATE] = {};
	int64_t goles[2] = { 0, 0 };
	int64_t goles_cabeza = 0;
	int64_t golpes[TIPOS_REMATE] = {};
	double distancia_remates = 0.0;
	// Remates que salen de un rebote del arquero (hasta 3 s después).
	int64_t remates_tras_rebote = 0;
	int64_t goles_tras_rebote = 0;
	// Lo que hizo el arquero con la pelota que tocó.
	int64_t agarres = 0;
	int64_t rebotes_arquero = 0;
	int64_t roces_arquero = 0;
	int64_t estiradas = 0;
	int64_t paradas = 0;
	// Pelotas sueltas que salió a agarrar (no remates).
	int64_t salidas_arquero = 0;
	// Gestos de atajada que no llegaron a la pelota.
	int64_t atajadas_falladas = 0;
};

// Un remate, para el diagnóstico (tests/_diag_remates_v2.gd): de dónde salió,
// adónde apuntaba, dónde estaba el arquero y cómo terminó.
struct RegistroRemate {
	int equipo = 0;
	int pateador = -1;
	int golpe = 0;
	bool de_primera = false;
	double desde_x = 0.0, desde_z = 0.0;
	double alto = 0.0, lateral = 0.0;
	double rapidez = 0.0;
	// El rival más cerca de la pelota al patear (m).
	double presion_m = 0.0;
	// El arquero al patear (NAN si no hay).
	double arquero_x = 0.0, arquero_z = 0.0;
	// El clip de atajada que arrancó (ClipArquero), -1 si no se tiró.
	int clip_arquero = -1;
	// El arquero estaba en medio de otro gesto al patear, y en qué paso
	// planeó la atajada (-1 si nunca).
	bool arquero_ocupado = false;
	int64_t paso_remate = 0;
	int64_t paso_plan = -1;
	int resultado = -1;
};

struct JugadorCanchita {
	Cuerpo cuerpo;
	int equipo = 0;
	// Lugar dentro del equipo (0..4): el lado del rondo o el ancla del partidito.
	int puesto = 0;
	// Atributos de Player (0..100).
	double pases = 50.0;
	double control = 50.0;
	// Etapa 5, relativos al nivel del partido (MatchEngine.relativo_al_nivel),
	// como la puntería del motor espacial.
	double tiro = 50.0;
	double golpe = 50.0;
	double cabezazo = 50.0;
	double reflejos = 50.0;
	double estirada = 50.0;
	double agarre = 50.0;
	double achique = 50.0;
	// Pie preferido: 0 sin el rasgo; +1 derecho, -1 zurdo.
	int pie_malo_lado = 0;
	bool arquero = false;

	// El plan: ir a tocar la pelota en el paso `paso_meta` y hacer `toque`.
	bool persigue = false;
	int paso_meta = -1;
	int toque = TOQUE_NADA;
	// El gesto que arrancó para tocarla y si su ventana todavía la puede tocar.
	int clip_toque = -1;
	int parte = PIE;
	bool toque_pendiente = false;
	// Pase: al punto (meta_x, meta_z), a `receptor`, raso o globo.
	double meta_x = 0.0, meta_z = 0.0;
	int receptor = -1;
	bool globo = false;
	// Conduce y control: hacia dónde sale la pelota y a qué rapidez.
	double dir_x = 1.0, dir_z = 0.0;
	double rapidez_toque = 0.0;
	// No rebota contra el que la acaba de tocar.
	int64_t inmune_hasta = 0;
	int64_t pateo_en = -1000;
	bool pensar_ya = false;
	// Lo que el equipo le pide cuando no va a la pelota.
	int marca = -1;
	// Su lugar en el modo PRUEBA.
	double casa_x = 0.0, casa_z = 0.0;
	double quieto_seg = 0.0;
	double rapidez_previa = 0.0;
	// PARTIDO: lo que decidió el cerebro y hasta qué paso vale.
	Decision decision;
	bool hay_decision = false;
	int64_t decision_hasta = 0;
	// Rapidez planeada del pase (al espacio); 0 = la calcula el toque.
	double rapidez_pase = 0.0;
	// La decisión del cerebro que armó el pase de este toque (DEC_NADA si no
	// salió del cerebro).
	int tipo_pase = DEC_NADA;
	// Remate: al punto (meta_x, meta_alto, meta_z) con el golpe `golpe_remate`.
	double meta_alto = 0.0;
	int golpe_remate = REMATE_COLOCADO;
	// Atajada: el clip del arquero (ClipArquero de remate.h).
	int clip_arquero = -1;
	// Modo ARCO: le pega al arco la próxima pelota (rematar()).
	bool remata_prueba = false;
};

class Canchita : public Planeador {
public:
	static constexpr double PASO_SEG = 1.0 / 60.0;
	// Cuánto adelanta la pelota el que planea: 5 s.
	static constexpr int HORIZONTE = 300;
	// Cerebro a 10 Hz, escalonado: cada jugador piensa uno de cada 6 pasos.
	static constexpr int PASOS_POR_TURNO = 6;
	static constexpr double RONDO_LADO = 12.0;
	static constexpr double PARTIDITO_LARGO = 40.0;
	static constexpr double PARTIDITO_ANCHO = 30.0;
	static constexpr double RAPIDEZ_QUIETO = 0.5;
	// Partido: la cancha entera (la misma del motor espacial).
	static constexpr double PARTIDO_LARGO = Cerebro::LARGO;
	static constexpr double PARTIDO_ANCHO = Cerebro::ANCHO;

	ParametrosPelota param_pelota;
	ParametrosCuerpo param_cuerpo;
	ParametrosToque param_toque;
	ParametrosRemate param_remate;
	ParametrosArquero param_arquero;
	std::vector<Clip> clips;

	std::vector<JugadorCanchita> jugadores;
	// PARTIDO: una ficha por jugador, en el mismo orden (ver cerebro.fichas).
	Cerebro cerebro;
	Pelota pelota;
	Trayectoria trayectoria;
	ContadoresCanchita cuenta;
	// Etapa 5: cada remate del partido.
	std::vector<RegistroRemate> registro;
	int modo = RONDO;
	int64_t paso = 0;
	int equipo_con_pelota = 0;
	int poseedor = -1;
	int ultimo_toque = -1;
	int ultimo_tipo = TOQUE_NADA;

	// Antes de empezar: los jugadores, con su físico ya pasado a unidades.
	void agregar(int equipo, const Cuerpo &fisico, double pases, double control);
	void empezar(int modo_, int64_t semilla);
	// Modo PRUEBA: dónde está cada uno, y una pelota que sale de `p` a `v` con
	// `giro` para que la juegue el equipo `equipo` (la ven todos enseguida).
	void poner_jugador(int i, double x, double z, double rumbo);
	void lanzar(V3 p, V3 v, V3 giro, int equipo);
	// Modo PRUEBA: el jugador `i` le va a pegar al arco a la pelota que viene
	// (la próxima que se lance), al punto (alto, lateral) con el golpe `golpe`.
	void rematar(int i, int golpe, double alto, double lateral);
	// El arquero de `equipo` (-1 si no tiene).
	int arquero_de(int equipo) const;
	// El que tiene la pelota en las manos (-1 si nadie).
	int en_manos() const {
		return _en_manos;
	}
	// El resultado del último remate que terminó (ResultadoRemate), -1 si no hubo.
	int ultimo_resultado() const {
		return _ultimo_resultado;
	}
	void avanzar();
	uint64_t huella() const;

	// Planeador (cerebro.h): el margen de un pase con la física del toque,
	// desde la pelota y el momento de la patada del que está decidiendo.
	double margen_pase(int de, int a) override;
	double margen_al_punto(int de, int a, double x, double z) override;
	double margen_globo(int de, double x, double z) override;
	double valor_remate(int de, int tipo, double alto, double lateral) override;
	// El receptor del pase que viaja (-1 si no hay pase).
	int receptor() const {
		return _pase_activo ? _receptor : -1;
	}
	// La foto que lee el cerebro (se arma en cada paso del PARTIDO).
	const Mundo &mundo() const {
		return _mundo;
	}

private:
	Azar _azar;
	Perfiles _perfiles;
	// Paso en que se calculó la trayectoria (la pelota cambió).
	int64_t _tray_paso = 0;
	// Desde qué paso los demás ya vieron la pelota nueva (reacción).
	int64_t _visto_paso = 0;
	int _reaccion_pasos = 12;
	std::vector<int> _k_llega;
	std::vector<double> _t_llega;
	int _perseguidor[2] = { -1, -1 };
	bool _pase_activo = false;
	int _pateador = -1;
	int _receptor = -1;
	int64_t _desde_control = 0;
	int64_t _reinicio_en = -1;
	int64_t _reinicio_hasta = -1;
	bool _cambio = false;
	// PARTIDO.
	Mundo _mundo;
	int _pases_posesion = 0;
	bool _pase_al_espacio = false;
	// Desde dónde y en cuántos segundos patea el que decide (Planeador).
	V3 _plan_bola;
	// Etapa 5.
	// Dónde cruza la trayectoria la línea de cada arco (índice en la
	// trayectoria, -1 si no va al arco). _k_cruce[e] es el arco que defiende e.
	int _k_cruce[2] = { -1, -1 };
	int _en_manos = -1;
	int64_t _suelta_en = -1;
	// Saque del medio después de un gol: cuándo y quién.
	int64_t _saque_medio_en = -1;
	int _saca_medio = 0;
	bool _llegada_contada = false;
	int _ultimo_resultado = -1;
	// El rebote del arquero, para contar el remate que sale de ahí.
	int64_t _rebote_arquero_en = -1000;
	struct Remate {
		bool activo = false;
		int equipo = 0;
		int pateador = -1;
		int64_t paso = 0;
		bool palo = false;
		bool toco_arquero = false;
		bool cabeza = false;
		bool tras_rebote = false;
		// Su lugar en `registro`.
		size_t indice = 0;
	};
	Remate _remate;

	double _plan_t = 0.0;

	double _medio_x() const;
	double _medio_z() const;
	bool _adentro(double x, double z, double margen) const;
	double _ataca(int equipo) const;
	V3 _bola_en(int64_t paso_) const;
	int _indice_tray(int64_t paso_) const;

	void _pensar();
	void _analizar();
	void _alcance(int i, double factor, int &k, double &t) const;
	void _pensar_jugador(int i);
	void _plan_tocar(int i);
	void _decidir(int i, V3 bola, double t_patada);
	void _ubicar(int i);
	void _contener(int i);
	void _avisar_receptor(int pateador);
	void _gatillo(int i);
	int _clip_para(const JugadorCanchita &j, double alto) const;
	int _clip_de_parte(const JugadorCanchita &j, Parte parte) const;
	void _franja(Parte parte, double &desde, double &hasta) const;
	double _rumbo_al_tocar(const Cuerpo &c, double rumbo, double x, double z) const;
	void _orientar(int i, V3 bola);

	struct Pase {
		bool hay = false;
		int receptor = -1;
		double x = 0.0, z = 0.0;
		bool globo = false;
		double margen = -1e9;
		double puntaje = -1e9;
		// Rapidez planeada (pase al espacio); 0 = la del toque.
		double rapidez = 0.0;
	};
	// `solo`: solo a ese receptor (el que eligió el cerebro).
	Pase _planear_pase(int i, V3 bola, double t_patada, int solo = -1);
	double _margen(int i, V3 bola, double dx, double dz, const Perfil &perfil, int k_fin, double t_patada) const;
	double _rapidez_raso(double d, int &k);
	double _rapidez_globo(double d, int &k);
	double _rapidez_conduce(double corre, double largo);
	double _rival_mas_cerca(int i, double x, double z) const;
	double _claridad(V3 bola, double x, double z, int equipo) const;

	bool _resolver_toques();
	void _tocar(int i, double distancia);
	bool _rebotes();
	void _reglas();
	void _reiniciar(int equipo, double x, double z);
	void _asignar_marcas();
	void _separar_cuerpos();
	void _medir();

	// PARTIDO.
	void _armar_mundo();
	void _ubicar_partido(int i, double &qx, double &qz, double &factor, bool &frenar);
	void _decidir_partido(int i, V3 bola, double t_patada);
	Pase _pase_a(int i, V3 bola, double t_patada, const Decision &d);
	double _rapidez_al_espacio(double d, double t_receptor, double t_patada);
	bool _reglas_partido();
	void _cerrar_posesion();

	// Etapa 5.
	void _nueva_trayectoria();
	void _buscar_cruces();
	bool _es_mi_area(int i, double x, double z) const;
	double _reaccion_arquero(int i) const;
	double _tolerancia(int i, int clip) const;
	double _tolerancia_alto(int clip, bool arriba) const;
	bool _es_estirada(int clip_arquero) const;
	double _alto_minimo(int clip_arquero, const Clip &k) const;
	double _distancia_al_brazo(const JugadorCanchita &j, const Cuerpo &c, V3 mano, V3 a, V3 b) const;
	// De su punta, lo que corre para acomodarse sin darse vuelta.
	double _factor_acomodarse(const Cuerpo &c) const;
	double _rumbo_contacto(const JugadorCanchita &j, const Cuerpo &c, int clip, double rumbo, double x, double z) const;
	bool _plan_atajar(int i);
	bool _prueba() const {
		return modo == PRUEBA || modo == ARCO;
	}
	bool _con_arcos() const {
		return modo == PARTIDO || modo == ARCO;
	}
	void _ubicar_arquero(int i, double &qx, double &qz, double &factor);
	void _atajar(int i, double distancia);
	void _llevar_en_manos();
	void _soltar();
	bool _decidir_remate_de_primera(int i, V3 bola, double t);
	double _rapidez_remate(const JugadorCanchita &j, int golpe) const;
	double _error_remate(const JugadorCanchita &j, int golpe, double de_lado, double alto_pelota, double llega_ms,
			double apretado, double cruce_pie_malo) const;
	void _patear_al_arco(int i, bool de_primera, double apretado);
	void _cerrar_remate(int resultado);
	void _gol(int marca);
	void _sacar_del_medio();
};

} // namespace motor_v2
