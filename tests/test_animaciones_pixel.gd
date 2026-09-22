extends SceneTree

func _init() -> void:
	var vista := VistaPartido.new()
	for accion in ["bloquea", "cae", "lesionado", "chilena", "volea", "barrida", "festeja"]:
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
	vista.fotogramas = []
	for i in range(12):
		vista.fotogramas.append({"acciones": []})
	vista.fotogramas[0] = {"acciones": [{"clave": 7, "accion": "regate_croqueta"}]}
	vista.fotogramas[2] = {"acciones": [{"clave": 7, "accion": "control_pie"}]}
	var gesto_viejo := vista._acciones_activas(2)
	assert(str(gesto_viejo[7]["accion"]) == "regate_croqueta",
		"Un control viejo no debe pisar un regate activo")
	for tipo in MotorEspacial.REGATE_ACCIONES:
		var cuadros_regate := SpritesPartido.cuadros_regate(tipo)
		assert(VistaPartido.DURACION_ACCION["regate_" + tipo] == MotorEspacial.duracion_regate(tipo),
			"Motor y vista terminan el regate en momentos distintos: " + tipo)
		var distintos := {}
		for fase in range(cuadros_regate):
			var cuadro_fase := SpritesPartido.regate_png(tipo, fase, false, Color("d94141")).get_image()
			distintos[hash(cuadro_fase.get_data())] = true
			assert(cuadro_fase.get_used_rect().size != Vector2i.ZERO,
				"Cuadro de regate transparente: %s/%d" % [tipo, fase])
		assert(distintos.size() >= 4, "Regate repite un dibujo de respaldo: " + tipo)
		var cuadro_base := SpritesPartido.regate_png(tipo, 0, false, Color("d94141")).get_image()
		var espejo := SpritesPartido.regate_png(tipo, 0, true, Color("d94141")).get_image()
		assert(cuadro_base.get_width() == 64 and cuadro_base.get_height() == 64, "Tamaño de regate: " + tipo)
		assert(cuadro_base.get_data() != espejo.get_data(), "Espejo de regate vacío: " + tipo)
	var inicio_croqueta := VistaPartido._trayectoria_regate("croqueta", 0.0, Vector2.RIGHT)
	var cruce_croqueta := VistaPartido._trayectoria_regate("croqueta", 0.5, Vector2.RIGHT)
	var salida_croqueta := VistaPartido._trayectoria_regate("croqueta", 1.0, Vector2.RIGHT)
	assert(float(inicio_croqueta["offset"].y) > 0.0,
		"La pelota de croqueta no arranca en el primer pie")
	assert(float(cruce_croqueta["offset"].y) < float(inicio_croqueta["offset"].y),
		"La pelota de croqueta no cruza el cuerpo")
	assert(float(salida_croqueta["offset"].y) < 0.0,
		"La pelota de croqueta no llega al segundo pie")
	assert(float(salida_croqueta["offset"].x) > float(cruce_croqueta["offset"].x),
		"La pelota de croqueta no acompana la salida")
	vista.free()
	print("OK: duraci?n, recuperaci?n y espejos de animaciones pixel")
	quit()
