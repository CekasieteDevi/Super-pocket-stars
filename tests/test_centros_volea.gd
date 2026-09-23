extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	var resultados := {}
	var animaciones := {}
	for local in [true, false]:
		for rol in ["EI", "ED", "MC", "LI", "LD"]:
			_test_centro_banda(local, rol)
		_test_centro_no_sale_del_medio(local)
		_test_centro_no_se_lo_hace_a_si_mismo(local)
		for semilla in range(80):
			var escena := _escena(local, 7.0, 1.0)
			var estado: Dictionary = escena["estado"]
			var jugador: Dictionary = escena["jugador"]
			jugador["atributos"]["volea"] = 95.0
			jugador["atributos"]["agilidad"] = 90.0
			jugador["atributos"]["salto"] = 85.0
			jugador["atributos"]["cabezazo"] = 10.0
			estado["rng"].seed = semilla
			estado["registro_remates"] = []
			estado["con_fotogramas"] = true
			estado["acciones_tick"] = []
			estado["forzar_centro"] = "gana"
			var arq: int = MotorEspacial._clave_arquero(estado, not local)
			estado["jugadores"][arq]["pos"] = MotorEspacial.arco_rival(local)
			MotorEspacial._resolver_centro(estado, escena["poseedor"]["pos"], local, 1)
			var registro: Dictionary = estado["registro_remates"][0]
			if registro["atributo"] != "volea" or registro["tiro"] != 95.0:
				fallos += 1
			resultados[registro["resultado"]] = true
			for accion in estado["acciones_tick"]:
				if accion["clave"] == escena["poseedor"]["clave"]:
					animaciones[accion["accion"]] = true
	_comprobar(resultados.has("gol") and resultados.has("atajada") and resultados.has("afuera"), "voleas: gol, atajada y afuera sin forzar resultado")
	_comprobar(animaciones.has("volea") and animaciones.has("chilena") and not animaciones.has(MotorEspacial.ACCION_PATEA), "volea y chilena usan su animacion")
	var escena := _escena(true, 12.0, 99.0)
	var jugador: Dictionary = escena["jugador"]
	jugador["atributos"]["volea"] = 1.0
	_comprobar(not MotorEspacial.remata_de_acrobacia(jugador), "tiro alto no reemplaza atributo volea")
	var baja := MotorEspacial.modelo_destino_remate(0.8, 0.8, 10.0, "volea")
	var alta := MotorEspacial.modelo_destino_remate(0.8, 0.8, 90.0, "volea")
	_comprobar(alta["probabilidad_modelo_porteria_sin_bloqueo"] > baja["probabilidad_modelo_porteria_sin_bloqueo"], "mayor volea mejora punteria")
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _test_centro_banda(local: bool, rol: String) -> void:
	var escena := _escena(local, 10.0, 50.0)
	var estado: Dictionary = escena["estado"]
	var poseedor: Dictionary = escena["poseedor"]
	poseedor["rol"] = rol
	poseedor["pos"].y = 27.0
	escena["jugador"]["atributos"]["centros"] = 90.0
	var receptor := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == local and id != poseedor["clave"] and e["rol"] != "ARQ":
			e["pos"] = MotorEspacial.arco_rival(local) + Vector2(-11.0 if local else 11.0, 0.0)
			receptor = id
			break
	var encontrado := false
	for opcion in MotorEspacial.evaluar_opciones(estado, poseedor, escena["jugador"]):
		if opcion["tipo"] == "centro" and opcion["objetivo_id"] == receptor:
			encontrado = true
	_comprobar(encontrado, "centro desde banda: %s local=%s" % [rol, local])


func _test_centro_no_sale_del_medio(local: bool) -> void:
	var escena := _escena(local, 7.0, 50.0)
	var estado: Dictionary = escena["estado"]
	var poseedor: Dictionary = escena["poseedor"]
	poseedor["pos"] = Vector2(0.0, 7.0)
	escena["jugador"]["atributos"]["centros"] = 99.0
	var hay_centro := false
	for opcion in MotorEspacial.evaluar_opciones(estado, poseedor, escena["jugador"]):
		if opcion["tipo"] == "centro":
			hay_centro = true
	_comprobar(not hay_centro, "mitad de cancha no se etiqueta como centro: local=%s" % local)


func _test_centro_no_se_lo_hace_a_si_mismo(local: bool) -> void:
	var escena := _escena(local, 7.0, 50.0)
	var estado: Dictionary = escena["estado"]
	var poseedor: Dictionary = escena["poseedor"]
	var punto := MotorEspacial.arco_rival(local) - Vector2(8.0 if local else -8.0, 0.0)
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == local and e["rol"] != "ARQ":
			e["pos"] = punto + Vector2(20.0, 0.0)
	poseedor["pos"] = punto + Vector2(1.0, 0.0)
	var elegido := MotorEspacial._mas_cercano_del_equipo(estado, punto, local, poseedor["clave"])
	_comprobar(elegido != poseedor["clave"], "el centrador no recibe su propio centro: local=%s" % local)
