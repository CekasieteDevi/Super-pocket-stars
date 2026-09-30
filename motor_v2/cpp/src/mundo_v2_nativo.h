#pragma once

// El mundo de la etapa 0 del Motor V2 (docs/motor_v2.md) en C++: la misma
// física que motor_v2/mundo.gd y el mismo cerebro falso que
// motor_v2/cerebro_falso.gd, para medir cuánto baja el costo contra GDScript.
// El estado va en double: la vista lo lee pasado a float. Desde la etapa 1 la
// pelota es motor_v2::Pelota (pelota.h), la misma del laboratorio.

#include "cuerpo.h"
#include "pelota.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>

namespace godot {

class MundoV2Nativo : public RefCounted {
	GDCLASS(MundoV2Nativo, RefCounted)

public:
	static constexpr int JUGADORES = 22;

	// Los parámetros de la pelota (FisicaV2.parametros()); antes de iniciar.
	void configurar_pelota(const Dictionary &parametros);
	// Los parámetros del cuerpo (FisicaV2.parametros_cuerpo()); antes de iniciar.
	void configurar_cuerpos(const Dictionary &parametros);
	void iniciar(int64_t semilla);
	// Un paso de 1/60 s: el cerebro falso y después el mundo.
	void avanzar();
	// `pasos` pasos seguidos; devuelve los segundos que tardó.
	double simular(int64_t pasos);

	PackedVector2Array get_pos() const;
	PackedVector2Array get_pos_previa() const;
	PackedFloat32Array get_rumbo() const;
	PackedFloat32Array get_rapidez() const;
	Vector3 get_pelota_pos() const;
	Vector3 get_pelota_previa() const;
	Dictionary contadores() const;
	int64_t huella() const;

protected:
	static void _bind_methods();

private:
	struct V2 {
		double x = 0.0, y = 0.0;
	};

	// PCG32: el mismo generador en PC y Android, sin pasar por el motor.
	uint64_t _estado_rng = 0;
	uint32_t _rng();
	double _al_azar(double desde, double hasta);

	V2 _pos[JUGADORES];
	V2 _pos_previa[JUGADORES];
	double _rumbo[JUGADORES] = {};
	double _rapidez[JUGADORES] = {};
	V2 _objetivo[JUGADORES];
	double _velocidad_max[JUGADORES] = {};
	double _masa[JUGADORES] = {};

	motor_v2::ParametrosCuerpo _param_cuerpo;
	motor_v2::Cuerpo _cuerpos[JUGADORES];
	motor_v2::ParametrosPelota _param_pelota;
	motor_v2::Pelota _pelota;
	int64_t _paso = 0;

	// Cerebro falso.
	int _perseguidor[2] = { 1, 12 };
	int64_t _puede_patear[JUGADORES] = {};

	int64_t _choques_cuerpos = 0, _choques_pelota = 0;
	int64_t _patadas = 0, _goles = 0, _salidas = 0;

	void _pensar();
	void _elegir_perseguidores(V2 pelota);
	void _intentar_patear(int i);
	void _reglas();
	void _poner_pelota(double x, double z);
	V2 _puesto(int i) const;

	void _mover_cuerpos();
	void _separar_cuerpos();
	void _mover_pelota();
	void _chocar_cuerpos();
};

} // namespace godot
