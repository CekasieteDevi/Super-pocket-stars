extends SceneTree

## El silbato corta el juego después del contacto. No debe convertir el
## último tramo de carrera en una pausa previa a la barrida.


func _init() -> void:
	_probar_separacion_del_corte()
	_probar_partido_completo()
	print("OK: la carrera llega al contacto y solo el acomodo corta la interpolacion")
	quit()


func _probar_separacion_del_corte() -> void:
	var continuidad := _fotogramas(false)
	assert(bool(continuidad[1]["corte"]))
	assert(not VistaPartido._es_reubicacion(continuidad[1]),
		"El silbato sin salto no debe cortar la carrera")
	var plan := CoreografiaPartido.new()
	plan.configurar(continuidad, VistaPartido.DURACION_ACCION)
	assert((plan.pelota(0, 0.5)["pos"] as Vector2).is_equal_approx(Vector2(1.0, 0.0)),
		"La pelota debe llegar con el jugador hasta el contacto")

	var salto := _fotogramas(true)
	assert(VistaPartido._es_reubicacion(salto[1]),
		"El acomodo para el tiro libre debe seguir siendo un salto")
	plan.configurar(salto, VistaPartido.DURACION_ACCION)
	assert((plan.pelota(0, 0.5)["pos"] as Vector2).is_equal_approx(Vector2.ZERO),
		"No interpolar la reubicacion de la pelota")
	assert(VistaPartido._es_reubicacion({"corte": true}),
		"Los partidos viejos conservan el comportamiento anterior")


## Recorre el motor completo, no el laboratorio. Busca una falta común y
## verifica la secuencia real: barrida/caída, pausa y acomodo posterior.
func _probar_partido_completo() -> void:
	for semilla in range(2000, 2012):
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var local := Team.generar("Local", rng)
		var visita := Team.generar("Visita", rng, 1000)
		var fotogramas: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for i in range(fotogramas.size()):
			var f: Dictionary = fotogramas[i]
			var falta := false
			for evento in f.get("eventos", []):
				if str(evento.get("tipo", "")) == "falta":
					falta = true
					break
			# El penal tiene otro armado inmediato; este bug es el tiro libre.
			if not falta or VistaPartido._es_reubicacion(f):
				continue
			assert(bool(f.get("corte", false)), "La falta debe marcar el silbato")
			var barrida := false
			var caida := false
			for accion in f.get("acciones", []):
				barrida = barrida or str(accion.get("accion", "")) == "barrida"
				caida = caida or str(accion.get("accion", "")) == "cae"
			assert(barrida and caida, "El contacto debe verse antes del acomodo")
			# No toda falta tiene salto: si la pelota quedó donde fue la
			# infracción, los jugadores trotan a sus marcas y no hay acomodo
			# (ver TIPOS_QUE_SE_UBICAN). Lo que no puede pasar es que la
			# pelota salte sin que el fotograma lo marque. Antes el test
			# exigía un acomodo en la primera falta y pasaba porque en esa
			# semilla la pelota había rodado lejos.
			var acomodo := false
			for k in range(i + 1, mini(fotogramas.size(), i + MotorEspacial.TICKS_CONGELADO_FALTA + 2)):
				var p0: Dictionary = fotogramas[k - 1]["pelota"]
				var p1: Dictionary = fotogramas[k]["pelota"]
				var salto := Vector2(p0["x"], p0["y"]).distance_to(Vector2(p1["x"], p1["y"]))
				if VistaPartido._es_reubicacion(fotogramas[k]):
					acomodo = true
					break
				assert(salto <= 1.0, "La pelota salta al tiro libre sin marcar el acomodo")
			if acomodo:
				return
	assert(false, "No aparecio una falta con acomodo en doce partidos completos")


func _fotogramas(reubicacion: bool) -> Array:
	var lista: Array = []
	for i in range(2):
		lista.append({
			"periodo": 1,
			"jugadores": [{"id": 1, "x": float(i) * 2.0, "y": 0.0,
				"equipo_local": true, "rol": "DC"}],
			"pelota": {"x": float(i) * 2.0, "y": 0.0, "z": 0.0,
				"poseedor_id": 1, "es_pase": false, "es_remate": false},
			"acciones": [{"clave": 2, "accion": "barrida"},
				{"clave": 1, "accion": "cae"}] if i == 1 else [],
			"corte": i == 1,
			"reubicacion": i == 1 and reubicacion,
		})
	return lista
