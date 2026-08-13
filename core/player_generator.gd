class_name PlayerGenerator
extends RefCounted

## Generador de jugadores — Fase 1 del roadmap (GDD §2, §4, §18).
## Sin nodos de Godot: todo Dictionary, para poder generar miles sin costo.

const WEIGHTS_PATH := "res://data/position_weights.json"
const ATTR_GROUPS_PATH := "res://data/attribute_groups.json"

static var _weights_cache = null
static var _all_attributes_cache: Array = []


static func get_weights() -> Dictionary:
	if _weights_cache == null:
		_weights_cache = DataLoader.load_json(WEIGHTS_PATH)
	return _weights_cache


static func get_all_attributes() -> Array:
	if _all_attributes_cache.is_empty():
		var groups = DataLoader.load_json(ATTR_GROUPS_PATH)
		var seen := {}
		for group_name in groups:
			for attr in groups[group_name]:
				seen[attr] = true
		_all_attributes_cache = seen.keys()
	return _all_attributes_cache


## Genera un jugador. forced_position vacío = posición al azar.
static func generate(id: int, rng: RandomNumberGenerator, forced_position: String = "") -> Dictionary:
	var positions := get_weights().keys()
	var position: String = forced_position if forced_position != "" else positions[rng.randi() % positions.size()]

	var genetica := Genetics.roll(rng)
	var potencial: int = genetica["potencial"]

	var atributos := {}
	for attr in get_all_attributes():
		atributos[attr] = _roll_attribute(potencial, rng)

	var media_natural := compute_media(atributos, position)
	var mejor := best_position(atributos)

	return {
		"id": id,
		"posicion": position,
		"genetica_tier": genetica["tier"],
		"potencial": potencial,
		"atributos": atributos,
		"media": media_natural,
		"mejor_posicion": mejor["posicion"],
		"media_mejor_posicion": mejor["media"],
	}


## Cada atributo se tira independiente, con techo blando en el potencial.
## factor 0.55-1.0 + ruido gaussiano da variación individual (§7.2 lo profundiza
## en fases posteriores con techo propio por atributo; acá alcanza para media general).
static func _roll_attribute(potencial: int, rng: RandomNumberGenerator) -> int:
	var factor := rng.randf_range(0.55, 1.0)
	var valor := float(potencial) * factor + rng.randfn(0.0, 4.0)
	return int(clamp(round(valor), 0, 100))


static func compute_media(atributos: Dictionary, position: String) -> float:
	var weights: Dictionary = get_weights()[position]
	var total := 0.0
	for attr in weights:
		total += float(atributos.get(attr, 0)) * float(weights[attr])
	return total / 100.0


## §2.1: guardar también la media en la mejor posición posible del jugador.
static func best_position(atributos: Dictionary) -> Dictionary:
	var best_pos := ""
	var best_media := -1.0
	for position in get_weights().keys():
		var media := compute_media(atributos, position)
		if media > best_media:
			best_media = media
			best_pos = position
	return {"posicion": best_pos, "media": best_media}
