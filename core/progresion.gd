class_name Progresion
extends RefCounted

## Progresión por edad y entrenamiento — Fase 5 (GDD §7.1, §4 punto 2).
##
## Sin calendario semanal real todavía (eso necesita más UI/economía de
## fases posteriores), la ganancia de entrenamiento se aplica una sola vez
## por temporada, al final: crecimiento hacia el potencial para los jóvenes,
## declive diferenciado por grupo de atributos para los veteranos.

const CURVA_EDAD := [
	{"min": 15, "max": 18, "mult": 2.0},
	{"min": 19, "max": 23, "mult": 1.5},
	{"min": 24, "max": 28, "mult": 1.0},
	{"min": 29, "max": 32, "mult": 0.5},
	{"min": 33, "max": 35, "mult": 0.2},
	{"min": 36, "max": 37, "mult": 0.0},
]

## §7.1: los físicos bajan primero y más fuerte, los técnicos poco, y los
## mentales siguen subiendo un toque incluso en declive (valor negativo).
const DECLIVE_POR_GRUPO := {
	"fisico": 1.0,
	"defensivo": 0.6,
	"tecnico": 0.3,
	"mental": -0.15,
}

## §4 punto 2: un GOAT crece ~2x más rápido que un Del montón.
const VELOCIDAD_POR_TIER := {
	"GOAT": 2.0, "Idolo": 1.8, "Prodigio": 1.6, "Prometedor": 1.4,
	"Solido": 1.2, "Correcto": 1.1, "Del monton": 1.0, "Justito": 0.9,
	"Limitado": 0.8, "Descarte": 0.7,
}

const ATTR_GROUPS_PATH := "res://data/attribute_groups.json"
static var _attr_grupo_cache: Dictionary = {}


static func _grupo_de_atributo(attr: String) -> String:
	if _attr_grupo_cache.is_empty():
		var groups = DataLoader.load_json(ATTR_GROUPS_PATH)
		var normalizado := {
			"fisicos": "fisico", "tecnicos": "tecnico",
			"defensivos": "defensivo", "mentales": "mental", "arquero": "tecnico",
		}
		for grupo in groups:
			for attr_nombre in groups[grupo]:
				_attr_grupo_cache[attr_nombre] = normalizado.get(grupo, "tecnico")
	return _attr_grupo_cache.get(attr, "tecnico")


static func _multiplicador_crecimiento(edad: int) -> float:
	for tramo in CURVA_EDAD:
		if edad >= tramo["min"] and edad <= tramo["max"]:
			return tramo["mult"]
	return -1.0  # 38+: declive


## Envejece un año al jugador y mueve sus atributos. Modifica el dict in
## place. mult_mentor (§6 extendido, Mentores.multiplicador_para): bonus de
## crecimiento si hay un veterano líder en su plantel y este jugador es
## joven — 1.0 si no aplica ninguna de las dos cosas. mult_entrenamiento
## (§9.5, Instalaciones.factor_entrenamiento): +1%/nivel de instalaciones
## de entrenamiento, sobre TODO el crecimiento. foco_atributo (§7.4 punto
## 3, core/entrenamiento.gd): si no es "", ESE atributo puntual crece al
## doble esta temporada — "" si el jugador no tiene foco individual.
const MULTIPLICADOR_FOCO := 2.0


static func aplicar_temporada(jugador: Dictionary, rng: RandomNumberGenerator, mult_mentor: float = 1.0,
		mult_entrenamiento: float = 1.0, foco_atributo: String = "") -> void:
	jugador["edad"] += 1
	var mult_edad := _multiplicador_crecimiento(jugador["edad"])
	var mult_tier: float = VELOCIDAD_POR_TIER.get(jugador["genetica_tier"], 1.0)
	var mult_personalidad: float = Personalidad.factor_entrenamiento(jugador)

	# §6 Comodón: "si es titular fijo 15 partidos, deja de crecer" — se
	# congela del todo el crecimiento de esta temporada (ni siquiera el
	# ruido aleatorio), no solo se lo reduce. El declive de veteranos NO
	# se ve afectado (esta bandera solo pesa en la rama de crecimiento).
	var congelado_por_comodon: bool = Personalidad.tiene(jugador, "Comodon") and \
		int(jugador.get("partidos_seguidos_titular", 0)) >= Personalidad.UMBRAL_COMODON

	for attr in jugador["atributos"].keys():
		var valor_actual: float = jugador["atributos"][attr]
		var cambio := 0.0

		if mult_edad >= 0.0:
			if not congelado_por_comodon:
				var distancia: float = float(jugador["potencial"]) - valor_actual
				if distancia > 0.0:
					var mult_foco: float = MULTIPLICADOR_FOCO if attr == foco_atributo else 1.0
					cambio = distancia * 0.12 * mult_edad * mult_tier * mult_personalidad * mult_mentor * mult_entrenamiento * mult_foco
				cambio += rng.randfn(0.0, 0.6)
		else:
			var grupo := _grupo_de_atributo(attr)
			var factor_declive: float = DECLIVE_POR_GRUPO.get(grupo, 0.5)
			cambio = -factor_declive * (1.0 + rng.randf() * 0.5)
			cambio += rng.randfn(0.0, 0.6)

		jugador["atributos"][attr] = clamp(round(valor_actual + cambio), 0, 100)

	jugador["media"] = PlayerGenerator.compute_media(jugador["atributos"], jugador["posicion"])
	var mejor := PlayerGenerator.best_position(jugador["atributos"])
	jugador["mejor_posicion"] = mejor["posicion"]
	jugador["media_mejor_posicion"] = mejor["media"]
