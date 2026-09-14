extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		var escena := _escena(local, 25.0, 50.0)
		var estado: Dictionary = escena["estado"]
		var poseedor: Dictionary = escena["poseedor"]
		var jugador: Dictionary = escena["jugador"]
		var signo := 1.0 if local else -1.0
		poseedor["pos"] = Vector2(-15.0 * signo, 0.0)
		jugador["atributos"]["vision"] = 95.0
		jugador["atributos"]["fuerza"] = 95.0
		var receptor := -1
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if e["equipo_local"] != local:
				e["pos"] = Vector2(40.0 * signo, -28.0)
			elif id != poseedor["clave"] and e["rol"] != "ARQ":
				receptor = id
		var destino := Vector2(22.0 * signo, 12.0)
		estado["jugadores"][receptor]["pos"] = Vector2(16.0 * signo, 8.0)
		estado["desmarques"] = {receptor: {"tipo": "ruptura", "destino": destino}}
		var encontrada := false
		for opcion in MotorEspacial.evaluar_opciones(estado, poseedor, jugador):
			if opcion.get("detalle", {}).get("corrida_preparada", false) and opcion["objetivo_id"] == receptor:
				encontrada = true
				_comprobar(opcion["punto"] == destino, "pase apunta a la corrida diagonal")
				MotorEspacial._lanzar_pase(estado, poseedor, receptor, jugador, opcion["punto"], opcion["tipo"] == "pase_largo")
				_comprobar(estado["pelota"]["destino_pos"] == destino, "pelota viaja al espacio")
		_comprobar(encontrada, "lee ruptura preparada local=%s" % local)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)
