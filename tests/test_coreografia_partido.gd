extends SceneTree


func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	for local in [true, false]:
		for accion in CoreografiaPartido.PERFILES:
			_probar_contacto(str(accion), local)
	_probar_pase_desde_los_pies()
	_probar_rebotes()
	_probar_interrupciones()
	_probar_cortes()
	_probar_laboratorios()
	print("OK: entrada, contacto, salida, controles, rebotes, cortes y busqueda temporal")
	quit()


func _probar_contacto(accion: String, local: bool) -> void:
	var lista := _escena(accion, local)
	var original := hash(var_to_bytes(lista))
	var plan := CoreografiaPartido.new()
	plan.configurar(lista, VistaPartido.DURACION_ACCION)
	assert(plan.contactos.has(3), "Falta contacto de " + accion)
	var contacto := plan.pelota(3, 0.0)
	assert((contacto["pos"] as Vector2).is_equal_approx(Vector2.ZERO))
	var gesto: Dictionary = plan.gestos(3.0, {})[1]
	var antes: Dictionary = plan.gestos(2.9, {})[1]
	assert(float(antes["fase"]) <= float(gesto["fase"]))
	if accion in CoreografiaPartido.AEREAS:
		assert(float(contacto["z"]) > 1.5, "El balon debe contactar arriba: " + accion)
		assert(float(plan.pelota(2, 0.0)["z"]) > 0.8, "No bajar a los pies antes del toque")
		assert(float(antes["fase"]) > 0.0, "Preparacion antes de recibir")
		assert(CoreografiaPartido.salto(accion, float(gesto["fase"])) > 0.6)
	var cuadros_impacto := {"chilena": 37, "volea": 65, "cabecea": 34, "patea": 14, "taco": 74}
	if cuadros_impacto.has(accion):
		assert(AtlasJugadores.cuadro(accion, float(gesto["fase"]), 2, false) == cuadros_impacto[accion])
	if accion in ["pecho", "control_pie"]:
		assert(float(plan.pelota(4, 0.0)["z"]) < float(contacto["z"]), "Amortiguar hacia el suelo")
	else:
		if accion != "agarra":
			var despues := plan.pelota(3, 0.1)
			assert((despues["pos"] as Vector2).x * (1.0 if local else -1.0) > 0.0, "Salida despues del impacto")
	# Dos intervalos deben compartir exactamente el mismo extremo, tambien
	# cuando una muestra del motor ya habia avanzado la pelota varios metros.
	for i in range(1, lista.size()):
		_igual(plan.pelota(i - 1, 1.0), plan.pelota(i, 0.0))
	var guardado := plan.pelota(2, 0.75)
	for tiempo in [5.6, 0.0, 4.2, 3.0, 2.75]:
		plan.pelota(int(tiempo), fposmod(tiempo, 1.0))
	_igual(guardado, plan.pelota(2, 0.75))
	assert(hash(var_to_bytes(lista)) == original, "La reproduccion no modifica el partido")


## El motor graba el tick del pase con la pelota ya en viaje y el pateador
## corrido. La pelota tiene que seguir la recta del motor, en el piso, sin
## ir a buscar el pie dibujado.
func _probar_pase_desde_los_pies() -> void:
	var lista: Array = []
	for i in range(6):
		var con_pelota := i <= 2
		var pelota := Vector2(float(i), 0.0) if con_pelota else Vector2(2.0, 4.5 * float(i - 2))
		lista.append({"jugadores": [{"id": 1, "x": float(i), "y": 0.0,
			"equipo_local": true, "rol": "MC", "ox": 1.0, "oy": 0.0}],
			"pelota": {"x": pelota.x, "y": pelota.y, "z": 0.0,
				"poseedor_id": 1 if con_pelota else -1, "es_pase": not con_pelota},
			"acciones": [{"clave": 1, "accion": "patea"}] if i == 3 else [],
			"corte": false})
	var plan := CoreografiaPartido.new()
	plan.configurar(lista, VistaPartido.DURACION_ACCION)
	assert(plan.contactos.has(3), "Falta el pase")
	assert(is_equal_approx(float(plan.contactos[3]["golpe"]), 2.0), "El golpe va donde tenia la pelota")
	var gesto: Dictionary = plan.gestos(2.0, {})[1]
	assert(AtlasJugadores.cuadro("patea", float(gesto["fase"]), 2, false) == 14, "Impacto al salir la pelota")
	for paso in range(24):
		var tiempo := 2.0 + float(paso) / 8.0
		var balon := plan.pelota(int(tiempo), fposmod(tiempo, 1.0))
		assert(is_equal_approx((balon["pos"] as Vector2).x, 2.0), "El pase dobla")
		assert(is_zero_approx(float(balon["z"])), "El pase raso se levanta")
		assert((balon["offset_px"] as Vector2).is_zero_approx(), "El pase se corre de costado")


