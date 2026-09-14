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
	var signo := 1.0 if local else -1.0
	a["pos"] = Vector2(8.0 * signo, 0.0)
	escena["jugador"]["atributos"]["vision"] = 95.0
	escena["jugador"]["atributos"]["fuerza"] = 95.0
	var rivales := []
	var extremo: Dictionary = {}
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(-30.0 * signo, -28.0 * lado)
			e["rol"] = "MC"
			rivales.append(e)
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			extremo = e
	extremo["rol"] = "EXT"
	extremo["pos"] = Vector2(15.0 * signo, 23.0 * lado)
	var lateral: Dictionary = rivales[0]
	var central: Dictionary = rivales[1]
	lateral["rol"] = "LAT"
	lateral["pos"] = Vector2(30.0 * signo, 24.0 * lado)
	central["rol"] = "DFC"
	central["pos"] = Vector2(30.0 * signo, 6.0 * lado)
	MotorEspacial._calcular_linea_offside(estado)
	var c := MotorEspacial._diagonal_extremo(estado, extremo, a)
	_comprobar(not c.is_empty(), "encuentra intervalo lateral-central")
	if c.is_empty():
		return
	_comprobar(absf(c["destino"].y) < absf(extremo["pos"].y), "diagonal entra desde banda")
	_comprobar(c["destino"].x * signo <= 30.0, "respeta linea de fuera de juego")
	estado["desmarques"] = {}
	MotorEspacial._anotar_desmarque(estado, estado["desmarques"], extremo["clave"], c)
	var pase := false
	for o in MotorEspacial.evaluar_opciones(estado, a, escena["jugador"]):
		if o.get("objetivo_id", -1) == extremo["clave"] and o.get("detalle", {}).get("corrida_preparada", false):
			pase = o["punto"] == c["destino"]
	_comprobar(pase, "pasador busca intervalo preparado")
	central["pos"].y = 20.0 * lado
	_comprobar(MotorEspacial._diagonal_extremo(estado, extremo, a).is_empty(), "intervalo cerrado no activa diagonal")
	central["pos"].y = 6.0 * lado
	rivales[2]["pos"] = c["destino"]
	_comprobar(MotorEspacial._diagonal_extremo(estado, extremo, a).is_empty(), "cobertura rival cancela diagonal")
	rivales[2]["pos"] = Vector2(-30.0 * signo, 0.0)
	extremo["pos"].y = 5.0 * lado
	_comprobar(MotorEspacial._diagonal_extremo(estado, extremo, a).is_empty(), "requiere extremo abierto")
