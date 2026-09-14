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
	a["rol"] = "EXT"
	a["pos"] = Vector2(10.0 * signo, 16.0 * lado)
	escena["jugador"]["atributos"]["vision"] = 95.0
	var b: Dictionary = {}
	var marca: Dictionary = {}
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(45.0 * signo, -28.0 * lado)
			if e["rol"] != "ARQ":
				marca = e
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			b = e
	b["rol"] = "LAT"
	b["pos"] = Vector2(5.0 * signo, 19.0 * lado)
	MotorEspacial._calcular_linea_offside(estado)
	_comprobar(_corrida(estado, b, a).is_empty(), "sin marca no fuerza doblamiento")
	marca["pos"] = a["pos"] + Vector2(0.0, -4.0 * lado)
	var corrida := _corrida(estado, b, a)
	_comprobar(not corrida.is_empty(), "lateral rompe con extremo marcado")
	if corrida.is_empty():
		return
	_comprobar(absf(corrida["destino"].y) > absf(a["pos"].y), "corrida pasa por afuera")
	estado["desmarques"] = {}
	MotorEspacial._anotar_desmarque(estado, estado["desmarques"], b["clave"], corrida)
	_comprobar(not _pase(estado, a, escena["jugador"], b["clave"]), "no lanza antes de que llegue lateral")
	b["pos"] = corrida["destino"] - Vector2(2.5 * signo, 0.0)
	_comprobar(_pase(estado, a, escena["jugador"], b["clave"]), "habilita corrida cuando lateral alcanza")
	b["pos"] = Vector2(5.0 * signo, -19.0 * lado)
	_comprobar(_corrida(estado, b, a).is_empty(), "lateral opuesto no cruza toda la cancha")
	b["pos"] = Vector2(5.0 * signo, 19.0 * lado)
	marca["pos"] = corrida["destino"]
	_comprobar(_corrida(estado, b, a).is_empty(), "salida cubierta no activa doblamiento")


func _corrida(estado: Dictionary, b: Dictionary, a: Dictionary) -> Dictionary:
	for c in MotorEspacial._candidatos_desmarque(estado, b, a, b["pos"]):
		if c.get("doblamiento", false):
			return c
	return {}


func _pase(estado: Dictionary, a: Dictionary, jugador: Dictionary, receptor: int) -> bool:
	for o in MotorEspacial.evaluar_opciones(estado, a, jugador):
		if o.get("objetivo_id", -1) == receptor and o.get("detalle", {}).get("corrida_preparada", false):
			return true
	return false