func _probar_rebotes() -> void:
	var lista := _escena("cabecea", true)
	lista[5]["acciones"] = [{"clave": 2, "accion": "volea"}]
	lista[5]["pelota"]["x"] = 7.0
	for f in lista:
		f["jugadores"].append({"id": 2, "x": 6.0, "y": 0.0, "ox": 1.0, "oy": 0.0,
			"equipo_local": true, "rol": "DC"})
	var plan := CoreografiaPartido.new()
	plan.configurar(lista, VistaPartido.DURACION_ACCION)
	assert(plan.contactos.size() == 2)
	assert(float(plan.pelota(4, 0.0)["z"]) > 1.0, "Rebote entre cabeza y volea sigue en el aire")
	assert((plan.pelota(5, 0.0)["pos"] as Vector2).is_equal_approx(Vector2(6, 0)))
	_igual(plan.pelota(4, 1.0), plan.pelota(5, 0.0))


func _probar_cortes() -> void:
	var lista := _escena("chilena", true)
	lista[3]["corte"] = true
	var plan := CoreografiaPartido.new()
	plan.configurar(lista, VistaPartido.DURACION_ACCION)
	assert(plan.gestos(2.9, {}).is_empty(), "No anticipar a traves de un corte")
	_igual(plan.pelota(2, 0.0), plan.pelota(2, 0.99))
	lista = _escena("chilena", true)
	for f in lista:
		f["acciones"] = []
	plan.configurar(lista, VistaPartido.DURACION_ACCION)
	assert(plan.contactos.is_empty(), "Limpiar plan al cambiar de partido")
	assert(not plan.pelota(3, 0.0)["corregida"])


func _probar_interrupciones() -> void:
	var lista := _escena("chilena", true)
	lista[4]["acciones"] = [{"clave": 1, "accion": "patea"}]
	var plan := CoreografiaPartido.new()
	plan.configurar(lista, VistaPartido.DURACION_ACCION)
	assert(plan.gestos(3.0, {})[1]["accion"] == "chilena", "Mostrar el impacto antes del siguiente armado")
	assert(plan.gestos(4.0, {})[1]["accion"] == "patea")
	assert(not plan.gestos(5.9, {}).has(1), "No resucitar una animacion interrumpida")


func _probar_laboratorios() -> void:
	for accion in ["chilena", "volea", "cabezazo", "palomita", "cadena_rebotes", "tiro_efecto"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2024
		var casa := Team.generar("Casa", rng)
		var visita := Team.generar("Visita", rng, 1000)
		var resultado := Laboratorio.generar(accion, casa, visita, rng)
		var original := hash(var_to_bytes(resultado))
		var vista := VistaPartido.new()
		root.add_child(vista)
		vista.iniciar(resultado["fotogramas"], Color.RED, Color.BLUE)
		vista.set_process(false)
		assert(not vista._coreografia.contactos.is_empty(), "Laboratorio sin contactos: " + accion)
		for indice in vista._coreografia.contactos:
			var c: Dictionary = vista._coreografia.contactos[indice]
			if str(c["accion"]) not in CoreografiaPartido.AEREAS:
				continue
			vista._mostrar(int(indice), 0.0)
			var balon: Dictionary = vista.vista.entidades[-1]
			assert(balon["tipo"] == "pelota")
			for ent in vista.vista.entidades:
				if ent["tipo"] != "jugador" or ent["accion"] != c["accion"]:
					continue
				if (ent["pos"] as Vector2).distance_to(c["pos"]) > 0.01:
					continue
				assert(float(balon["z"]) > float(ent["z"]) + 0.8)
				assert(is_equal_approx(float(ent["fase_animacion"]), float(c["impacto"])))
		assert(hash(var_to_bytes(resultado)) == original)
		vista.free()


func _igual(a: Dictionary, b: Dictionary) -> void:
	assert((a["pos"] as Vector2).is_equal_approx(b["pos"]), "Salto de posicion")
	assert(is_equal_approx(float(a["z"]), float(b["z"])), "Salto de altura")
	assert((a["offset_px"] as Vector2).is_equal_approx(b["offset_px"]), "Salto del punto de contacto")


func _escena(accion: String, local: bool) -> Array:
	var lista: Array = []
	var lado := 1.0 if local else -1.0
	var recepcion := accion in CoreografiaPartido.RECEPCIONES
	for i in range(8):
		var x := float(i - 3) * 2.0 * lado
		if i == 3:
			x = lado * 2.0 # Snapshot tomado despues de que el remate avanzo.
		if recepcion and i >= 3:
			x = 0.0
		lista.append({"jugadores": [{"id": 1, "x": 0.0, "y": 0.0,
			"equipo_local": local, "rol": "DC", "ox": lado, "oy": 0.0}],
			"pelota": {"x": x, "y": 0.0, "z": 2.0 if i < 2 else 0.0,
				"poseedor_id": 1 if recepcion and i >= 3 else -1,
				"es_pase": i < 3, "es_remate": not recepcion and i >= 3 and i < 7},
			"acciones": [{"clave": 1, "accion": accion}] if i == 3 else [],
			"corte": false})
	return lista
