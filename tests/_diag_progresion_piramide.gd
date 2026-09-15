extends SceneTree

## Progresión de la pirámide entera sin el club del jugador: cuánto sube la
## media, cuántos atributos tocan 95+ y cuántas habilidades se aprenden por
## temporada. Es el control de antes/después al sacar el foco individual.

const SEED := 777
const TEMPORADAS := 6


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	print("temp | media div1 | media div5 | media div10 | attrs 95+ | aprendidas | media 90+")
	_reporte(piramide, 0, 0)
	for t in range(TEMPORADAS):
		var con_habilidad := _ids_con_habilidad(piramide)
		# Fecha por fecha con avanzar_dias, como en el juego. Sin eso nadie
		# se cura, los planteles de 18 no llegan al mínimo y medio fixture
		# termina 0-3: los minutos y el rendimiento salían mal medidos.
		for liga in piramide.divisiones:
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng)
				liga.avanzar_dias(7)
		piramide.fin_de_temporada(rng, null, t)
		var nuevas := 0
		for id in _ids_con_habilidad(piramide):
			if id >= 0 and con_habilidad.has(-1 - id):
				nuevas += 1
		_reporte(piramide, t + 1, nuevas)
	quit()


func _jugadores(piramide: Piramide) -> Array:
	var todos := []
	for liga in piramide.divisiones:
		for e in liga.equipos:
			todos.append_array(e.todos_los_jugadores())
	return todos


## Solo cuenta a los que ya estaban en la pirámide: un canterano nuevo que
## nace con habilidad no es un aprendizaje.
func _ids_con_habilidad(piramide: Piramide) -> Dictionary:
	var ids := {}
	for j in _jugadores(piramide):
		if not j.get("habilidad", {}).is_empty():
			ids[j["id"]] = true
		else:
			ids[-1 - int(j["id"])] = true
	return ids


func _media_division(piramide: Piramide, d: int) -> float:
	var liga: Liga = piramide.divisiones[d]
	var suma := 0.0
	for e in liga.equipos:
		suma += e.media_equipo()
	return suma / float(liga.equipos.size())


func _reporte(piramide: Piramide, t: int, nuevas: int) -> void:
	var altos := 0
	var cracks := 0
	for j in _jugadores(piramide):
		if float(j["media"]) >= 90.0:
			cracks += 1
		for a in j["atributos"]:
			if int(j["atributos"][a]) >= 95:
				altos += 1
	print("%4d | %10.1f | %10.1f | %11.1f | %9d | %10d | %d" % [t, _media_division(piramide, 0),
		_media_division(piramide, 4), _media_division(piramide, 9), altos, nuevas, cracks])
