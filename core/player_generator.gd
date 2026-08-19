class_name PlayerGenerator
extends RefCounted

## Generador de jugadores — Fase 1 del roadmap (GDD §2, §4, §18).
## Sin nodos de Godot: todo Dictionary, para poder generar miles sin costo.

const WEIGHTS_PATH := "res://data/position_weights.json"
const ATTR_GROUPS_PATH := "res://data/attribute_groups.json"

static var _weights_cache = null
static var _all_attributes_cache: Array = []
static var _groups_cache = null


## Los atributos agrupados como los define el GDD (§2). Lo usa la ficha
## del jugador para mostrarlos por bloque en vez de como una lista de 25.
static func get_attribute_groups() -> Dictionary:
	if _groups_cache == null:
		_groups_cache = DataLoader.load_json(ATTR_GROUPS_PATH)
	return _groups_cache


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
## potencial_forzado >= 0 saltea la tabla de tiers de §4 y usa ese valor
## (± variación) como potencial directamente — lo usan los clubes del
## exterior (Fase 7, §10.5) para que el plantel generado ronde su
## fuerza_equipo horneada en vez de la distribución calibrada para Uruguay.
## pais (§10.1): pool de nombre/apellido — "Uruguay" (default) usa
## GeneradorNombres, cualquier otro país reconocido usa su propio pool
## (GeneradorNombresInternacional), y un país sin pool cae al de Uruguay.
static func generate(id: int, rng: RandomNumberGenerator, forced_position: String = "", potencial_forzado: int = -1, pais: String = "Uruguay") -> Dictionary:
	var positions := get_weights().keys()
	var position: String = forced_position if forced_position != "" else positions[rng.randi() % positions.size()]

	var potencial: int
	var tier: String
	if potencial_forzado >= 0:
		potencial = clamp(potencial_forzado + rng.randi_range(-8, 8), 15, 99)
		tier = "Extranjero"
	else:
		var genetica := Genetics.roll(rng)
		potencial = genetica["potencial"]
		tier = genetica["tier"]

	var atributos := {}
	for attr in get_all_attributes():
		atributos[attr] = _roll_attribute(potencial, rng)

	var media_natural := compute_media(atributos, position)
	var mejor := best_position(atributos)
	var identidad: Dictionary = GeneradorNombres.nombre_jugador(rng) if pais == "Uruguay" else GeneradorNombresInternacional.nombre_jugador(pais, rng)

	return {
		"id": id,
		"nombre": identidad["nombre"],
		"apellido": identidad["apellido"],
		"posicion": position,
		"genetica_tier": tier,
		"potencial": potencial,
		"atributos": atributos,
		"media": media_natural,
		"mejor_posicion": mejor["posicion"],
		"media_mejor_posicion": mejor["media"],
		"edad": rng.randi_range(18, 35),
		# Oculto (§2, "Atributos ocultos"): multiplica el riesgo de lesión.
		# Distribución triangular (promedio de dos tiradas) para que los
		# extremos (indestructible / de cristal) sean menos comunes.
		"propension_lesion": int(round((rng.randf() + rng.randf()) / 2.0 * 100.0)),
		# §6: 1 positiva + 1 negativa, o ninguna de las dos — nunca una sola.
		"personalidades": Personalidad.generar(rng),
		# §5: como mucho 1 habilidad por jugador, {} si no le tocó ninguna.
		"habilidad": Habilidades.generar(position, rng),
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
