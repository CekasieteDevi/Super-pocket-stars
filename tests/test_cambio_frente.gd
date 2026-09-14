extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		for lado in [-1.0, 1.0]:
			_probar(local, lado)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _probar(local: bool, lado: float) -> void:
	var escena := _escena(local, 30.0, 90.0)
	var estado: Dictionary = escena["estado"]
	var a: Dictionary = escena["poseedor"]
	a["pos"] = Vector2(0.0, 20.0 * lado)
	escena["jugador"]["atributos"]["fuerza"] = 95.0
	var rivales := []
	var b: Dictionary = {}
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local and e["rol"] != "ARQ":
			rivales.append(e)
			e["pos"] = Vector2(12.0, 15.0 * lado)
		elif e["equipo_local"] == local and e["clave"] != a["clave"] and e["rol"] != "ARQ":
			b = e
	b["rol"] = "EXT"
	b["pos"] = Vector2(0.0, -23.0 * lado)
	MotorEspacial._calcular_linea_offside(estado)
	_comprobar(MotorEspacial._ventaja_cambio_frente(estado, a["pos"], b["pos"], local) > 0.0, "reconoce banda contraria libre")
	var apertura := false
	for c in MotorEspacial._candidatos_desmarque(estado, b, a, b["pos"]):
		apertura = apertura or c.get("cambio_frente", false)
	_comprobar(apertura, "extremo prepara amplitud contraria")
	var pase := false
	for o in MotorEspacial.evaluar_opciones(estado, a, escena["jugador"]):
		if o["tipo"] == "pase_largo" and o["objetivo_id"] == b["clave"]:
			pase = o["detalle"].get("cambio_frente", false)
	_comprobar(pase, "habilita cambio largo horizontal")
	rivales[0]["pos"] = b["pos"]
	_comprobar(MotorEspacial._ventaja_cambio_frente(estado, a["pos"], b["pos"], local) == 0.0, "sin premio si receptor esta marcado")
	for i in range(rivales.size()):
		rivales[i]["pos"] = Vector2(12.0, 15.0 if i % 2 == 0 else -15.0)
	_comprobar(MotorEspacial._ventaja_cambio_frente(estado, a["pos"], b["pos"], local) == 0.0, "defensa equilibrada no activa atraccion")
