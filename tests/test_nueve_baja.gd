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
	a["pos"] = Vector2(5.0 * signo, 0.0)
	var companeros := []
	var rivales := []
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(45.0 * signo, -28.0)
			rivales.append(e)
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			companeros.append(e)
	var nueve: Dictionary = companeros[0]
	nueve["rol"] = "DC"
	nueve["pos"] = Vector2(25.0 * signo, 0.0)
	var extremo: Dictionary = companeros[1]
	extremo["rol"] = "EXT"
	extremo["pos"] = Vector2(17.0 * signo, 13.0)
	MotorEspacial._calcular_linea_offside(estado)
	var baja := _candidato(estado, nueve, a, "nueve_baja")
	_comprobar(not baja.is_empty(), "nueve ofrece descarga hacia pelota")
	if baja.is_empty():
		return
	_comprobar((nueve["pos"].x - baja["destino"].x) * signo > 3.0, "descarga retrocede")
	estado["desmarques"] = {}
	MotorEspacial._anotar_desmarque(estado, estado["desmarques"], nueve["clave"], baja)
	_comprobar(_candidato(estado, extremo, a, "relevo_nueve").is_empty(), "no invade espacio aun ocupado por nueve")
	nueve["pos"] = baja["destino"]
	var relevo := _candidato(estado, extremo, a, "relevo_nueve")
	_comprobar(not relevo.is_empty(), "extremo ataca espacio liberado")
	if not relevo.is_empty():
		_comprobar(relevo["destino"] == baja["espacio_nueve"], "corrida ocupa posicion que dejo nueve")
		MotorEspacial._anotar_desmarque(estado, estado["desmarques"], extremo["clave"], relevo)
		escena["jugador"]["atributos"]["vision"] = 95.0
		var pase := false
		for o in MotorEspacial.evaluar_opciones(estado, a, escena["jugador"]):
			if o.get("objetivo_id", -1) == extremo["clave"] and o.get("detalle", {}).get("corrida_preparada", false):
				pase = o["punto"] == relevo["destino"]
		_comprobar(pase, "pasador puede habilitar relevo")
	rivales[0]["pos"] = baja["espacio_nueve"]
	_comprobar(_candidato(estado, extremo, a, "relevo_nueve").is_empty(), "defensa que sostiene posicion impide relevo")
	rivales[0]["pos"] = Vector2(45.0 * signo, -28.0)
	estado["desmarques"][nueve["clave"]]["hasta"] = estado["tick"]
	_comprobar(_candidato(estado, extremo, a, "relevo_nueve").is_empty(), "plan vencido no activa corrida")


func _candidato(estado: Dictionary, e: Dictionary, a: Dictionary, marca: String) -> Dictionary:
	for c in MotorEspacial._candidatos_desmarque(estado, e, a, e["pos"]):
		if c.get(marca, false):
			return c
	return {}
