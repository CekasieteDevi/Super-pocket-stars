extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		for lado in [-1.0, 1.0]:
			_probar(local, lado)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _probar(local: bool, lado: float) -> void:
	var escena := _escena(local, 18.0, 90.0)
	var estado: Dictionary = escena["estado"]
	var a: Dictionary = escena["poseedor"]
	var jugador: Dictionary = escena["jugador"]
	var signo := 1.0 if local else -1.0
	a["pos"].y = 23.0 * lado
	jugador["atributos"]["centros"] = 90.0
	jugador["atributos"]["control"] = 90.0
	var b: Dictionary = {}
	var rival: Dictionary = {}
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local:
			e["pos"] = Vector2(-30.0 * signo, -28.0 * lado)
			if e["rol"] != "ARQ":
				rival = e
		elif e["clave"] != a["clave"] and e["rol"] != "ARQ":
			b = e
	_comprobar(MotorEspacial._opcion_enganche(estado, a, jugador).is_empty(), "sin receptor no amenaza centro")
	b["pos"] = MotorEspacial.arco_rival(local) - Vector2(11.0 * signo, 0.0)
	var enganche := MotorEspacial._opcion_enganche(estado, a, jugador)
	_comprobar(not enganche.is_empty(), "centro posible habilita enganche")
	if enganche.is_empty():
		return
	_comprobar(absf(enganche["destino"].y) < absf(a["pos"].y), "recorta hacia dentro")
	rival["pos"] = a["pos"] + Vector2(5.0 * signo, 0.0)
	var disponible := false
	for opcion in MotorEspacial.evaluar_opciones(estado, a, jugador):
		if opcion["tipo"] == "gambeta" and not opcion.get("enganche", {}).is_empty():
			disponible = true
	_comprobar(disponible, "enganche participa en decisiones")
	var gana := false
	var pierde := false
	for semilla in range(60):
		var copia: Dictionary = estado.duplicate(true)
		copia["con_fotogramas"] = true
		copia["acciones_tick"] = []
		copia["rng"] = RandomNumberGenerator.new()
		copia["rng"].seed = semilla
		var atacante: Dictionary = copia["jugadores"][a["clave"]]
		atacante.erase("corredor")
		var ganadas_antes: int = copia["gambetas"]["home" if local else "away"]["ganadas"]
		MotorEspacial._resolver_gambeta(copia, atacante, jugador, rival["clave"], enganche)
		var gesto := false
		for accion in copia["acciones_tick"]:
			gesto = gesto or (accion["clave"] == a["clave"] and accion["accion"] == "amague_centro")
		_comprobar(gesto, "intento emite animacion de amague")
		if copia["gambetas"]["home" if local else "away"]["ganadas"] > ganadas_antes:
			gana = true
			_comprobar(atacante["corredor"] == enganche["destino"] and atacante["pos"] == a["pos"], "gana y prepara giro sin teletransporte")
		elif copia["pelota"]["poseedor_id"] != a["clave"]:
			pierde = true
			_comprobar(not atacante.has("corredor"), "no obtiene enganche al perder")
		if gana and pierde:
			break
	_comprobar(gana and pierde, "duelo conserva resultados distintos")
	rival["pos"] = enganche["destino"]
	var alternativa := MotorEspacial._opcion_enganche(estado, a, jugador)
	_comprobar(alternativa.is_empty() or alternativa["destino"].distance_to(rival["pos"]) > 2.7, "busca otra salida si cubren la primera")
	for e in estado["jugadores"].values():
		if e["equipo_local"] != local and e["clave"] != rival["clave"]:
			e["pos"] = a["pos"] + Vector2(-2.0 * signo, -6.0 * lado)
			break
	_comprobar(MotorEspacial._opcion_enganche(estado, a, jugador).is_empty(), "cobertura interior impide recorte")
	a["pos"].y = 0.0
	_comprobar(MotorEspacial._opcion_enganche(estado, a, jugador).is_empty(), "por el centro no amaga centro de banda")
