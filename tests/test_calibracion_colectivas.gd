extends "res://tests/test_identificador_remate.gd"

func _init() -> void:
	for local in [true, false]:
		_probar(local)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)

func _probar(local: bool) -> void:
	var escena := _escena(local, 18.0, 90.0)
	var estado: Dictionary = escena["estado"]
	var a: Dictionary = escena["poseedor"]
	var signo := 1.0 if local else -1.0
	a["pos"].y = 18.0
	escena["jugador"]["atributos"]["centros"] = 90.0
	escena["jugador"]["atributos"]["control"] = 90.0
	var rivales := []
	var b: Dictionary = {}
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(-40.0 * signo, -28.0)
			if e["rol"] != "ARQ":
				rivales.append(e)
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			b = e
	b["pos"] = MotorEspacial.arco_rival(local) - Vector2(11.0 * signo, 0.0)
	var marca: Dictionary = rivales[0]
	marca["pos"] = a["pos"] + Vector2(signo, 0.0)
	var habilitado := false
	for o in MotorEspacial.evaluar_opciones(estado, a, escena["jugador"]):
		if o["tipo"] == "gambeta" and not o.get("enganche", {}).is_empty():
			habilitado = true
	_comprobar(habilitado, "marcador cercano permite intentar duelo de enganche")
	for i in range(3):
		rivales[i + 1]["pos"] = a["pos"] + Vector2(float(i - 1) * 2.0, -6.0)
	_comprobar(MotorEspacial._opcion_enganche(estado, a, escena["jugador"], marca["clave"]).is_empty(), "cobertura distinta al marcador sigue bloqueando enganche")
	for rival in rivales:
		rival["pos"] = Vector2(-40.0 * signo, -28.0)
	marca["pos"] = a["pos"] + Vector2(3.0 * signo, 0.0)
	var atras: Vector2 = a["pos"] - Vector2(8.0 * signo, 0.0)
	_comprobar(MotorEspacial._riesgo_de_salida(estado, a["pos"], atras, local) == 0.0, "marca por delante no tapa pase hacia atras")
	marca["pos"] = a["pos"].lerp(atras, 0.5)
	_comprobar(MotorEspacial._riesgo_de_salida(estado, a["pos"], atras, local) == 1.0, "rival en trayectoria sigue tapando pase")
	marca["pos"] = a["pos"] + Vector2(signo, 0.0)
	_comprobar(MotorEspacial._riesgo_de_salida(estado, a["pos"], atras, local) > 0.8, "contacto junto al balon sigue contando")
	for rival in rivales:
		rival["pos"] = Vector2(-40.0 * signo, -28.0)
	estado["linea_offside"] = {"local": 43.5, "away": -43.5}
	a["pos"] = Vector2(31.0 * signo, 18.0)
	b["rol"] = "MC"
	b["pos"] = Vector2(29.0 * signo, 0.0)
	var anticipa := false
	for candidato in MotorEspacial._candidatos_desmarque(estado, b, a, b["pos"]):
		anticipa = anticipa or bool(candidato.get("pase_atras", false))
	_comprobar(anticipa, "llegada arranca antes de que extremo entre al area")
