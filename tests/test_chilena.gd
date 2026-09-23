extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	_test_requisitos()
	_test_centros()
	_test_png()
	_test_laboratorio_chilena()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _test_requisitos() -> void:
	var jugador := {"atributos": MotorEspacial.REQUISITOS_CHILENA.duplicate()}
	_comprobar(MotorEspacial.puede_hacer_chilena(jugador), "umbrales inclusivos")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for atributo in MotorEspacial.REQUISITOS_CHILENA:
		var insuficiente: Dictionary = jugador.duplicate(true)
		insuficiente["atributos"][atributo] -= 1.0
		_comprobar(not MotorEspacial.puede_hacer_chilena(insuficiente), "requisito obligatorio: " + atributo)
		var antes := rng.state
		_comprobar(not MotorEspacial.remata_de_chilena(insuficiente, Vector2(7, 0), Vector2.ZERO, rng), "sin sorteo si falta " + atributo)
		_comprobar(antes == rng.state, "rechazo no consume azar")
	_comprobar(not MotorEspacial.puede_hacer_chilena({}), "atributos ausentes no habilitan")
	_comprobar(not MotorEspacial.remata_de_chilena(jugador, Vector2(9, 0), Vector2.ZERO, rng), "limite de nueve metros")


func _test_centros() -> void:
	for local in [true, false]:
		for caso in ["habilitado", "volea", "agilidad", "salto", "lejos", "medio"]:
			var chilenas := 0
			for semilla in range(80):
				var escena := _escena(local, 12.0 if caso == "lejos" else 7.0, 1.0)
				var estado: Dictionary = escena["estado"]
				var attrs: Dictionary = escena["jugador"]["atributos"]
				attrs["cabezazo"] = 1.0
				for atributo in MotorEspacial.REQUISITOS_CHILENA:
					attrs[atributo] = 95.0
				if MotorEspacial.REQUISITOS_CHILENA.has(caso):
					attrs[caso] = float(MotorEspacial.REQUISITOS_CHILENA[caso]) - 1.0
				estado["rng"].seed = semilla
				estado["con_fotogramas"] = true
				estado["acciones_tick"] = []
				estado["forzar_centro"] = "gana"
				estado["pelota"]["tipo_centro"] = "medio" if caso == "medio" else MotorEspacial.TIPO_CENTRO_ALTO
				MotorEspacial._resolver_centro(estado, escena["poseedor"]["pos"], local, 1)
				for accion in estado["acciones_tick"]:
					if accion["accion"] == "chilena":
						chilenas += 1
			_comprobar(chilenas > 0 if caso == "habilitado" else chilenas == 0, "centro %s local=%s" % [caso, local])


func _test_png() -> void:
	for estilo in range(AtlasJugadores.PEINADOS.size()):
		for espejo in [false, true]:
			var distintos := {}
			for indice in AtlasJugadores.CLIPS["chilena"]:
				var img := AtlasJugadores.textura(indice, Color.RED, Color.WHITE, Color.SADDLE_BROWN, espejo, 0, estilo).get_image()
				_comprobar(img.get_used_rect().has_area(), "pose %d: %s" % [indice, AtlasJugadores.PEINADOS[estilo]])
				distintos[hash(img.get_data())] = true
			_comprobar(distintos.size() == 6, "seis poses distintas, espejo=%s" % espejo)


func _test_laboratorio_chilena() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng)
	var visita := Team.generar("Visita", rng, 1000)
	var resultado := Laboratorio.generar("chilena", casa, visita, rng)
	var chilenas := 0
	for cuadro in resultado["fotogramas"]:
		for accion in cuadro.get("acciones", []):
			if accion["accion"] == "chilena":
				chilenas += 1
	_comprobar(chilenas == 1 and resultado["goles_local"] == 1, "laboratorio: centro, chilena y gol")
