extends SceneTree

func _init() -> void:
	assert(AtlasJugadores.PEINADOS.size() == 22, "Deben existir 22 peinados")
	assert(SpritesPartido.PALOMITA_PEINADOS == AtlasJugadores.PEINADOS,
		"La palomita debe cubrir todos los peinados")
	assert(SpritesPartido.TONOS_PELO.size() == 7, "Deben existir 7 tonos de pelo")
	var color_prueba_camiseta := Color("d84040")
	var color_prueba_pelo := Color("397d35")
	var parado_color := AtlasJugadores.textura(24, color_prueba_camiseta, Color.WHITE,
		color_prueba_pelo).get_image()
	var palomita_color := SpritesPartido.palomita_png(color_prueba_camiseta, Color.WHITE,
		0, false, color_prueba_pelo).get_image()
	assert(absf(_brillo_tinte(parado_color, 0) - _brillo_tinte(palomita_color, 0)) < 0.12,
		"La camiseta de la palomita debe conservar el color del jugador")
	assert(absf(_brillo_tinte(parado_color, 1) - _brillo_tinte(palomita_color, 1)) < 0.12,
		"El pelo de la palomita debe conservar el color del jugador")
	for accion_misma_fuente in ["control_pie", "saque_arco"]:
		for indice in AtlasJugadores.CLIPS[accion_misma_fuente]:
			assert(int(indice) < 64,
				"%s debe usar la misma fuente artistica que correr y quedar parado" % accion_misma_fuente)
	for indice in AtlasJugadores.CLIPS["saque_arco"]:
		var base_saque := AtlasJugadores.textura(indice, Color.RED, Color.BLUE,
			Color.SADDLE_BROWN).get_image()
		var con_guantes := AtlasJugadores.textura_saque_arco(indice, Color.RED,
			Color.BLUE, Color.SADDLE_BROWN).get_image()
		assert(con_guantes.get_data() != base_saque.get_data(),
			"El saque de arco debe conservar los guantes")
		var espejo_guantes := AtlasJugadores.textura_saque_arco(indice, Color.RED,
			Color.BLUE, Color.SADDLE_BROWN, true).get_image()
		con_guantes.flip_x()
		assert(con_guantes.get_data() == espejo_guantes.get_data(),
			"Los guantes del saque deben espejarse con el golero")
	assert(AtlasJugadores.estilo_de(1) == 2,
		"La rotacion nueva debe actualizar los peinados existentes")
	var jugadores_con_pelo_azul := 0
	var jugadores_con_pelo_blanco := 0
	for jugador_id in range(1, 30001):
		if SpritesPartido.tono_pelo_de(jugador_id) == SpritesPartido.TONOS_PELO[SpritesPartido.INDICE_PELO_AZUL]:
			jugadores_con_pelo_azul += 1
		if SpritesPartido.tono_pelo_de(jugador_id) == SpritesPartido.TONOS_PELO[SpritesPartido.INDICE_PELO_BLANCO]:
			jugadores_con_pelo_blanco += 1
	assert(jugadores_con_pelo_azul == 100,
		"El pelo azul debe aparecer en uno de cada trescientos jugadores")
	assert(jugadores_con_pelo_blanco == 100,
		"El pelo blanco debe aparecer en uno de cada trescientos jugadores")
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
	var altos_palomita := []
	for frame in range(SpritesPartido.CUADROS_PALOMITA):
		altos_palomita.append(SpritesPartido.palomita_png(Color("2b74d9"), Color.WHITE,
			frame, false, Color("6a3b1e"), 0, 0).get_image().get_used_rect().size.y)
	for estilo in range(SpritesPartido.PALOMITA_PEINADOS.size()):
		var cuadros_palomita := {}
		for frame in range(SpritesPartido.CUADROS_PALOMITA):
			var palomita := SpritesPartido.palomita_png(Color("2b74d9"), Color.WHITE,
				frame, false, Color("6a3b1e"), estilo, 9).get_image()
			assert(palomita.get_size() == Vector2i(64, 64),
				"Tamano de palomita: %d/%d" % [estilo, frame])
			assert(palomita.get_used_rect().has_area(),
				"PNG de palomita vacio: %d/%d" % [estilo, frame])
			assert(_componentes_pintados(palomita) == 1,
				"Palomita con manchas aisladas: %s/%d" % [SpritesPartido.PALOMITA_PEINADOS[estilo], frame])
			# Tolera 2 px: en el cuadro 4 el pelo asoma arriba o abajo del
			# cuerpo según el peinado (afro 40, puntas 39, atado 41). Un
			# cuerpo de otra escala cambia mucho más que eso.
			assert(absi(palomita.get_used_rect().size.y - int(altos_palomita[frame])) <= 2,
				"Palomita de distinto tamano: %s/%d" % [SpritesPartido.PALOMITA_PEINADOS[estilo], frame])
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


func _brillo_tinte(img: Image, canal: int) -> float:
	var suma := 0.0
	var cantidad := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			var coincide := c.r > c.g * 1.5 and c.r > c.b * 1.5 if canal == 0 else \
				c.g > c.r * 1.2 and c.g > c.b * 1.2
			if c.a > 0.5 and coincide:
				suma += c.v
				cantidad += 1
	assert(cantidad > 10, "La prueba debe encontrar suficientes pixeles teñidos")
	return suma / float(cantidad)


func _componentes_pintados(img: Image) -> int:
	var visitado := PackedByteArray()
	visitado.resize(img.get_width() * img.get_height())
	var cantidad := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var inicio := y * img.get_width() + x
			if visitado[inicio] != 0 or img.get_pixel(x, y).a <= 0.0:
				continue
			cantidad += 1
			var cola := [inicio]
			visitado[inicio] = 1
			var cursor := 0
			while cursor < cola.size():
				var actual: int = cola[cursor]
				cursor += 1
				var ax := actual % img.get_width()
				var ay := actual / img.get_width()
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := ax + dx
						var ny := ay + dy
						if (dx == 0 and dy == 0) or nx < 0 or nx >= img.get_width() \
							or ny < 0 or ny >= img.get_height():
							continue
						var vecino := ny * img.get_width() + nx
						if visitado[vecino] == 0 and img.get_pixel(nx, ny).a > 0.0:
							visitado[vecino] = 1
							cola.append(vecino)
	return cantidad
