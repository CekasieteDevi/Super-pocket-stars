#pragma once

// La canchita de la etapa 3 (canchita.h) para el laboratorio del toque y los
// tests (docs/motor_v2.md). GDScript solo configura, avanza y lee.

#include "canchita.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

namespace godot {

// Pasa lo que armó FisicaV2.parametros_toque() (data/fisica_v2.json, "toque").
// Los nombres de los clips se buscan en `nombres` (los de leer_clips).
void leer_parametros_toque(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosToque &p);

class CanchitaV2Nativa : public RefCounted {
	GDCLASS(CanchitaV2Nativa, RefCounted)

public:

	// FisicaV2.parametros(), parametros_cuerpo(), clips() y parametros_toque().
	void configurar(const Dictionary &pelota, const Dictionary &cuerpo, const Dictionary &clips, const Dictionary &toque);
	// `fisico`: el de FisicaV2.fisico_de más "pases" y "control" (0..100).
	int64_t agregar(int64_t equipo, const Dictionary &fisico);
	void empezar(int64_t modo, int64_t semilla);
	// Etapa 4 (PARTIDO): los pesos del cerebro (MotorEspacial.pesos() y la
	// sección "cerebro" de data/fisica_v2.json) y el plan de cada club. La
	// ficha de cada jugador va en `agregar` (ver motor_v2/cerebro_v2.gd).
	void configurar_cerebro(const Dictionary &utility, const Dictionary &nuevos);
	void configurar_plan(int64_t equipo, const Dictionary &plan);
	// Los pesos de fábrica del cerebro, como los JSON (para el test).
	Dictionary pesos_cerebro_de_fabrica() const;
	// La matemática propia (matematica_fija.h), para el test.
	static double exponencial(double x);
	static double logaritmo(double x);
	// Modo PRUEBA (tests): dónde está cada uno y la pelota que se lanza.
	void poner_jugador(int64_t i, const Vector2 &pos, double rumbo);
	void lanzar(const Vector3 &pos, const Vector3 &vel, const Vector3 &giro, int64_t equipo);
	void avanzar();
	// `pasos` pasos seguidos; devuelve los segundos que tardó.
	double simular(int64_t pasos);

	int64_t cantidad() const;
	PackedVector2Array get_pos() const;
	PackedVector2Array get_pos_previa() const;
	PackedFloat32Array get_rumbo() const;
	PackedFloat32Array get_rapidez() const;
	PackedInt32Array get_equipos() const;
	String get_accion(int64_t i) const;
	int64_t get_fase(int64_t i) const;
	double get_tiempo_accion(int64_t i) const;
	double get_rapidez_buscada(int64_t i) const;
	double get_metros_para_parar(int64_t i) const;
	double get_giro_pendiente(int64_t i) const;
	double get_rumbo_buscado(int64_t i) const;
	int64_t get_poseedor() const;
	int64_t get_equipo_con_pelota() const;
	int64_t get_ultimo_toque() const;
	int64_t get_receptor() const;
	Vector3 get_pelota_pos() const;
	Vector3 get_pelota_previa() const;
	Vector3 get_pelota_vel() const;
	Vector3 get_pelota_giro() const;
	// Lo que va a hacer la pelota si nadie la toca (lo que planean todos).
	PackedVector3Array prediccion() const;
	Dictionary contadores() const;
	// PARTIDO: lo que pensó el cerebro.
	Dictionary contadores_cerebro() const;
	// Papel en la defensa de cada uno (cerebro.h, PapelDefensa).
	PackedInt32Array get_papeles() const;
	// Adónde va cada uno que no tiene la pelota (el objetivo del cerebro).
	PackedVector2Array get_objetivos() const;
	// Destino del desmarque de cada uno, o (NAN, NAN) si no tiene.
	PackedVector2Array get_desmarques() const;
	PackedInt32Array get_roles() const;
	// Línea de offside y línea defensiva de cada equipo: (offside0, offside1,
	// defensiva0, defensiva1).
	PackedFloat32Array get_lineas() const;
	int64_t get_fase_ritmo() const;
	// La última decisión del cerebro: {decisor, temperatura, opciones: [{tipo,
	// receptor, punto, utilidad}]}.
	Dictionary ultima_decision() const;
	int64_t huella() const;

protected:
	static void _bind_methods();

private:
	motor_v2::Canchita _c;
	std::vector<String> _nombres;

	bool _valido(int64_t i) const;
};

} // namespace godot
