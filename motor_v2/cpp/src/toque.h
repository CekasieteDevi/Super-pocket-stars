#pragma once

// Tocar la pelota (docs/motor_v2.md, etapa 3): lo que necesitan el que
// patea, el que recibe y el que corta para saber dónde y cuándo va a estar la
// pelota, y el mundo para saber si un pie llegó.
//
// Nadie dirige la pelota: el cerebro planea con la misma física que la mueve
// (una copia de la pelota que se adelanta), el cuerpo arranca el gesto a
// tiempo y el mundo decide quién la toca en la ventana de contacto.
//
// Sin Godot: solo C++ y matematica_fija.h.

#include "cuerpo.h"
#include "pelota.h"

#include <vector>

namespace motor_v2 {

// Salen de data/fisica_v2.json ("toque"; ahí está el porqué de cada uno).
// FisicaV2.parametros_toque() se los pasa al motor. Los valores de acá son los
// del JSON; tests/test_toque_v2.gd falla si se separan.
struct ParametrosToque {
	double tolerancia_m = 0.3;
	double tolerancia_alto_m = 0.25;
	double gatillo_m = 0.2;
	double radio_piernas = 0.2;
	double alto_cuerpo = 1.25;
	double restitucion_cuerpo = 0.3;
	double reaccion_seg = 0.2;
	double pie_hasta = 0.32;
	double muslo_hasta = 0.55;
	double pecho_hasta = 0.85;
	double cabeza_hasta = 1.8;
	double llegada_pase_ms = 7.0;
	double pase_min_ms = 4.0;
	double pase_max_ms = 26.0;
	double elevacion_globo = 0.6;
	double error_pase_rad = 0.1;
	double error_pase_rapidez = 0.12;
	double presion_m = 3.0;
	double control_ms = 1.5;
	double error_control_rad = 0.4;
	double error_control_ms = 1.5;
	double toque_largo_m = 1.4;
	double toque_corto_m = 0.8;
	double conduccion_factor = 0.75;
	double sin_rebote_seg = 0.3;
	double margen_seguro_seg = 0.25;
	double giro_alcance_rad = 1.0;
	// Clips (índices en los clips del cuerpo); los pone quien configura.
	int clip_pase = -1;
	int clip_conduce = -1;
	int clip_recepcion[4] = { -1, -1, -1, -1 };
};

// Con qué parte recibe, según la altura del centro de la pelota.
enum Parte : int {
	PIE = 0,
	MUSLO = 1,
	PECHO = 2,
	CABEZA = 3,
	NINGUNA = 4,
};

Parte parte_para(const ParametrosToque &p, double alto);

// Dónde queda el punto de contacto del clip si el cuerpo mira a `rumbo`.
V3 punto_de_contacto(const Cuerpo &c, const Clip &k, double rumbo);

// Distancia en el piso del punto `q` al tramo a-b.
double distancia_al_tramo(double qx, double qz, V3 a, V3 b);

// Segundos que tarda el cuerpo en quedar a `alcance` del punto: acelera desde
// lo que ya corre hacia allá hasta su punta (con `factor` de la punta).
// Cuenta cerrada, sin giros: la usan todos los que planean.
double tiempo_de_llegada(const Cuerpo &c, double x, double z, double alcance, double factor = 1.0);

// Lo que va a hacer la pelota si nadie la toca: la misma pelota adelantada
// paso por paso. `pos[k]` es dónde está después de k + 1 pasos. Es exacta
// (viento y efecto incluidos) mientras nadie la toque.
struct Trayectoria {
	std::vector<V3> pos;
	std::vector<V3> vel;
	void predecir(const Pelota &p, int pasos);
};

// Pelotas de referencia para planear un pase: salen de (0, radio, 0) hacia +x
// a una rapidez y elevación, sin viento. `dist`, `alto` y `rapidez` después de
// k + 1 pasos. El pase planeado apunta con esto; el que patea no sabe del
// viento, así que el viento es parte del error.
struct Perfil {
	std::vector<double> dist;
	std::vector<double> alto;
	std::vector<double> rapidez;
	// Primer paso en que la dist llega a `d`; -1 si nunca.
	int paso_a(double d) const;
};

class Perfiles {
public:
	static constexpr double PASO_RAPIDEZ = 0.5;

	void configurar(const ParametrosPelota &p, double elevacion_globo, int pasos);
	// El perfil de la rapidez más cercana de la grilla (de a PASO_RAPIDEZ).
	const Perfil &de(double rapidez, bool globo);
	static double rapidez_de(int indice);

private:
	ParametrosPelota _param;
	double _elevacion_globo = 0.6;
	int _pasos = 0;
	std::vector<Perfil> _raso;
	std::vector<Perfil> _globo;
	std::vector<bool> _hecho_raso;
	std::vector<bool> _hecho_globo;
	void _armar(Perfil &perfil, double rapidez, double elevacion);
};

} // namespace motor_v2
