extends SceneTree

func _init() -> void:
	assert(AtlasJugadores.PEINADOS.size() == 22, "Deben existir 22 peinados")
	assert(SpritesPartido.PALOMITA_PEINADOS == AtlasJugadores.PEINADOS,
		"La palomita debe cubrir todos los peinados")
	assert(SpritesPartido.TONOS_PELO.size() == 7, "Deben existir 7 tonos de pelo")
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
	for grupo in [
		{"nombre": "Atajada", "indices": range(76, 80)},
		{"nombre": "Saque de meta", "indices": range(80, 84)},
	]:
		for indice in grupo["indices"]:
			var base := AtlasJugadores.textura(indice, Color("2b74d9"), Color("17202b"),
				Color("6a3b1e"), false, 0, 0).get_image()
			var peinados_distintos := 0
			for estilo in range(1, AtlasJugadores.PEINADOS.size()):
				var variante := AtlasJugadores.textura(indice, Color("2b74d9"), Color("17202b"),
					Color("6a3b1e"), false, 0, estilo).get_image()
				if variante.get_data() != base.get_data():
					peinados_distintos += 1
			assert(peinados_distintos >= 4,
				"%s sin peinados suficientes: cuadro %d" % [grupo["nombre"], indice])
	var peinados_palomita := {}
	for estilo in range(SpritesPartido.PALOMITA_PEINADOS.size()):
		var cuadros_palomita := {}
		for frame in range(SpritesPartido.CUADROS_PALOMITA):
			var palomita := SpritesPartido.palomita_png(Color("2b74d9"), Color.WHITE,
				frame, false, Color("6a3b1e"), estilo, 9).get_image()
			assert(palomita.get_size() == Vector2i(64, 64),
				"Tamano de palomita: %d/%d" % [estilo, frame])
			assert(palomita.get_used_rect().has_area(),
				"PNG de palomita vacio: %d/%d" % [estilo, frame])
			cuadros_palomita[hash(palomita.get_data())] = true
			if frame == 0:
				peinados_palomita[hash(palomita.get_data())] = true
			# El espejo se compara sin dorsal: el numero se estampa despues de
			# espejar para que se lea derecho, asi que con dorsal nunca da igual.
			var sin_dorsal := SpritesPartido.palomita_png(Color("2b74d9"), Color.WHITE,
				frame, false, Color("6a3b1e"), estilo, 0).get_image()
			var palomita_espejo := SpritesPartido.palomita_png(Color("2b74d9"), Color.WHITE,
				frame, true, Color("6a3b1e"), estilo, 0).get_image()
			sin_dorsal.flip_x()
			assert(sin_dorsal.get_data() == palomita_espejo.get_data(),
				"Espejo roto en palomita: %d/%d" % [estilo, frame])
		assert(cuadros_palomita.size() == SpritesPartido.CUADROS_PALOMITA,
			"Palomita repite o pierde PNG: %d" % estilo)
	assert(peinados_palomita.size() == SpritesPartido.PALOMITA_PEINADOS.size(),
		"Palomita repite peinados")
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
	# Todos los regates usan las poses exactas de cada atlas preparado.
	# Comprobar el producto completo evita que una fase o un gesto vuelva
	# silenciosamente al peinado base.
	var color_camiseta := Color("d94141")
	var color_short := Color("17202b")
	var color_pelo := Color("6a3b1e")
	for tipo in MotorEspacial.REGATE_ACCIONES:
		var clip: Array = SpritesPartido.CLIPS_REGATE_ATLAS[tipo]
		var espejos_locales: Array = SpritesPartido.ESPEJOS_REGATE_ATLAS.get(tipo, [])
		for estilo in range(AtlasJugadores.PEINADOS.size()):
			for fase in range(clip.size()):
				var espejo_local := not espejos_locales.is_empty() and bool(espejos_locales[fase])
				var esperado := AtlasJugadores.textura(int(clip[fase]), color_camiseta,
					color_short, color_pelo, espejo_local, 9, estilo).get_image()
				var recibido := SpritesPartido.regate_png(tipo, fase, false,
					color_camiseta, color_short, color_pelo, estilo, 9).get_image()
				assert(recibido.get_data() == esperado.get_data(),
					"Regate cambia peinado: %s/%s/%d" % [tipo, AtlasJugadores.PEINADOS[estilo], fase])
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
