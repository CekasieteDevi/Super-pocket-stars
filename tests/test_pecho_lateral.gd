extends SceneTree

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 441
	var estado := MotorEspacial.crear_estado(Team.generar("Local", rng), Team.generar("Visita", rng, 1000), rng)
	estado["con_fotogramas"] = true
	var clave := -1
	for id in estado["jugadores"]:
		if estado["jugadores"][id]["rol"] != "ARQ":
			clave = int(id)
			break
	estado["pelota"]["en_vuelo"] = true
	estado["pelota"]["altura_max"] = 3.5
	MotorEspacial._entregar_pelota(estado, clave)
	assert(estado["acciones_tick"][-1]["accion"] == "pecho")
	assert(estado["pelota"]["altura_max"] == 0.0, "No heredar la altura del vuelo anterior")
	estado["acciones_tick"] = []
	estado["pelota"]["en_vuelo"] = true
	estado["pelota"]["altura_max"] = 0.0
	MotorEspacial._entregar_pelota(estado, clave)
	assert(estado["acciones_tick"].is_empty(), "Pase raso no se controla con el pecho")
	MotorEspacial._lateral(estado, Vector2(0, MotorEspacial.MEDIO_ANCHO), true)
	assert(estado["balon_parado"]["con_manos"])
	MotorEspacial._ejecutar_balon_parado(estado)
	assert(estado["acciones_tick"][-1]["accion"] == "lateral_manos")
	assert(estado["pelota"]["en_vuelo"])
	assert(estado["pelota"]["altura_salida"] == 2.0)
	assert(estado["pelota"]["z"] == 2.0)
	MotorEspacial._avanzar_pelota(estado)
	assert(float(estado["pelota"]["z"]) >= 0.0)
	print("OK: pecho sólo en balones altos; lateral con manos y salida elevada")
	quit()
