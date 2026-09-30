#pragma once

// La pelota del Motor V2 sola, para el laboratorio y los tests de la etapa 1
// (docs/motor_v2.md). Es la misma motor_v2::Pelota que usa MundoV2Nativo.

#include "pelota.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

// Pasa lo que armó FisicaV2.parametros() (data/fisica_v2.json con césped y
// clima) a la pelota. Las claves que falten quedan con el valor de
// ParametrosPelota.
void leer_parametros_pelota(const Dictionary &d, motor_v2::ParametrosPelota &p);

class PelotaV2Nativa : public RefCounted {
	GDCLASS(PelotaV2Nativa, RefCounted)

public:
	// Parámetros de FisicaV2.parametros(); pone los contadores en cero.
	void configurar(const Dictionary &parametros);
	void poner(const Vector3 &pos, const Vector3 &vel, const Vector3 &giro);
	// Un paso de 1/60 s; devuelve los eventos (EventoPelota) del paso.
	int64_t avanzar();
	void simular(int64_t pasos);

	Vector3 get_pos() const;
	Vector3 get_previa() const;
	Vector3 get_vel() const;
	Vector3 get_giro() const;
	bool get_en_piso() const;
	Dictionary contadores() const;
	int64_t huella() const;

protected:
	static void _bind_methods();

private:
	motor_v2::Pelota _pelota;
};

} // namespace godot
