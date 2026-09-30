#pragma once

// Cuerpos del Motor V2 sueltos, sin pelota ni cerebro, para el banco y los
// tests de la etapa 2 (docs/motor_v2.md). Son los mismos motor_v2::Cuerpo
// que mueve MundoV2Nativo.

#include "cuerpo.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <vector>

namespace godot {

// Pasa lo que armó FisicaV2.parametros_cuerpo() al cuerpo. Las claves que
// falten quedan con el valor de ParametrosCuerpo.
void leer_parametros_cuerpo(const Dictionary &d, motor_v2::ParametrosCuerpo &p);
// Los clips de data/acciones_v2.json ("clips"): nombres en `nombres`, en el
// mismo orden que `clips`.
void leer_clips(const Dictionary &d, std::vector<motor_v2::Clip> &clips, std::vector<String> &nombres);

class CuerposV2Nativos : public RefCounted {
	GDCLASS(CuerposV2Nativos, RefCounted)

public:
	void configurar(const Dictionary &parametros, const Dictionary &clips);
	// `fisico`: vel_max (m/s), aceleracion (m/s²), giro (rad/s), cansancio (0..1).
	int64_t agregar(const Vector2 &pos, double rumbo, const Dictionary &fisico);
	void ir_a(int64_t i, const Vector2 &punto, double factor, bool frenar);
	void parar(int64_t i);
	void mirar_a(int64_t i, const Vector2 &punto);
	void poner_reserva(int64_t i, double reserva);
	void poner_cansancio(int64_t i, double cansancio);
	bool empezar_accion(int64_t i, const String &nombre);
	void avanzar();

	int64_t cantidad() const;
	PackedVector2Array get_pos() const;
	PackedVector2Array get_pos_previa() const;
	PackedFloat32Array get_rumbo() const;
	PackedFloat32Array get_rapidez() const;
	Vector2 get_vel(int64_t i) const;
	double get_reserva(int64_t i) const;
	double get_rapidez_buscada(int64_t i) const;
	double get_metros_para_parar(int64_t i) const;
	double get_giro_pendiente(int64_t i) const;
	double get_rumbo_buscado(int64_t i) const;
	String get_accion(int64_t i) const;
	int64_t get_fase(int64_t i) const;
	double get_tiempo_accion(int64_t i) const;
	int64_t get_eventos(int64_t i) const;
	double duracion(const String &nombre) const;
	int64_t huella() const;

protected:
	static void _bind_methods();

private:
	motor_v2::ParametrosCuerpo _param;
	std::vector<motor_v2::Clip> _clips;
	std::vector<String> _nombres;
	std::vector<motor_v2::Cuerpo> _cuerpos;

	int _indice(const String &nombre) const;
	bool _valido(int64_t i) const;
};

} // namespace godot
