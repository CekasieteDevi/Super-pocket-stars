class_name Habilidades
extends RefCounted

## Habilidades — GDD §5. 3 niveles (bronce/plata/oro), como personalidad
## se generan (no se eligen) y quedan fijas: máximo 1 habilidad por
## jugador. Igual que un rasgo de personalidad, es un modificador más del
## bloque D del duelo (§8.4/§8.5, "efectos de personalidad y habilidades")
## — no cambia qué acción se intenta, solo empuja en puntos porcentuales
## la probabilidad de esa acción puntual, escalado por nivel. El talento
## (atributos) sigue mandando, la habilidad empuja.
##
## Simplificaciones documentadas: el GDD también describe "aprender" una
## habilidad de bronce entrenando 2 temporadas + mentor, y que un scout de
## nivel alto revele una habilidad "latente" (bajo el umbral de media
## para manifestarse) como pista de fichaje — ninguna de las dos está
## implementada todavía, solo la generación al crear el jugador + el
## efecto en partido una vez manifestada.

const DATA_PATH := "res://data/habilidades.json"

const P_BRONCE := 0.15
const P_PLATA_SI_BRONCE := 0.10
const P_ORO_SI_PLATA := 0.05

## Media mínima para que cada nivel se manifieste (aplique su bonus) —
## por debajo de esto el jugador "tiene" la habilidad pero todavía no hace
## nada, como un piso que primero hay que alcanzar.
const MEDIA_MINIMA := {1: 55.0, 2: 70.0, 3: 80.0}

## Bonus en puntos porcentuales al duelo (bloque D), por nivel.
const BONUS_DUELO := {1: 2.0, 2: 4.0, 3: 6.0}

## Atajapenales trabaja distinto: resta directo a la chance de convertir
## en Penales.gd (escala 0..1), no son puntos porcentuales de duelo.
const BONUS_ATAJAPENALES := {1: 0.05, 2: 0.09, 3: 0.13}

static var _datos_cache: Dictionary = {}
static var _atributo_por_nombre_cache: Dictionary = {}


static func _datos() -> Dictionary:
	if _datos_cache.is_empty():
		_datos_cache = DataLoader.load_json(DATA_PATH)
		for grupo in _datos_cache:
			for atributo in _datos_cache[grupo]:
				for nombre in _datos_cache[grupo][atributo]:
					_atributo_por_nombre_cache[nombre] = atributo
	return _datos_cache


## Devuelve {} (sin habilidad) o {"nombre":String, "nivel":int 1-3}.
## "campo" para cualquier posición salvo ARQ, que tiene su propio pool
## (reflejos + Atajapenales) — habilidades "coherentes con la posición".
static func generar(posicion: String, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= P_BRONCE:
		return {}

	var datos := _datos()
	var grupo: String = "arquero" if posicion == "ARQ" else "campo"
	var atributos: Array = datos[grupo].keys()
	var atributo: String = atributos[rng.randi() % atributos.size()]
	var opciones: Array = datos[grupo][atributo]
	var nombre: String = opciones[rng.randi() % opciones.size()]

	var nivel := 1
	if rng.randf() < P_PLATA_SI_BRONCE:
		nivel = 2
		if rng.randf() < P_ORO_SI_PLATA:
			nivel = 3

	return {"nombre": nombre, "nivel": nivel}


static func atributo_de(nombre: String) -> String:
	_datos()  # asegura que el cache de atributo por nombre este poblado
	return _atributo_por_nombre_cache.get(nombre, "")


## true si el jugador tiene ESTA habilidad puntual Y ya alcanzó la media
## mínima para que se manifieste.
static func tiene_manifestada(jugador: Dictionary, nombre: String) -> bool:
	var h: Dictionary = jugador.get("habilidad", {})
	if h.get("nombre", "") != nombre:
		return false
	return jugador["media"] >= MEDIA_MINIMA.get(h.get("nivel", 1), 999.0)


## Bonus de bloque D (§8.4/§8.5) para ESTE jugador en un duelo de este
## atributo puntual — 0.0 si no tiene ninguna habilidad manifestada que
## aplique a este atributo.
static func modificador_partido(jugador: Dictionary, atributo: String) -> float:
	var h: Dictionary = jugador.get("habilidad", {})
	if h.is_empty():
		return 0.0
	if atributo_de(h["nombre"]) != atributo:
		return 0.0
	if jugador["media"] < MEDIA_MINIMA.get(h["nivel"], 999.0):
		return 0.0
	return BONUS_DUELO.get(h["nivel"], 0.0)


## Cuánto le resta a la chance de convertir del PATEADOR el arquero con
## Atajapenales manifestada — 0.0 si no aplica.
static func bonus_atajapenales(arquero: Dictionary) -> float:
	var h: Dictionary = arquero.get("habilidad", {})
	if h.get("nombre", "") != "Atajapenales":
		return 0.0
	if arquero["media"] < MEDIA_MINIMA.get(h["nivel"], 999.0):
		return 0.0
	return BONUS_ATAJAPENALES.get(h["nivel"], 0.0)
