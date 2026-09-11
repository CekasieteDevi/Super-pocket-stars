extends SceneTree

func _init() -> void:
	var tiempos: Array[int] = []
	var hashes := {}
	var inicio := Time.get_ticks_usec()
	for estilo in range(4):
		for cuadro in range(64):
			var t := Time.get_ticks_usec()
			var tex := AtlasJugadores.textura(cuadro, Color.RED, Color.WHITE, Color.SADDLE_BROWN, false, 10, estilo)
			tiempos.append(Time.get_ticks_usec() - t)
			var sha := HashingContext.new()
			sha.start(HashingContext.HASH_SHA256)
			sha.update(tex.get_image().get_data())
			hashes["%d_%d" % [estilo, cuadro]] = sha.finish().hex_encode()
	var total := Time.get_ticks_usec() - inicio
	tiempos.sort()
	print("ATLAS frio: total %.1f ms, p95 %.2f ms, max %.2f ms" % [total / 1000.0, tiempos[243] / 1000.0, tiempos[-1] / 1000.0])
	var ruta := "res://tests/fixtures/atlas_rgba_sha256.json"
	var antes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	assert(antes == hashes, "La optimizacion cambio pixeles")
	print("OK: 256 cuadros identicos al original")
	quit()
