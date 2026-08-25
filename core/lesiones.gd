class_name Lesiones
extends RefCounted

## Motor de lesiones — Fase 5 (GDD §2.3).
##
## instalaciones_medicas ya es un sistema real (§9.5, Instalaciones.factor_riesgo_lesion)
## y carga_entrenamiento también (§7.4.1, CargaEntrenamiento.factor_lesion);
## los dos se pasan desde MatchEngine._chequear_lesion.
##
## Nota sobre la fórmula del GDD: "riesgo = base × (1 − energía/100) × ...",
## tomada literal, da riesgo CERO con el jugador 100% descansado — ningún
## futbolista fresco se lesiona nunca, lo cual no pasa en la realidad. Acá
## se usa un multiplicador de fatiga que nunca baja de 1.0 (nunca reduce el
## riesgo base) y llega a 2.0 con el jugador reventado, conservando la
## intención (cansado se lesiona más) sin el efecto absurdo.

const TABLA_PATH := "res://data/lesiones.json"
## Subido de 0.0010 a 0.0050. La tasa vieja se habia bajado porque no
## habia banco: una lesion no se cubria con nadie y le pegaba a la
## posicion por el resto de la temporada. Eso ya no aplica —el banco de 7
## existe (§14) y la cantera cubre las emergencias (ver
## Team.ajustar_convocatorias_de_emergencia)—, y a 0.0010 el sistema no
## se sentia: ~3 lesiones por plantel y temporada, 1,5% del plantel
## afuera. Con eso, entrenar Brutal era gratis y ademas daba puntos, o
## sea que elegir la carga (§7.4.1) no era una decision.
##
## A 0.0050 con carga Normal: ~16 lesiones por plantel y temporada, 7%
## del plantel afuera en cualquier momento, ~2,7 graves. Brutal cuesta
## 2,6 puntos por temporada y paga con +1,1 de media a las 4 — que es la
## forma que tenia que tener el intercambio. Los goles no se movieron
## (2,8-3,0 por partido, igual que antes).
##
## OJO: subir esto no alcanzaba por si solo. El motivo real de que las
## lesiones no dolieran era que el banco salia tan bueno como el once
## (+0,2 de media) — ver Team._acomodar_por_calidad.
const RIESGO_BASE := 0.0050

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
static func intentar_lesion(jugador: Dictionary, resistencia_pct: float, rng: RandomNumberGenerator,
		instalaciones_medicas: float = 1.0, carga_entrenamiento: float = 1.0) -> Dictionary:
	var riesgo := evaluar_riesgo(jugador, resistencia_pct, instalaciones_medicas, carga_entrenamiento)
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
