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
	var b: Dictionary = {}
	var rival: Dictionary = {}
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(45.0 * signo, -28.0)
			rival = e
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			b = e
	b["pos"] = Vector2(12.0 * signo, 6.0)
	var opciones := [{"tipo": "conducir", "utilidad": 1.0, "detalle": {}},
		{"tipo": "pase", "objetivo_id": b["clave"], "utilidad": 1.0, "detalle": {}},
		{"tipo": "tiro", "utilidad": 1.0, "detalle": {}}]
	estado["pelota"]["ticks_con_pelota"] = 1
	var primera: Array = opciones.duplicate(true)
	MotorEspacial._premiar_descarga_util(estado, a, primera)
	_comprobar(primera == opciones, "primer toque no obliga a soltar")
	estado["pelota"]["ticks_con_pelota"] = 12
	var descarga: Array = opciones.duplicate(true)
	var azar: int = estado["rng"].state
	MotorEspacial._premiar_descarga_util(estado, a, descarga)
	_comprobar(descarga[1]["utilidad"] > descarga[0]["utilidad"], "tras conducir prefiere companero libre adelantado")
	_comprobar(descarga[2] == opciones[2] and estado["rng"].state == azar, "no toca tiro ni consume azar")
	rival["pos"] = b["pos"] * 0.5
	var tapada: Array = opciones.duplicate(true)
	MotorEspacial._premiar_descarga_util(estado, a, tapada)
	_comprobar(tapada == opciones, "no castiga conduccion si pase esta tapado")
	rival["pos"] = Vector2(45.0 * signo, -28.0)
	b["pos"] = Vector2(-12.0 * signo, 0.0)
	var atras: Array = opciones.duplicate(true)
	MotorEspacial._premiar_descarga_util(estado, a, atras)
	_comprobar(atras == opciones, "no premia devolver atras sin progreso")
	b["pos"] = Vector2(12.0 * signo, 6.0)
	var sin_pase := [opciones[0].duplicate(true), opciones[2].duplicate(true)]
	var original: Array = sin_pase.duplicate(true)
	MotorEspacial._premiar_descarga_util(estado, a, sin_pase)
	_comprobar(sin_pase == original, "sin pase ejecutable conserva opciones")
