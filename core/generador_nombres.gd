class_name GeneradorNombres
extends RefCounted

## Fix 10 del GDD: mundo horneado con nombres (ficticios, no de clubes ni
## jugadores reales — el GDD aclara nombres de PAÍS reales pero nunca
## clubes/escudos/jugadores reales) en vez de placeholders como "D10 Club
## 02" o jugadores sin nombre. Pool de nombres/apellidos de sabor
## rioplatense y combinaciones de club estilo uruguayo: 11 tipos x 40
## nombres = 440 combinaciones posibles, de sobra para los 200 clubes de
## la pirámide sin agotarse ni tener que repetir.

const PATH := "res://data/nombres.json"
static var _datos_cache = null


static func _datos() -> Dictionary:
	if _datos_cache == null:
		_datos_cache = DataLoader.load_json(PATH)
	return _datos_cache


## usados: Dictionary usado como set de nombres ya asignados (compartido
## entre todas las divisiones de la pirámide) para que dos clubes no
## terminen con el mismo nombre. Si algún día se agotaran las 440
## combinaciones, cae a un sufijo numérico para no trabarse.
static func nombre_club(rng: RandomNumberGenerator, usados: Dictionary) -> String:
	var tipos: Array = _datos()["tipos_club"]
	var nombres: Array = _datos()["nombres_club"]

	for intento in range(30):
		var candidato: String = "%s %s" % [tipos[rng.randi() % tipos.size()], nombres[rng.randi() % nombres.size()]]
		if not usados.has(candidato):
			usados[candidato] = true
			return candidato

	var contador := 1
	while true:
		var candidato: String = "Club %d" % contador
		if not usados.has(candidato):
			usados[candidato] = true
			return candidato
		contador += 1
	return ""


## Nombre y apellido de un jugador. No se controlan duplicados a propósito
## (en la vida real hay muchos "Diego Rodríguez" distintos, y con miles de
## jugadores en la pirámide sería una lista carísima de mantener sin
## fondo) — el id sigue siendo la clave única real.
static func nombre_jugador(rng: RandomNumberGenerator) -> Dictionary:
	var nombres: Array = _datos()["nombres_jugador"]
	var apellidos: Array = _datos()["apellidos_jugador"]
	return {
		"nombre": nombres[rng.randi() % nombres.size()],
		"apellido": apellidos[rng.randi() % apellidos.size()],
	}
