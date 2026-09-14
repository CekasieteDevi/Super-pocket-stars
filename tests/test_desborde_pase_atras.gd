extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		for lado in [-1.0, 1.0]:
			_probar(local, lado)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _probar(local: bool, lado: float) -> void:
	var escena := _escena(local, 5.0, 90.0)
	var estado: Dictionary = escena["estado"]
	var a: Dictionary = escena["poseedor"]
	var signo := 1.0 if local else -1.0
	a["pos"].y = 22.0 * lado
	var receptor: Dictionary = {}
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != local:
			e["pos"] = Vector2(49.0 * signo, -28.0 * lado)
		elif id != a["clave"] and e["rol"] != "ARQ":
			receptor = e
	receptor["rol"] = "MC"
	var punto := Vector2((MotorEspacial.MEDIO_LARGO - 11.0) * signo, 0.0)
	receptor["pos"] = punto - Vector2(3.0 * signo, 0.0)
	MotorEspacial._calcular_linea_offside(estado)
	var candidato := {}
	for c in MotorEspacial._candidatos_desmarque(estado, receptor, a, receptor["pos"]):
		if c.get("pase_atras", false) and absf(c["destino"].y) < 0.1:
			candidato = c
	_comprobar(not candidato.is_empty(), "volante prepara llegada al punto penal")
	if candidato.is_empty():
		return
	estado["desmarques"] = {}
	MotorEspacial._anotar_desmarque(estado, estado["desmarques"], receptor["clave"], candidato)
	var opcion := _pase(estado, a, escena["jugador"])
	_comprobar(not opcion.is_empty(), "extremo ve pase atras a la corrida")
	if not opcion.is_empty():
		MotorEspacial._lanzar_pase(estado, a, receptor["clave"], escena["jugador"], opcion["punto"])
		_comprobar(estado["pelota"]["destino_pos"] == candidato["destino"] and not estado["pelota"].get("es_centro", false), "pase al espacio sin centro aereo")
	receptor["pos"] = Vector2.ZERO
	_comprobar(_pase(estado, a, escena["jugador"]).is_empty(), "espera si el volante esta demasiado lejos")
	receptor["pos"] = punto
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = a["pos"].lerp(punto, 0.5)
	_comprobar(_pase(estado, a, escena["jugador"]).is_empty(), "carril cerrado cancela pase coordinado")
	a["pos"] = Vector2.ZERO
	_comprobar(_pase(estado, a, escena["jugador"]).is_empty(), "sin desborde no fuerza pase atras")


func _pase(estado: Dictionary, a: Dictionary, jugador: Dictionary) -> Dictionary:
	for opcion in MotorEspacial.evaluar_opciones(estado, a, jugador):
		if opcion.get("detalle", {}).get("llegada_coordinada", false):
			return opcion
	return {}
