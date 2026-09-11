extends SceneTree

func _init() -> void:
	var hoja := Image.create(8 * 128, 10 * 128, false, Image.FORMAT_RGBA8)
	hoja.fill(Color("315b36"))
	for i in range(64):
		var img := AtlasJugadores.textura(i, Color("156ddd"), Color.WHITE, Color("583719")).get_image()
		img.resize(128, 128, Image.INTERPOLATE_NEAREST)
		hoja.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i((i % 8) * 128, (i / 8) * 128))
	for estilo in range(4):
		for dir in range(2):
			var img := AtlasJugadores.textura(24 + dir, Color("e44847"), Color("25364a"), Color("583719"), false, 10, estilo).get_image()
			img.resize(128, 128, Image.INTERPOLATE_NEAREST)
			hoja.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i((estilo * 2 + dir) * 128, 8 * 128))
	for i in range(8):
		var img := SpritesPartido.pelota(i).get_image()
		img.resize(64, 64, Image.INTERPOLATE_NEAREST)
		hoja.blend_rect(img, Rect2i(0, 0, 64, 64), Vector2i(i * 128 + 32, 9 * 128 + 32))
	hoja.save_png("res://assets/partido/vista_previa.png")
	print("OK: assets/partido/vista_previa.png")
	quit()
