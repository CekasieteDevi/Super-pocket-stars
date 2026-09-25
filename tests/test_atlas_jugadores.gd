extends SceneTree

func _init() -> void:
	assert(AtlasJugadores.cuadro("", 7.9, 2, true) == 7)
	assert(AtlasJugadores.cuadro("", 8.0, 2, true) == 0)
	assert(AtlasJugadores.cuadro("", 3.0, 4, true) == 19)
	assert(AtlasJugadores.cuadro("", 0.0, 4, false) == 25)
	for accion in AtlasJugadores.CLIPS:
		var clip: Array = AtlasJugadores.CLIPS[accion]
		assert(AtlasJugadores.cuadro(accion, 0.0, 0, false) == clip[0])
		assert(AtlasJugadores.cuadro(accion, 1.0, 0, false) == clip[-1])
	for estilo in range(AtlasJugadores.PEINADOS.size()):
		for i in range(AtlasJugadores.TOTAL_CUADROS):
			var tex := AtlasJugadores.textura(i, Color.RED, Color.WHITE, Color.SADDLE_BROWN, false, 0, estilo)
			var img := tex.get_image()
			assert(img.get_size() == Vector2i(64, 64))
			assert(img.get_pixel(0, 0).a == 0.0, "Fondo opaco en cuadro %d" % i)
			assert(img.get_used_rect().get_area() > 80, "Cuadro vacío: %d" % i)
			var referencia := AtlasJugadores.textura(i, Color.RED, Color.WHITE,
				Color.SADDLE_BROWN, false, 0, 0).get_image()
			assert(img.get_used_rect().size.y == referencia.get_used_rect().size.y,
				"Jugador de distinto tamano: %s/%d" % [AtlasJugadores.PEINADOS[estilo], i])
			var espejo := AtlasJugadores.textura(i, Color.RED, Color.WHITE, Color.SADDLE_BROWN, true, 0, estilo).get_image()
			img.flip_x()
			assert(img.get_data() == espejo.get_data())
	var pelotas := {}
	for i in range(12):
		var img := SpritesPartido.pelota(i).get_image()
		assert(img.get_size() == Vector2i(16, 16))
		assert(img.get_pixel(0, 0).a == 0.0)
		pelotas[hash(img.get_data())] = true
	assert(pelotas.size() > 6, "La pelota debe girar")
	assert(SpritesPartido.pelota(12) == SpritesPartido.pelota(0))
	print("OK: %d cuadros, transparencia, espejos y secuencias" % (AtlasJugadores.TOTAL_CUADROS * AtlasJugadores.PEINADOS.size()))
	quit()
