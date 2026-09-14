extends SceneTree

func _init() -> void:
	call_deferred("_probar")

func _probar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	var estado := MotorEspacial.crear_estado(Team.generar("Local", rng), Team.generar("Visita", rng, 1000), rng)
	estado["con_fotogramas"] = true
	var campo: Array[int] = []
	for id in estado["jugadores"]:
		if estado["jugadores"][id]["rol"] != "ARQ" and estado["jugadores"][id]["equipo_local"]:
			campo.append(id)
	var clave := campo[0]
	var receptor: Dictionary = estado["jugadores"][clave]
	receptor["pos"] = Vector2.ZERO
	receptor["orientacion"] = Vector2.LEFT
	var pelota: Dictionary = estado["pelota"]
	for caso in [[0.0, ""], [0.8, "control_pie"], [3.5, "pecho"]]:
		estado["acciones_tick"] = []
		pelota["en_vuelo"] = true
		pelota["es_remate"] = false
		pelota["altura_max"] = caso[0]
		var semilla_antes := rng.state
		MotorEspacial._entregar_pelota(estado, clave)
		assert(rng.state == semilla_antes, "La animacion no consume RNG")
		assert(pelota["altura_max"] == 0.0)
		if caso[1] == "":
			assert(estado["acciones_tick"].is_empty())
		else:
			assert(estado["acciones_tick"][-1]["accion"] == caso[1])
	var jugador := MotorEspacial._dict_jugador(estado, estado["home"], receptor["jugador_id"])
	for caso in [[Vector2(5, 0), false, "taco"], [Vector2(-5, 0), false, "patea"], [Vector2(20, 0), false, "patea"], [Vector2(5, 0), true, "patea"]]:
		estado["acciones_tick"] = []
		estado["jugadores"][campo[1]]["pos"] = caso[0]
		MotorEspacial._lanzar_pase(estado, receptor, campo[1], jugador, null, caso[1])
		assert(estado["acciones_tick"][-1]["accion"] == caso[2])
	# Recorrido completo de cada gesto, ambos espejos, pausa y salto hacia atras.
	for direccion in [Vector2.LEFT, Vector2.RIGHT]:
		receptor["orientacion"] = direccion
		for accion in ["control_pie", "volea", "taco", "amague_centro"]:
			estado["fotogramas"] = []
			pelota["poseedor_id"] = clave if accion == "control_pie" else -1
			for tick in range(6):
				estado["acciones_tick"] = [{"clave": clave, "accion": accion}] if tick == 0 else []
				MotorEspacial._push_fotograma(estado)
			var vista := VistaPartido.new()
			root.add_child(vista)
			vista.iniciar(estado["fotogramas"], Color.RED, Color.BLUE)
			vista.set_process(false)
			var cache_antes := AtlasJugadores._cache.size()
			for paso in [0, 1, 3, 5, 7, 9, 0]:
				vista._mostrar(paso / 4, float(paso % 4) / 4.0)
				var balon: Dictionary = vista.vista.entidades[-1]
				if accion == "control_pie" and paso < 8:
					assert(balon["anclada"])
					assert(signf(balon["anclaje_px"].x) == signf(direccion.x))
				else:
					assert(not balon["anclada"])
				assert(AtlasJugadores._cache.size() == cache_antes)
			vista.free()
	for estilo in range(AtlasJugadores.PEINADOS.size()):
		for accion in ["volea", "control_pie", "taco"]:
			var distintos := {}
			for cuadro in AtlasJugadores.CLIPS[accion]:
				var img := AtlasJugadores.textura(cuadro, Color.RED, Color.WHITE, Color.SADDLE_BROWN, false, 0, estilo).get_image()
				distintos[hash(img.get_data())] = true
				assert(img.get_used_rect().end.y <= 58, "Pies fuera del apoyo")
			assert(distintos.size() == 4, "Cuatro poses propias por gesto")
	print("OK: control a distintas alturas, taco contextual, espejos, busqueda temporal y 132 poses nuevas")
	quit()
