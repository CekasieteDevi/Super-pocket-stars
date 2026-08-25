class_name Genetics
extends RefCounted

## Tiers de potencial (techo de media). Datos en data/genetics_tiers.json (GDD §4).

const TIERS_PATH := "res://data/genetics_tiers.json"

static var _tiers_cache = null


static func get_tiers() -> Array:
	if _tiers_cache == null:
		var data = DataLoader.load_json(TIERS_PATH)
		_tiers_cache = data["tiers"]
	return _tiers_cache


## Tira un tier según su probabilidad y devuelve {tier, potencial}.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var tiers := get_tiers()
	var total_prob := 0.0
	for t in tiers:
		total_prob += float(t["prob"])

	var pick := rng.randf() * total_prob
	var acc := 0.0
	for t in tiers:
		acc += float(t["prob"])
		if pick <= acc:
			return {
				"tier": t["tier"],
				"potencial": rng.randi_range(int(t["min"]), int(t["max"])),
			}

	# Fallback por redondeo flotante: último tier de la tabla.
	var last = tiers[tiers.size() - 1]
	return {
		"tier": last["tier"],
		"potencial": rng.randi_range(int(last["min"]), int(last["max"])),
	}


## El tier que le corresponde a un potencial ya decidido. Se usa cuando el
## potencial viene impuesto de afuera (nivel de la división, fuerza de un
## club del exterior, de una selección) en vez de salir de roll(): antes
## esos jugadores se marcaban todos como "Extranjero", que no está en la
## tabla, y entonces Progresion.VELOCIDAD_POR_TIER caía al 1.0 por defecto
## y Aprendizaje no les daba nunca el bonus de genética. O sea que el tier
## dejaba de significar algo justo para los planteles generados por nivel.
static func tier_de(potencial: int) -> String:
	var tiers := get_tiers()
	var mejor: String = str(tiers[tiers.size() - 1]["tier"])
	for t in tiers:
		if potencial >= int(t["min"]):
			return str(t["tier"])
		mejor = str(t["tier"])
	return mejor
