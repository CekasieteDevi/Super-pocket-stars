#pragma once

// La canchita de la etapa 3 (canchita.h) para el laboratorio del toque y los
// tests (docs/motor_v2.md). GDScript solo configura, avanza y lee.

#include "canchita.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
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
// Etapa 5: FisicaV2.parametros_remate() y parametros_arquero().
void leer_parametros_remate(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosRemate &p);
void leer_parametros_arquero(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosArquero &p);
// Etapa 6: FisicaV2.parametros_reglas().
void leer_parametros_reglas(const Dictionary &d, const std::vector<String> &nombres, motor_v2::ParametrosReglas &p);

class CanchitaV2Nativa : public RefCounted {
	GDCLASS(CanchitaV2Nativa, RefCounted)

public:

	// FisicaV2.parametros(), parametros_cuerpo(), clips() y parametros_toque().
	void configurar(const Dictionary &pelota, const Dictionary &cuerpo, const Dictionary &clips, const Dictionary &toque);
	// Etapa 5: FisicaV2.parametros_remate() y parametros_arquero().
	void configurar_remate(const Dictionary &remate, const Dictionary &arquero);
	// Los de fábrica del remate y del arquero, como los JSON (para el test).
	Dictionary remate_de_fabrica() const;
	// `fisico`: el de FisicaV2.fisico_de más "pases" y "control" (0..100). Etapa
	// 5: tiro, golpe, cabezazo y los del arquero (reflejos, estirada, agarre,
	// achique), de "relativos" si viene (CerebroV2.ficha_de) o sueltos; y
	// "arquero" (o rol "ARQ") y "pie_malo_lado".
	int64_t agregar(int64_t equipo, const Dictionary &fisico);
	// Etapa 6: las reglas (FisicaV2.parametros_reglas()) y lo de cada club
	// (umbral_cambio, suben_corner, cuelga_lejos). Antes de empezar. Los
	// jugadores traen "reglas" (FisicaV2.reglas_de) y los suplentes van al banco.
	void configurar_reglas(const Dictionary &reglas);
	void configurar_reglas_equipo(int64_t equipo, const Dictionary &club);
	void agregar_suplente(int64_t equipo, const Dictionary &fisico);
	// Los de fábrica de las reglas, como el JSON (para el test).
	Dictionary reglas_de_fabrica() const;
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
	// Modo ARCO: el jugador `i` le pega al arco a la próxima pelota.
	void rematar(int64_t i, int64_t golpe, double alto, double lateral);
	// La patada que busca `apuntar` (remate.h) con la pelota de `pelota`
	// (FisicaV2.parametros()): {ok, vel, giro, cruce (dónde cruza el plano),
	// segundos}. Para el test.
	static Dictionary apuntar_prueba(const Dictionary &pelota, const Vector3 &desde, const Vector3 &meta, double rapidez,
			double elevacion_fija, double giro_lateral);
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
	bool get_alcanza(int64_t i) const;
	double get_rapidez_buscada(int64_t i) const;
	double get_metros_para_parar(int64_t i) const;
	double get_giro_pendiente(int64_t i) const;
	double get_rumbo_buscado(int64_t i) const;
	int64_t get_poseedor() const;
	int64_t get_equipo_con_pelota() const;
	int64_t get_ultimo_toque() const;
	int64_t get_ultimo_tipo() const;
	int64_t get_receptor() const;
	// Etapa 5.
	int64_t get_en_manos() const;
	int64_t get_ultimo_resultado() const;
	PackedInt32Array get_arqueros() const;
	// Los goles (0 y 1).
	PackedInt32Array get_goles() const;
	Vector3 get_pelota_pos() const;
	Vector3 get_pelota_previa() const;
	Vector3 get_pelota_vel() const;
	Vector3 get_pelota_giro() const;
	// Lo que va a hacer la pelota si nadie la toca (lo que planean todos).
	PackedVector3Array prediccion() const;
	Dictionary contadores() const;
	// Etapa 5: cada remate (canchita.h, RegistroRemate).
	Array registro_remates() const;
	Array registro_pases() const;
	// Etapa 6: lo que pasó ({paso, tipo, equipo, jugador, otro, detalle, pos};
	// jugador y otro son ids), el id y la energía de cada uno, los que se van
	// ({id, equipo, pos, rumbo, rapidez, expulsado, accion, tiempo_accion}) y el estado del partido
	// ({periodo, reloj, adicion, lado, paso, corte, parada, ejecutor, punto,
	// goles_tanda, pateados_tanda}).
	Array eventos() const;
	PackedInt32Array get_ids() const;
	PackedFloat32Array get_energias() const;
	Dictionary energias_por_id() const;
	Array get_afuera() const;
	Dictionary get_estado() const;
	// Laboratorio de reanudaciones (canchita.h, forzar_*). `tipo` es el nombre
	// de la parada: "corner", "tiro_libre", "penal" o "lateral".
	bool forzar_parada(const String &tipo, int64_t equipo, const Vector2 &pos);
	bool forzar_falta(int64_t tarjeta, bool lesion);
	bool forzar_fin_de_tiempo();
	// El que tiene el lateral en las manos (-1 si nadie): la vista le dibuja
	// la pelota entre las manos.
	int64_t get_lateral_en_manos() const;
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
	// Activa o apaga la traza por paso (apagada por defecto, sin costo). Encenderla o
	// apagarla vacía el buffer.
	void activar_traza(bool on);
	// Una fila por paso: {build_id, paso, pelota, poseedor, decision, accion, motivo,
	// direccion (x, z), rapidez, raya_m}.
	Array get_traza() const;
	// Versión y fecha de compilación del motor (va en cada fila de la traza).
	String get_build_id() const;
	int64_t huella() const;

protected:
	static void _bind_methods();

private:
	motor_v2::Canchita _c;
	std::vector<String> _nombres;

	bool _valido(int64_t i) const;
	void _agregar_jugador(int equipo, const Dictionary &fisico);
};

} // namespace godot
