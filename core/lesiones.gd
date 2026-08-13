class_name Lesiones
extends RefCounted

## Motor de lesiones — Fase 5 (GDD §2.3).
##
## instalaciones_medicas y carga_entrenamiento todavía no son sistemas reales
## (eso es Mejoras/Entrenamiento de club, fases de economía) — quedan en 1.0
## hasta que existan y multipliquen el riesgo como dice el GDD.
##
## Nota sobre la fórmula del GDD: "riesgo = base × (1 − energía/100) × ...",
## tomada literal, da riesgo CERO con el jugador 100% descansado — ningún
## futbolista fresco se lesiona nunca, lo cual no pasa en la realidad. Acá
## se usa un multiplicador de fatiga que nunca baja de 1.0 (nunca reduce el
## riesgo base) y llega a 2.0 con el jugador reventado, conservando la
## intención (cansado se lesiona más) sin el efecto absurdo.

const TABLA_PATH := "res://data/lesiones.json"
## Bajado de 0.0018 a 0.0010 en el balance de la fase 10: sin plantel de 25
## todavía (§14), una lesión no se cubre con un suplente — le pega directo
## a la posición por el resto de la temporada. A la tasa vieja (~0,75
## lesiones nuevas por jugador y temporada) eso inflaba los goles de una
## temporada completa a ~5,5 por partido con las defensas degradadas. No
## es la solución real (esa es tener banco), pero mientras tanto conviene
## que ocurran con menos frecuencia.
const RIESGO_BASE := 0.0010

static var _tabla_cache: Array = []


static func _tabla() -> Array:
	if _tabla_cache.is_empty():
		_tabla_cache = DataLoader.load_json(TABLA_PATH)["lesiones"]
	return _tabla_cache


static func evaluar_riesgo(jugador: Dictionary, resistencia_pct: float,
		instalaciones_medicas: float = 1.0, carga_entrenamiento: float = 1.0) -> float:
	var propension: float = float(jugador.get("propension_lesion", 50)) / 100.0
	var factor_fatiga: float = 1.0 + (1.0 - clamp(resistencia_pct, 0.0, 1.0))
	var factor_edad: float = 1.3 if jugador["edad"] > 32 else 1.0
	var factor_personalidad: float = Personalidad.factor_lesion(jugador)
	return RIESGO_BASE * factor_fatiga * propension * carga_entrenamiento * factor_edad * instalaciones_medicas * factor_personalidad


## Devuelve {} si no hay lesión, o {"tipo":String, "dias":int} si hubo.
static func intentar_lesion(jugador: Dictionary, resistencia_pct: float, rng: RandomNumberGenerator) -> Dictionary:
	var riesgo := evaluar_riesgo(jugador, resistencia_pct)
	if rng.randf() >= riesgo:
		return {}

	var es_arquero: bool = jugador["posicion"] == "ARQ"
	var candidatas := []
	var total_peso := 0.0
	for l in _tabla():
		if bool(l.get("solo_arquero", false)) and not es_arquero:
			continue
		candidatas.append(l)
		total_peso += float(l["peso"])

	var pick := rng.randf() * total_peso
	var acc := 0.0
	for l in candidatas:
		acc += float(l["peso"])
		if pick <= acc:
			return {"tipo": l["nombre"], "dias": rng.randi_range(int(l["dias_min"]), int(l["dias_max"]))}

	return {}
