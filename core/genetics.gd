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
