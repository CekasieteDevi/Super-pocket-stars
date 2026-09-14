extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		_probar(local)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _probar(local: bool) -> void:
	var escena := _escena(local, 30.0, 90.0)
	var estado: Dictionary = escena["estado"]
	var a: Dictionary = escena["poseedor"]
	var signo := 1.0 if local else -1.0
	a["pos"] = Vector2.ZERO
	var amigos := []
	var rivales := []
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(45.0 * signo, -28.0)
			rivales.append(e)
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			amigos.append(e)
	var b: Dictionary = amigos[0]
	var c: Dictionary = amigos[1]
	var d: Dictionary = amigos[2]
	b["pos"] = Vector2(0.0, 8.0)
	c["pos"] = Vector2(0.0, -8.0)
	d["pos"] = Vector2(15.0 * signo, 0.0)
	estado["ritmo"] = {"local": local, "fase": MotorEspacial.FASE_CIRCULACION}
	var opciones := [{"tipo": "pase", "objetivo_id": d["clave"], "utilidad": 1.0, "detalle": {}}]
	_comprobar(MotorEspacial._ventana_tras_circular(estado, a, opciones) == -1, "sin circulacion no activa secuencia")
	MotorEspacial._anotar_pase_de_ritmo(estado, a["clave"], b["clave"])
	MotorEspacial._anotar_pase_de_ritmo(estado, b["clave"], a["clave"])
	_comprobar(MotorEspacial._ventana_tras_circular(estado, a, opciones) == -1, "ida y vuelta entre dos no basta")
	MotorEspacial._anotar_pase_de_ritmo(estado, c["clave"], a["clave"])
	_comprobar(MotorEspacial._ventana_tras_circular(estado, a, opciones) == 0, "tres participantes abren aceleracion vertical")
	MotorEspacial._ponderar_plan(estado, opciones, a, escena["jugador"], 0.0, 0.5)
	_comprobar(opciones[0]["detalle"].get("aceleracion_preparada", false), "premia envio vertical")
	_comprobar(estado["ritmo"]["fase"] == MotorEspacial.FASE_ACELERACION, "equipo cambia ritmo")
	rivales[0]["pos"] = Vector2(7.0 * signo, 0.0)
	_comprobar(MotorEspacial._ventana_tras_circular(estado, a, opciones) == -1, "carril tapado no fuerza aceleracion")
	MotorEspacial._anotar_pase_de_ritmo(estado, a["clave"], d["clave"])
	_comprobar(estado["ritmo"]["toques_circulacion"] == 0, "avance completado reinicia secuencia")
