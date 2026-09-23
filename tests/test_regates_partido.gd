extends SceneTree

## Integra ticks del motor con la vista del partido, sin Laboratorio.
func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	for tipo in MotorEspacial.REGATE_ACCIONES:
		for rumbo in [Vector2.RIGHT, Vector2.LEFT, Vector2(0.2, -1).normalized()]:
			await _probar_regate(tipo, rumbo)
	print("OK: cinco regates, ambos lados y diagonal, posiciones y pelota continuas")
	quit()


func _probar_regate(tipo: String, rumbo: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260922
	var local := Team.generar("Local", rng)
	var visita := Team.generar("Visita", rng, 1000)
	local.reset_partido()
	visita.reset_partido()
	var estado := MotorEspacial.crear_estado(local, visita, rng)
	estado["con_fotogramas"] = true
	estado["detenido"] = 0
	var clave := -1
	for id in estado["jugadores"]:
		var j: Dictionary = estado["jugadores"][id]
		if j["equipo_local"] and j["rol"] == "DC":
			clave = int(id)
	assert(clave != -1)
	var ejecutor: Dictionary = estado["jugadores"][clave]
	ejecutor["pos"] = Vector2.ZERO
	ejecutor["orientacion"] = rumbo
	estado["pelota"]["poseedor_id"] = clave
	estado["pelota"]["pos"] = Vector2.ZERO
	MotorEspacial._marcar_regate(estado, ejecutor, tipo)
	MotorEspacial._accion(estado, clave, "regate_" + tipo)
	# El enganche cambia el rumbo normal despues de marcar el regate.
	# Su trayectoria y el sprite deben conservar el rumbo original.
	ejecutor["orientacion"] = -rumbo
	MotorEspacial._push_fotograma(estado)
	var duracion := MotorEspacial.duracion_regate(tipo)
	for edad in range(1, duracion):
		estado["tick"] = edad
		MotorEspacial._tick(estado, true)
	# Salida real, incluyendo la siguiente decision del poseedor.
	for edad in range(duracion, duracion + 2):
		estado["tick"] = edad
		MotorEspacial._tick(estado, true)
	var lista: Array = estado["fotogramas"]
	var original := hash(var_to_bytes(lista))
	var vista := VistaPartido.new()
	root.add_child(vista)
	vista.iniciar(lista, Color.RED, Color.BLUE)
	vista.set_process(false)
	var indice := -1
	for i in range(lista[0]["jugadores"].size()):
		if int(lista[0]["jugadores"][i]["id"]) == clave:
			indice = i
	assert(indice >= 0)
	var cuadros := {}
	var capturas_regate := {}
	for i in range(duracion):
		for fraccion in [0.0, 0.25, 0.5, 0.75, 0.9999]:
			vista._mostrar(i, fraccion)
			var ent: Dictionary = vista.vista.entidades[indice]
			var a: Dictionary = lista[i]["jugadores"][indice]
			var b: Dictionary = lista[i + 1]["jugadores"][indice]
			var esperada := Vector2(a["x"], a["y"]).lerp(Vector2(b["x"], b["y"]), fraccion)
			assert((ent["pos"] as Vector2).distance_to(esperada) < 0.0001,
				"La vista cambia la trayectoria grabada: " + tipo)
			assert(ent["accion"] == "regate_" + tipo)
			assert(float(ent["z"]) == 0.0, "Un regate no salta")
			assert((ent["regate_orientacion"] as Vector2).is_equal_approx(rumbo))
			assert(bool(ent["regate_espejo"]) == (ProyeccionPartido.direccion_pantalla(rumbo).x < 0.0))
			var fase := float(ent["fase_animacion"])
			var cuadro := mini(SpritesPartido.cuadros_regate(tipo) - 1,
				int(clampf(fase, 0.0, 0.999) * SpritesPartido.cuadros_regate(tipo)))
			cuadros[cuadro] = true
			assert(SpritesPartido.regate_png(tipo, cuadro, ent["regate_espejo"], ent["color"],
				ent["color_short"], ent["color_pelo"], int(ent["pelo"]), int(ent["numero"])) != null)
			if "capturar" in OS.get_cmdline_user_args():
				vista._seguir_camara(i, 0.0625)
				await process_frame
				await RenderingServer.frame_post_draw
				if rumbo == Vector2.RIGHT and not capturas_regate.has(cuadro):
					root.get_texture().get_image().save_png(
						"res://scratch/verificado_%s_fase_%02d.png" % [tipo, cuadro])
					capturas_regate[cuadro] = true
				if rumbo == Vector2.RIGHT and i == duracion / 2 and fraccion == 0.0:
					root.get_texture().get_image().save_png("res://scratch/verificado_%s.png" % tipo)
					# Mismo fotograma de partido simulado. Cambia sólo la
					# identidad visual para revisar los once peinados.
					var pelo_original := int(ent["pelo"])
					var color_pelo_original: Color = ent["color_pelo"]
					for estilo in range(AtlasJugadores.PEINADOS.size()):
						vista.vista.entidades[indice]["pelo"] = estilo
						vista.vista.entidades[indice]["color_pelo"] = SpritesPartido.tono_pelo_de(estilo)
						vista.vista.queue_redraw()
						await process_frame
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(
							"res://scratch/verificado_%s_%s.png" % [tipo, AtlasJugadores.PEINADOS[estilo]])
					vista.vista.entidades[indice]["pelo"] = pelo_original
					vista.vista.entidades[indice]["color_pelo"] = color_pelo_original
			if fraccion == 0.9999:
				var antes := _pelota(vista).duplicate()
				vista._mostrar(i + 1, 0.0)
				var despues := _pelota(vista)
				assert((antes["pos"] as Vector2).distance_to(despues["pos"]) < 0.01,
					"Salto de pelota entre ticks: " + tipo)
				assert(absf(float(antes["z"]) - float(despues["z"])) < 0.01)
	assert(cuadros.size() == SpritesPartido.cuadros_regate(tipo), "Faltan cuadros: " + tipo)
	if "capturar" in OS.get_cmdline_user_args() and rumbo == Vector2.RIGHT:
		assert(capturas_regate.size() == SpritesPartido.cuadros_regate(tipo),
			"La captura visual no cubrio todo el regate: " + tipo)
	assert(hash(var_to_bytes(lista)) == original, "Reproducir no debe modificar los fotogramas")
	vista.free()


func _pelota(vista: VistaPartido) -> Dictionary:
	for ent in vista.vista.entidades:
		if ent["tipo"] == "pelota":
			return ent
	assert(false, "Falta pelota durante el regate")
	return {}
