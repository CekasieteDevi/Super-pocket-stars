extends "res://tests/test_identificador_remate.gd"


## Recorre cientos de centros y pases. La pelota puede cambiar de dueño solo
## cuando está a distancia de contacto del jugador que la recibe.
func _init() -> void:
	var casos := 0
	var fallos_centro := 0
	var fallos_pase := 0
	for semilla in range(300):
		if not _probar_centro(semilla):
			fallos_centro += 1
		if not _probar_pase_largo(semilla + 10000):
			fallos_pase += 1
		casos += 2
	_comprobar(fallos_centro == 0, "%d centros sin salto a la cabeza" % 300)
	_comprobar(fallos_pase == 0, "%d pases fallidos sin salto a los pies" % 300)
	print("OK: %d jugadas revisadas; centros=%d pases=%d" % [casos, fallos_centro, fallos_pase])
	quit(1 if fallos else 0)


func _probar_centro(semilla: int) -> bool:
	var escena := _escena(true, 12.0, 80.0)
	var estado: Dictionary = escena["estado"]
	estado["rng"].seed = semilla
	var atacante := -1
	var defensor := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] and e["rol"] != "ARQ" and id != escena["poseedor"]["clave"] and atacante == -1:
			atacante = id
		elif not e["equipo_local"] and e["rol"] != "ARQ" and defensor == -1:
			defensor = id
	if atacante == -1 or defensor == -1:
		return false
	var punto := Vector2(40.0, 0.0)
	for id in estado["jugadores"]:
		estado["jugadores"][id]["pos"] = Vector2(-30.0, 30.0)
	estado["jugadores"][atacante]["pos"] = punto + Vector2(-3.0, 0.0)
	estado["jugadores"][defensor]["pos"] = punto + Vector2(6.0, 0.0)
	estado["pelota"]["pos"] = punto
	estado["pelota"]["poseedor_id"] = -1
	estado["pelota"]["en_vuelo"] = true
	estado["pelota"]["vel"] = Vector2.ZERO
	estado["pelota"]["destino_pos"] = punto
	estado["pelota"]["es_centro"] = true
	estado["pelota"]["tipo_centro"] = MotorEspacial.TIPO_CENTRO_ALTO
	estado["pelota"]["centro_de"] = true
	estado["forzar_centro"] = "gana"
	estado["forzar_remate"] = "atajada"
	var antes: Vector2 = estado["pelota"]["pos"]
	MotorEspacial._avanzar_pelota(estado)
	var pelota: Dictionary = estado["pelota"]
	if not pelota.has("dirigida_a") or bool(pelota.get("es_remate", false)):
		return false
	for _i in range(12):
		antes = pelota["pos"]
		var era_remate: bool = bool(pelota.get("es_remate", false))
		MotorEspacial._avanzar_pelota(estado)
		pelota = estado["pelota"]
		if bool(pelota.get("es_remate", false)) and not era_remate:
			var e_atacante: Dictionary = estado["jugadores"][atacante]
			if pelota["pos"].distance_to(e_atacante["pos"]) > 0.36:
				return false
		if not bool(pelota.get("en_vuelo", false)):
			break
	return true


func _probar_pase_largo(semilla: int) -> bool:
	var escena := _escena(true, 20.0, 80.0)
	var estado: Dictionary = escena["estado"]
	estado["rng"].seed = semilla
	var pasador := -1
	var receptor := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] and e["rol"] != "ARQ":
			if pasador == -1:
				pasador = id
			elif receptor == -1:
				receptor = id
	if pasador == -1 or receptor == -1:
		return false
	for id in estado["jugadores"]:
		estado["jugadores"][id]["pos"] = Vector2(30.0, 30.0)
	estado["jugadores"][pasador]["pos"] = Vector2(-20.0, 0.0)
	estado["jugadores"][receptor]["pos"] = Vector2(0.0, 0.0)
	estado["pelota"]["pos"] = estado["jugadores"][pasador]["pos"]
	estado["pelota"]["poseedor_id"] = pasador
	var jugador: Dictionary = escena["casa"].jugadores[0]
	MotorEspacial._lanzar_pase(estado, estado["jugadores"][pasador], receptor, jugador, null)
	var pelota: Dictionary = estado["pelota"]
	for _i in range(20):
		if pelota.has("dirigida_a"):
			estado["jugadores"][receptor]["pos"] += Vector2(8.0, 0.0)
		var antes: Vector2 = pelota["pos"]
		MotorEspacial._avanzar_pelota(estado)
		pelota = estado["pelota"]
		if int(pelota.get("poseedor_id", -1)) != -1:
			var poseedor: Dictionary = estado["jugadores"][pelota["poseedor_id"]]
			if pelota["pos"].distance_to(poseedor["pos"]) > 0.36:
				return false
		if pelota["pos"].distance_to(antes) > 8.0:
			return false
		if not bool(pelota.get("en_vuelo", false)) and int(pelota.get("poseedor_id", -1)) != -1:
			break
	return true
