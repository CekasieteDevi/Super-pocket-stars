extends SceneTree

func _init() -> void:
	var hoja := Image.create(1024, AtlasJugadores.PEINADOS.size() * 64, false, Image.FORMAT_RGBA8)
	hoja.fill(Color("315b36"))
	for estilo in range(AtlasJugadores.PEINADOS.size()):
		for columna in range(16):
			var indice: int = [0, 3, 8, 12, 16, 20, 24, 25, 26, 32, 37, 41, 44, 48, 58, 62][columna]
			var img := AtlasJugadores.textura(indice, Color("3485cf"), Color.WHITE, Color("583719"), false, 10, estilo).get_image()
			hoja.blend_rect(img, Rect2i(0, 0, 64, 64), Vector2i(columna * 64, estilo * 64))
	assert(hoja.save_png("res://assets/partido/vista_previa_peinados.png") == OK)
	var acciones := Image.create(12 * 64, AtlasJugadores.PEINADOS.size() * 64, false, Image.FORMAT_RGBA8)
	acciones.fill(Color("315b36"))
	for estilo in range(AtlasJugadores.PEINADOS.size()):
		for cuadro in range(12):
			var img := AtlasJugadores.textura(64 + cuadro, Color("3485cf"), Color.WHITE, Color("583719"), false, 0, estilo).get_image()
			acciones.blend_rect(img, Rect2i(0, 0, 64, 64), Vector2i(cuadro * 64, estilo * 64))
	assert(acciones.save_png("res://assets/partido/vista_previa_acciones.png") == OK)
	var publico := TexturasEstadio.publico().get_image()
	assert(publico.get_size() == Vector2i(80, 80))
	publico.resize(640, 640, Image.INTERPOLATE_NEAREST)
	assert(publico.save_png("res://assets/partido/vista_previa_publico.png") == OK)
	call_deferred("_probar_grada")

func _probar_grada() -> void:
	var cancha := VistaCancha.new()
	cancha.size = Vector2(1280, 720)
	root.add_child(cancha)
	for emocion in [0.0, 1.0]:
		cancha.euforia = emocion
		cancha.queue_redraw()
		await process_frame
		await process_frame
	cancha.free()
	print("OK: vistas previas de %d peinados, acciones y publico" % AtlasJugadores.PEINADOS.size())
	quit()
