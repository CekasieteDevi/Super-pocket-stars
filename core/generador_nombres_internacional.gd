class_name GeneradorNombresInternacional
extends RefCounted

## §10.1/§10.5: pool de nombres creíble POR PAÍS para los 110 clubes del
## exterior y sus jugadores — hasta ahora los clubes extranjeros eran
## placeholders tipo "Brasil FC 01" (Confederacion.generar) y sus
## jugadores usaban el mismo pool uruguayo que el resto de la pirámide
## (GeneradorNombres.nombre_jugador, sin país). Plantillas de nombre por
## país tomadas del GDD §10.1 donde las da explícitas (Brasil, España,
## Inglaterra, Italia, Alemania, Francia, Países Bajos); Argentina/
## Portugal/México/Colombia no tenían plantilla en el documento, así que
## se armaron con el mismo criterio (tipo de club real de esos países +
## pool de ciudades reales) — no hay tipo/ciudad de club real usado tal
## cual (serían clubes reales), son combinaciones nuevas. Uruguay sigue
## usando GeneradorNombres/data/nombres.json sin cambios.

const PATH := "res://data/nombres_internacional.json"
static var _datos_cache = null


static func _datos() -> Dictionary:
	if _datos_cache == null:
		_datos_cache = DataLoader.load_json(PATH)
	return _datos_cache


## Confederacion.PAISES_INICIALES usa nombres ASCII ("Espana", "Mexico",
## "Paises Bajos") como clave real de data/nombres_internacional.json,
## pero otras partes del motor (ej. GameState.PAISES_RIVALES_SELECCION,
## para los amistosos de la Selección) pasan la forma acentuada — se
## resuelve acá en vez de duplicar los datos con dos claves por país.
const ALIAS_ACENTOS := {"España": "Espana", "México": "Mexico", "Países Bajos": "Paises Bajos"}


static func _clave(pais: String) -> String:
	if _datos().has(pais):
		return pais
	return ALIAS_ACENTOS.get(pais, pais)


static func tiene_pais(pais: String) -> bool:
	return _datos().has(_clave(pais))


## usados: mismo patrón que GeneradorNombres.nombre_club — set compartido
## para que dos clubes del mismo país no terminen con el mismo nombre.
static func nombre_club(pais: String, rng: RandomNumberGenerator, usados: Dictionary) -> String:
	var datos: Dictionary = _datos().get(_clave(pais), {})
	if datos.is_empty():
		return "%s FC %02d" % [pais, usados.size() + 1]  # país sin pool todavía: fallback al placeholder viejo

	var formato: String = datos["formato_club"]
	var tipos: Array = datos["tipos_club"]
	var ciudades: Array = datos["ciudades"]
	var sufijos: Array = datos.get("sufijos_club", [""])

	for intento in range(30):
		var candidato: String = formato.format({
			"tipo": tipos[rng.randi() % tipos.size()],
			"ciudad": ciudades[rng.randi() % ciudades.size()],
			"sufijo": sufijos[rng.randi() % sufijos.size()],
		})
		if not usados.has(candidato):
			usados[candidato] = true
			return candidato

	var contador := 1
	while true:
		var candidato: String = "%s Club %d" % [pais, contador]
		if not usados.has(candidato):
			usados[candidato] = true
			return candidato
		contador += 1
	return ""


## Nombre y apellido de un jugador de este país — sin control de
## duplicados, mismo criterio que GeneradorNombres.nombre_jugador (con
## miles de jugadores posibles no vale la pena la lista de "ya usados").
## Si el país no tiene pool propio, cae al pool uruguayo en vez de romper.
static func nombre_jugador(pais: String, rng: RandomNumberGenerator) -> Dictionary:
	var datos: Dictionary = _datos().get(_clave(pais), {})
	if datos.is_empty():
		return GeneradorNombres.nombre_jugador(rng)

	var nombres: Array = datos["nombres_jugador"]
	var apellidos: Array = datos["apellidos_jugador"]
	return {
		"nombre": nombres[rng.randi() % nombres.size()],
		"apellido": apellidos[rng.randi() % apellidos.size()],
	}
