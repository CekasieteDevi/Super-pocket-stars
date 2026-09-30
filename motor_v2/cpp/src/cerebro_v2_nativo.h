#pragma once

// Lo que GDScript le pasa al cerebro del Motor V2 (cerebro/cerebro.h, etapa
// 4): los pesos de data/utility_pesos.json y de data/fisica_v2.json
// ("cerebro"), el plan de cada club y la ficha de cada jugador. Los arma
// motor_v2/cerebro_v2.gd.

#include "cerebro/cerebro.h"

#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

// `utility`: MotorEspacial.pesos() (las secciones con sus nombres de siempre).
// `nuevos`: la sección "cerebro" de data/fisica_v2.json.
void leer_pesos_cerebro(const Dictionary &utility, const Dictionary &nuevos, motor_v2::PesosCerebro &p);
// Los pesos armados como los JSON (mismas secciones y claves): para que el
// test compare los valores de fábrica del C++ con los de los JSON.
Dictionary pesos_cerebro_a_diccionario(const motor_v2::PesosCerebro &p);
void leer_plan_equipo(const Dictionary &d, motor_v2::PlanEquipo &p);
// `d`: rol (String), base (Vector2), atributos y relativos (Dictionary de
// Player) y los rasgos (creador, metodico, pie_malo_lado, margen_offside).
void leer_ficha_cerebro(int equipo, const Dictionary &d, motor_v2::FichaCerebro &f);

} // namespace godot
