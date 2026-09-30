#pragma once

// La pelota del Motor V2 (docs/motor_v2.md, etapa 1): un cuerpo con
// posición, velocidad y giro en 3D, que vuela, pica, rueda y choca contra los
// palos, el travesaño y la red con física propia. Nadie la dirige: se la
// patea (poner velocidad y giro) y el resultado sale de acá.
//
// Ejes como en MundoV2Nativo: x a lo largo de la cancha (los arcos en
// x = ±medio_largo), y hacia arriba, z a lo ancho. Todo en metros, segundos
// y radianes. Sin Godot: solo C++ y matematica_fija.h, así los tests del
// motor y la vista leen la misma pelota.

#include <cstdint>

namespace motor_v2 {

struct V3 {
	double x = 0.0, y = 0.0, z = 0.0;
};

// Los números salen de data/fisica_v2.json (ahí está el porqué de cada uno);
// FisicaV2 (motor_v2/fisica_v2.gd) les aplica el césped y el clima y se los
// pasa al motor. Los valores de acá son los del JSON sin modificar, para
// quien crea la pelota sin configurarla (el banco de la etapa 0).
struct ParametrosPelota {
	double gravedad = 9.81;
	double radio = 0.11;
	double masa = 0.43;
	double densidad_aire = 1.2;
	double cd_lenta = 0.45;
	double cd_rapida = 0.25;
	double crisis_desde = 10.0;
	double crisis_hasta = 14.0;
	double cl_por_giro = 1.0;
	double cl_tope = 0.35;
	double giro_decae_aire = 0.12;
	double restitucion_piso = 0.55;
	double rozamiento_pique = 0.45;
	double vertical_rueda = 1.8;
	double rozamiento_deslizar = 0.4;
	double frenado_rodando = 1.1;
	double giro_vertical_decae_piso = 2.5;
	double quieta = 0.03;
	double medio_largo = 52.5;
	double arco_medio_ancho = 3.66;
	double arco_alto = 2.44;
	double radio_palo = 0.06;
	double restitucion_palo = 0.7;
	double rozamiento_palo = 0.1;
	double profundidad_red = 2.0;
	double restitucion_red = 0.12;
	double rozamiento_red = 0.5;
	double subpaso_max_m = 0.05;
	V3 viento;
};

// Lo que pasó en un paso, para reglas, registro y sonido.
enum EventoPelota : uint32_t {
	PIQUE = 1u << 0,
	PALO = 1u << 1,
	TRAVESANO = 1u << 2,
	RED = 1u << 3,
	EMPIEZA_A_RODAR = 1u << 4,
	SE_DETIENE = 1u << 5,
};

class Pelota {
public:
	static constexpr double PASO_SEG = 1.0 / 60.0;

	ParametrosPelota param;

	V3 pos;
	V3 previa;
	V3 vel;
	// Vector de giro (rad/s): la dirección es el eje y el largo la rapidez.
	V3 giro;
	bool en_piso = false;

	int64_t piques = 0;
	int64_t palos = 0;
	int64_t travesanos = 0;
	int64_t redes = 0;
	// Detector SALTO_PELOTA (docs/motor_v2.md): pasos en que la pelota se
	// movió más que lo que recorrió a su velocidad. Tiene que dar 0 siempre.
	int64_t saltos = 0;
	double peor_exceso_m = 0.0;

	void configurar(const ParametrosPelota &p);
	// Poner la pelota (reanudación o patada). Si queda apoyada y sin velocidad
	// hacia arriba, empieza rodando.
	void poner(V3 p, V3 v, V3 w);
	// Un paso de 1/60 s. Devuelve los EventoPelota que ocurrieron.
	uint32_t avanzar();

private:
	double _k_aire = 0.0;
	double _k_inercia = 2.0 / 3.0;
	uint32_t _eventos = 0;
	double _recorrido = 0.0;

	void _subpaso(double dt);
	void _fuerzas_aire(double dt);
	void _rozamiento_piso(double dt);
	void _mover_con_choques(double dt);
	void _pique();
	void _chocar(V3 n, double restitucion, double rozamiento);
	void _sincronizar_rodada();
};

} // namespace motor_v2
