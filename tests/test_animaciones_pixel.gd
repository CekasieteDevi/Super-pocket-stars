extends SceneTree

func _init() -> void:
	var vista := VistaPartido.new()
	for accion in ["bloquea", "cae", "chilena", "volea", "barrida", "festeja"]:
		vista.fotogramas = []
		var duracion: int = VistaPartido.DURACION_ACCION[accion]
		for i in range(duracion + 1):
			vista.fotogramas.append({"acciones": [{"clave": 7, "accion": accion}] if i == 0 else []})
		assert(vista._acciones_activas(0).has(7), "Acci?n sin pose: " + accion)
		assert(vista._acciones_activas(duracion).is_empty(), "Acci?n no termina: " + accion)
		if accion in ["bloquea", "cae", "chilena", "barrida"]:
			assert(vista._acciones_activas(duracion - 1)[7]["pose"] == SpritesPartido.RECUPERA)
	for pose in SpritesPartido.POSES_ESPECIALES:
		var derecha := SpritesPartido.jugador(Color.RED, SpritesPartido.DERECHA, pose).get_image()
		var izquierda := SpritesPartido.jugador(Color.RED, SpritesPartido.IZQUIERDA, pose).get_image()
		derecha.flip_x()
		assert(derecha.get_data() == izquierda.get_data(), "Espejo incorrecto: " + pose)
	vista.free()
	print("OK: duraci?n, recuperaci?n y espejos de animaciones pixel")
	quit()
