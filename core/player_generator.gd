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
## Cuanto de su techo tiene YA realizado un jugador al nacer. §7.2 dio a
## cada atributo su propio techo; esto es cuanto de ese techo trae puesto.
## Un titular arranca entre el 55% y el 100%; un suplente bastante mas
## abajo, que es lo que lo hace suplente. Los techos NO cambian: el
## suplente puede crecer y quedarse con el puesto (§7.3), que es como
## deberia funcionar un banco.
const REALIZACION_TITULAR := Vector2(0.55, 1.0)
const REALIZACION_SUPLENTE := Vector2(0.45, 0.78)


static func generate(id: int, rng: RandomNumberGenerator, forced_position: String = "", potencial_forzado: int = -1, pais: String = "Uruguay", realizacion: Vector2 = REALIZACION_TITULAR) -> Dictionary:
	var positions := get_weights().keys()
	var position: String = forced_position if forced_position != "" else positions[rng.randi() % positions.size()]

	var potencial: int
	var tier: String
	if potencial_forzado >= 0:
		potencial = clamp(potencial_forzado + rng.randi_range(-8, 8), 15, 99)
		tier = Genetics.tier_de(potencial)
	else:
		var genetica := Genetics.roll(rng)
		potencial = genetica["potencial"]
		tier = genetica["tier"]

	var potenciales := techos_por_atributo(potencial, rng)
	var atributos := {}
	for attr in get_all_attributes():
		atributos[attr] = _roll_attribute(potenciales[attr], rng, realizacion)

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
		# §7.2: cada atributo con su propio techo. `potencial` sigue siendo
		# el número de la genética (lo usan el scouting, el valor y la UI),
		# pero lo que limita el crecimiento de CADA atributo es este dict.
		"potenciales": potenciales,
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


## §7.2: el techo de CADA atributo, derivado del potencial global más una
## variación propia. Es lo que hace que dos Prodigios no sean el mismo
## jugador: uno tope de velocidad y otro tope de pases.
##
## La variación NO se sesga por puesto a propósito. Sesgarla haría a todos
## más "correctos" para su posición, pero mataría dos cosas que ya
## existen: que aparezca un lateral que en realidad remata mejor que el 9
## (`mejor_posicion`), y que valga la pena mirar la ficha atributo por
## atributo en vez de la media.
const DESVIO_TECHO := 9.0
const TECHO_MIN := 15
const TECHO_MAX := 99


static func techos_por_atributo(potencial: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for attr in get_all_attributes():
		out[attr] = int(clamp(round(float(potencial) + rng.randfn(0.0, DESVIO_TECHO)),
			TECHO_MIN, TECHO_MAX))
	return out


## Versión determinista para partidas guardadas ANTES de que existieran
## los techos por atributo: no hay RNG disponible al cargar, así que la
## desviación sale del id del jugador y del nombre del atributo. Es
## estable (el mismo jugador siempre obtiene los mismos techos) y tiene la
## misma forma que la versión aleatoria.
static func techos_derivados(potencial: int, jugador_id: int) -> Dictionary:
	var out := {}
	for attr in get_all_attributes():
		var h: int = absi(hash("%d/%s" % [jugador_id, attr]))
		# Dos muestras uniformes promediadas se acercan a una normal, que
		# es lo que produce techos_por_atributo con randfn.
		var u1: float = float(h % 1000) / 1000.0
		var u2: float = float((h / 1000) % 1000) / 1000.0
		var desvio: float = (u1 + u2 - 1.0) * DESVIO_TECHO * 1.7
		out[attr] = int(clamp(round(float(potencial) + desvio), TECHO_MIN, TECHO_MAX))
	return out


## Cada atributo se tira independiente, con techo blando en SU propio
## techo (§7.2). factor 0.55-1.0 + ruido gaussiano da la variación de
## cuánto de ese techo ya tiene alcanzado al generarse.
static func _roll_attribute(techo: int, rng: RandomNumberGenerator,
		realizacion: Vector2 = REALIZACION_TITULAR) -> int:
	var factor := rng.randf_range(realizacion.x, realizacion.y)
	var valor := float(techo) * factor + rng.randfn(0.0, 4.0)
	# Se corta EN el techo: con factor cerca de 1 y ruido positivo, un
	# atributo nacía hasta 10 puntos por encima de su propio tope y ya
	# nunca volvía a bajar, con lo cual el techo no significaba nada.
	return int(clamp(round(valor), 0, float(techo)))


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
