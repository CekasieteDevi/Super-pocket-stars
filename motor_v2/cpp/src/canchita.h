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
// Sin Godot: solo C++ y matematica_fija.h.

#include "azar.h"
#include "cuerpo.h"
#include "pelota.h"
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
};

enum TipoToque : int {
	TOQUE_NADA = 0,
	TOQUE_PASE = 1,
	TOQUE_CONDUCE = 2,
	TOQUE_CONTROL = 3,
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
};

struct JugadorCanchita {
	Cuerpo cuerpo;
	int equipo = 0;
	// Lugar dentro del equipo (0..4): el lado del rondo o el ancla del partidito.
	int puesto = 0;
	// Atributos de Player (0..100).
	double pases = 50.0;
	double control = 50.0;

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
};

class Canchita {
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

	ParametrosPelota param_pelota;
	ParametrosCuerpo param_cuerpo;
	ParametrosToque param_toque;
	std::vector<Clip> clips;

	std::vector<JugadorCanchita> jugadores;
	Pelota pelota;
	Trayectoria trayectoria;
	ContadoresCanchita cuenta;
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
	void avanzar();
	uint64_t huella() const;
	// El receptor del pase que viaja (-1 si no hay pase).
	int receptor() const {
		return _pase_activo ? _receptor : -1;
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
	};
	Pase _planear_pase(int i, V3 bola, double t_patada);
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
};

} // namespace motor_v2
