extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		for bloqueado in [false, true]:
			_probar(local, bloqueado)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _probar(local: bool, bloqueado: bool) -> void:
	var escena := _escena(local, 25.0, 90.0)
	var estado: Dictionary = escena["estado"]
	var a: Dictionary = escena["poseedor"]
	var signo := 1.0 if local else -1.0
	a["pos"] = Vector2.ZERO
	var companeros := []
	var rivales := []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != local:
			e["pos"] = Vector2(45.0 * signo, -25.0)
			rivales.append(e)
		elif id != a["clave"] and e["rol"] != "ARQ":
			companeros.append(e)
	var b: Dictionary = companeros[0]
	var c: Dictionary = companeros[1]
	b["pos"] = Vector2(6.0 * signo, 8.0)
	c["pos"] = Vector2(12.0 * signo, 0.0)
	var destino := Vector2(18.0 * signo, 0.0)
	estado["desmarques"] = {c["clave"]: {"tipo": "ruptura", "destino": destino}}
	var plan := MotorEspacial._buscar_tercer_hombre(estado, a, b)
	_comprobar(not plan.is_empty() and plan.get("clave") == c["clave"], "elige C distinto de A y B")
	var encontrada := false
	for opcion in MotorEspacial.evaluar_opciones(estado, a, escena["jugador"]):
		if opcion.get("tercero_id", -1) == c["clave"] and opcion["objetivo_id"] == b["clave"]:
			encontrada = true
	_comprobar(encontrada, "combinacion disponible en decisiones")
	MotorEspacial._lanzar_pase(estado, a, b["clave"], escena["jugador"])
	estado["pelota"]["pared_a"] = c["clave"]
	estado["pelota"]["pared_destino"] = destino
	estado["pelota"]["offside"] = false
	if bloqueado:
		for rival in rivales:
			rival["pos"] = b["pos"].lerp(destino, 0.5)
	MotorEspacial._resolver_recepcion(estado, b["clave"], b["pos"], 1)
	if bloqueado:
		_comprobar(estado["pelota"]["poseedor_id"] == b["clave"], "B conserva si cierran el carril")
	else:
		_comprobar(estado["pelota"]["destino_id"] == c["clave"] and estado["pelota"]["destino_pos"] == destino, "B habilita al espacio de C")
