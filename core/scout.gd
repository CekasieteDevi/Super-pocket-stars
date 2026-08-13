class_name Scout
extends RefCounted

## Scouts — Fase 6 (GDD §9.4, §15 decisión 9). Cada scout tiene un nivel
## 1-8 que determina el margen de error del reporte: el atributo real
## queda oculto detrás de un rango real ± margen.

const MARGEN_POR_NIVEL := {
	1: 20, 2: 15, 3: 11, 4: 8, 5: 5, 6: 3, 7: 1, 8: 0,
}

const NIVEL_MAXIMO := 8
const SCOUTS_MAXIMOS := 8


static func margen(nivel: int) -> int:
	return MARGEN_POR_NIVEL.get(clamp(nivel, 1, NIVEL_MAXIMO), 20)


## Reporte de scouting de un jugador: cada atributo pasa a ser un rango
## [real-margen, real+margen] en vez de un número exacto. Con nivel 8 el
## rango colapsa al valor real (dato exacto).
static func reportar(jugador: Dictionary, nivel: int) -> Dictionary:
	var m := margen(nivel)
	var reporte := {}
	for attr in jugador["atributos"]:
		var real: int = jugador["atributos"][attr]
		reporte[attr] = [clamp(real - m, 0, 100), clamp(real + m, 0, 100)]
	return reporte
