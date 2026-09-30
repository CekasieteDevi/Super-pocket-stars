#pragma once

// El único generador al azar del Motor V2 (docs/motor_v2.md, "Cómo se
// escribe el C++"): PCG32, el mismo de MundoV2Nativo. Da la misma serie en la
// PC y en Android porque solo usa enteros.

#include <cstdint>

namespace motor_v2 {

struct Azar {
	uint64_t estado = 0;

	void sembrar(int64_t semilla) {
		estado = uint64_t(semilla) * 2u + 1u;
		siguiente();
	}

	uint32_t siguiente() {
		uint64_t viejo = estado;
		estado = viejo * 6364136223846793005ULL + 1442695040888963407ULL;
		uint32_t mezcla = uint32_t(((viejo >> 18u) ^ viejo) >> 27u);
		uint32_t giro = uint32_t(viejo >> 59u);
		return (mezcla >> giro) | (mezcla << ((-int32_t(giro)) & 31));
	}

	// En [0, 1).
	double uno() {
		return double(siguiente()) / 4294967296.0;
	}

	double entre(double desde, double hasta) {
		return desde + (hasta - desde) * uno();
	}

	// Casi normal, media 0 y desvío 1: suma de cuatro uniformes (Irwin-Hall).
	// Box-Muller necesita log y coseno del sistema; esto solo suma, y el error
	// de ejecución no necesita colas largas: nunca pasa de ±3,5.
	double normal() {
		double s = uno() + uno() + uno() + uno();
		// Cuatro uniformes: media 2, varianza 4/12.
		return (s - 2.0) * 1.7320508075688772;
	}
};

} // namespace motor_v2
