extends SceneTree

func _init() -> void:
	call_deferred("_probar")

func _probar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	var resultado := MotorEspacial.simular(Team.generar("Local", rng), Team.generar("Visita", rng, 1000), rng, true)
	var vista := VistaPartido.new()
	root.add_child(vista)
	var inicio := Time.get_ticks_usec()
	vista.iniciar(resultado["fotogramas"], Color.RED, Color.BLUE)
	var preparacion := Time.get_ticks_usec() - inicio
	var texturas_preparadas := AtlasJugadores._cache.size()
	var maximo_us := 0
	vista.set_process(false)
	var acciones := {}
	for i in range(vista.fotogramas.size()):
		var inicio_frame := Time.get_ticks_usec()
		vista._mostrar(i, float(i % 4) / 4.0)
		for ent in vista.vista.entidades:
			if ent["tipo"] != "jugador":
				continue
			var accion: String = ent["accion"]
			if not accion.is_empty():
				acciones[accion] = true
			var indice := AtlasJugadores.cuadro(accion, ent["fase_animacion"], ent["direccion"],
				ent["pose"] in [SpritesPartido.CORRE_A, SpritesPartido.CORRE_B], ent["arquero"])
			assert(indice >= 0 and indice < AtlasJugadores.TOTAL_CUADROS)
			var espejo := bool(ent.get("espejo", false)) if accion == "vuela" else int(ent["direccion"]) in [5, 6, 7]
			assert(AtlasJugadores.textura(indice, ent["color"], ent["color_short"], ent["color_pelo"], espejo, ent["numero"], ent["pelo"]) != null)
		maximo_us = maxi(maximo_us, Time.get_ticks_usec() - inicio_frame)
		assert(AtlasJugadores._cache.size() == texturas_preparadas, "Se crea textura durante la reproduccion")
	print("OK: partido completo, %d fotogramas, acciones %s" % [vista.fotogramas.size(), acciones.keys()])
	print("Preparacion %.1f ms; CPU max/frame %.2f ms; %d texturas, sin creaciones durante el partido" % [preparacion / 1000.0, maximo_us / 1000.0, texturas_preparadas])
	vista.free()
	quit()
