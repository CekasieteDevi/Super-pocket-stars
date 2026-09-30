#pragma once

// El cuerpo del Motor V2 (docs/motor_v2.md, etapa 2): cómo se mueve un
// jugador (locomoción) y cómo hace un gesto (acción con preparación, ventana
// de contacto y recuperación). El cerebro pide ("andá a P", "pateá"); el
// cuerpo lo hace con las restricciones de su físico y de su animación.
//
// La locomoción es la de MotorEspacial._mover_hacia (core/motor_espacial.gd)
// pasada a 60 Hz: rampa de aceleración con arranque, frenada, techo por
// reserva de sprint y un tope al cambio de la velocidad (giro con inercia).
// Ejes como la pelota: x a lo largo, z a lo ancho. El rumbo es el ángulo
// hacia donde mira, medido desde +z hacia +x (adelante = (sen, cos)), el
// mismo que usa la vista para rotation.y.
//
// Sin Godot: solo C++ y matematica_fija.h.

#include <cstdint>
#include <vector>

namespace motor_v2 {

// Salen de data/utility_pesos.json (fisica, control y esfuerzo: los mismos
// números del motor actual) y de data/fisica_v2.json (cuerpo). FisicaV2 los
// junta y se los pasa al motor. Los valores de acá son los de esos JSON, para
// quien crea el cuerpo sin configurarlo; tests/test_cuerpo_v2.gd falla si se
// separan.
struct ParametrosCuerpo {
	double frenada = 6.0;
	double giro_acel = 12.0;
	double arranque_extra = 0.8;
	double rapidez_para_girar = 2.0;
	double peso_aceleracion = 0.5;
	double umbral_sprint = 0.55;
	double consumo_sprint = 0.06;
	double recuperacion_reserva = 0.07;
	double reserva_para_frenar = 0.5;
	double piso_sprint = 0.85;
	double ventana_contacto_seg = 0.1;
};

// Un clip de data/acciones_v2.json, lo que el cuerpo necesita de él.
struct Clip {
	double duracion = 0.0;
	// Segundo del contacto dentro del clip; negativo si no toca la pelota.
	double contacto_seg = -1.0;
	// Sigue con su locomoción mientras dura (patear corriendo).
	bool mueve = false;
	// Dónde toca la pelota en el cuadro de contacto (punto_contacto de
	// data/acciones_v2.json), en metros desde el pie del jugador: x a su
	// izquierda, y arriba, z adelante. La etapa 3 lo usa para saber si llega.
	double punto_x = 0.0, punto_y = 0.0, punto_z = 0.0;
};

enum FaseAccion : int {
	SIN_ACCION = 0,
	PREPARACION = 1,
	CONTACTO = 2,
	RECUPERACION = 3,
};

enum EventoCuerpo : uint32_t {
	ABRE_CONTACTO = 1u << 0,
	CIERRA_CONTACTO = 1u << 1,
	TERMINA_ACCION = 1u << 2,
	LLEGO = 1u << 3,
};

struct Cuerpo {
	// Físico, ya pasado a unidades por GDScript desde los atributos
	// (MotorEspacial._vel_max, _aceleracion y _giro_de).
	double vel_max = 7.5;
	double aceleracion = 3.8;
	// Giro del cuerpo parado o trotando, rad/s (agilidad).
	double giro = 6.5;
	// Factor de energía del partido (Cansancio): baja punta y aceleración.
	double cansancio = 1.0;

	double x = 0.0, z = 0.0;
	double previa_x = 0.0, previa_z = 0.0;
	double vx = 0.0, vz = 0.0;
	double rumbo = 0.0;
	// Reserva de sprint (0..1), como MotorEspacial.actualizar_reserva.
	double reserva = 1.0;
	double recorrido = 0.0;

	bool tiene_objetivo = false;
	double objetivo_x = 0.0, objetivo_z = 0.0;
	double factor = 1.0;
	bool frenar = false;
	bool mira = false;
	double mira_x = 0.0, mira_z = 0.0;

	int clip = -1;
	double tiempo_accion = 0.0;
	FaseAccion fase = SIN_ACCION;
	uint32_t eventos = 0;

	double rapidez() const;
	// Lo más que puede bajar la rapidez en un paso (llegando frenado a un
	// punto): más que eso es frenar en seco.
	static double caida_maxima(const ParametrosCuerpo &p, double dt);
	void ir_a(double px, double pz, double factor_ = 1.0, bool frenar_ = false);
	// Arranca un gesto. No se puede empezar otro hasta que termina: devuelve
	// false y no cambia nada.
	bool empezar(int indice_clip);
	void paso(const ParametrosCuerpo &p, const std::vector<Clip> &clips, double dt);

	// Lo que el cuerpo busca hacer, para que la vista elija el clip (Arranque,
	// Frenada, giros) sin adivinarlo. Solo lectura: no cambia nada.
	// La rapidez a la que va el objetivo (sin la frenada del final); 0 sin objetivo.
	double rapidez_buscada(const ParametrosCuerpo &p) const;
	// Metros hasta quedar parado: al objetivo si llega frenando, lo que tarda
	// en frenar si no tiene objetivo; -1 si pasa el objetivo sin frenar.
	double metros_para_parar(const ParametrosCuerpo &p) const;
	// Radianes que le faltan girar (+ = hacia su izquierda).
	double giro_pendiente(const ParametrosCuerpo &p) const;
	// Hacia dónde queda el objetivo (como el rumbo); sin objetivo, el rumbo.
	double rumbo_buscado() const;

private:
	double _capacidad_de_sprint(const ParametrosCuerpo &p) const;
	double _hacia(const ParametrosCuerpo &p) const;
	void _moverse(const ParametrosCuerpo &p, bool quieto, double dt);
	void _girar(const ParametrosCuerpo &p, bool trabado, double dt);
	void _gastar(const ParametrosCuerpo &p, double rapidez_previa, double dt);
	void _avanzar_accion(const ParametrosCuerpo &p, const std::vector<Clip> &clips, double dt);
};

} // namespace motor_v2
