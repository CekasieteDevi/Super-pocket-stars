extends SceneTree

const SEED := 9500
const MUESTRAS := 300
var fallos := 0


func _init() -> void:
	for local in [true, false]:
		for tipo in ["tiro", "cabezazo", "tiros_libres"]:
			var cubierto := _medir(local, tipo, "cubierto")
			var lejos := _medir(local, tipo, "lejos")
			var ausente := _medir(local, tipo, "ausente")
			print("REMATES local=%s tipo=%s cubierto=%s lejos=%s ausente=%s" % [local, tipo, cubierto, lejos, ausente])
			_comprobar(lejos["atajada"] == 0 and ausente["atajada"] == 0, "sin arquero alcanzable no hay atajadas: " + tipo)
			_comprobar(cubierto["atajada"] > 0 and lejos["gol"] > cubierto["gol"], "arquero bien ubicado reduce goles: " + tipo)
			_comprobar(lejos["afuera"] > 0 and lejos["palo"] > 0
				and lejos["afuera"] == cubierto["afuera"] and lejos["palo"] == cubierto["palo"], "arco vacío conserva puntería y palos: " + tipo)
			_comprobar(lejos == ausente, "arquero imposible y ausente dan la misma resolución: " + tipo)
		_test_geometria(local)
		var tapado := _medir(local, "tiro", "cubierto", true)
		var vacio_tapado := _medir(local, "tiro", "ausente", true)
		_comprobar(tapado["bloqueado"] > 0 and tapado["bloqueado"] == vacio_tapado["bloqueado"], "arco vacío conserva el duelo de bloqueo")
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _comprobar(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion: fallos += 1


func _medir(local: bool, tipo: String, situacion: String, con_defensor: bool = false) -> Dictionary:
	var escena := _escena(local, 16.0, 50.0)
	var plantilla: Dictionary = escena["estado"]
	plantilla["registro_remates"] = []
	var clave := MotorEspacial._clave_arquero(plantilla, not local)
	if situacion == "ausente":
		plantilla["jugadores"].erase(clave)
	else:
		plantilla["jugadores"][clave]["pos"] = MotorEspacial.arco_rival(local) if situacion == "cubierto" else Vector2(0, 30)
	if con_defensor:
		for id in plantilla["jugadores"]:
			var defensor: Dictionary = plantilla["jugadores"][id]
			if defensor["equipo_local"] != local and defensor["rol"] != "ARQ":
				defensor["pos"] = escena["poseedor"]["pos"] + Vector2(1.0 if local else -1.0, 0)
				break
	var conteo := {"gol": 0, "atajada": 0, "afuera": 0, "palo": 0, "bloqueado": 0}
	for indice in range(MUESTRAS):
		escena["casa"].reset_partido()
		escena["visita"].reset_partido()
		var estado := plantilla.duplicate(true)
		estado["rng"].seed = SEED + indice
		MotorEspacial._resolver_tiro(estado, estado["jugadores"][escena["poseedor"]["clave"]], escena["jugador"], tipo)
		var resultado: String = estado["registro_remates"][0]["resultado"]
		conteo[resultado] += 1
	return conteo


func _test_geometria(local: bool) -> void:
	var escena := _escena(local, 16.0, 50.0)
	var estado: Dictionary = escena["estado"]
	var clave := MotorEspacial._clave_arquero(estado, not local)
	var desde: Vector2 = escena["poseedor"]["pos"]
	var arco := MotorEspacial.arco_rival(local)
	estado["jugadores"][clave]["pos"] = desde.lerp(arco, 0.5)
	_comprobar(MotorEspacial._arquero_puede_intervenir(estado, desde, local), "arquero adelantado dentro de la trayectoria puede intervenir")
	estado["jugadores"][clave]["pos"] = arco + Vector2(0, 7)
	var lento: Dictionary = estado["jugadores"][clave]
	lento["rapidez"] = 0.0
	lento["aceleracion"] = 0.0
	lento["vel_max"] = 0.0
	_comprobar(not MotorEspacial._arquero_puede_intervenir(estado, desde, local), "arquero inmóvil fuera de trayectoria no llega")
	lento["rapidez"] = 8.0
	lento["vel_max"] = 8.0
	_comprobar(MotorEspacial._arquero_puede_intervenir(estado, desde, local), "velocidad disponible permite alcanzar la trayectoria")
	estado["saliendo"] = [{"clave": clave}]
	_comprobar(not MotorEspacial._arquero_puede_intervenir(estado, desde, local), "arquero que sale de cancha no puede atajar")


func _escena(local: bool, distancia: float, tiro: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		for jugador in equipo.jugadores:
			for atributo in jugador["atributos"]:
				jugador["atributos"][atributo] = 50.0
		equipo.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, local, 1)
	var atacante: Dictionary = (casa if local else visita).jugadores.back()
	atacante["atributos"]["tiro"] = tiro
	var clave := MotorEspacial.clave_de(atacante["id"], local)
	var poseedor: Dictionary = estado["jugadores"][clave]
	for id in estado["jugadores"]:
		# La prueba mide puntería, sin defensores bloqueando la trayectoria.
		estado["jugadores"][id]["pos"] = Vector2(0.0, 30.0)
	poseedor["pos"] = MotorEspacial.arco_rival(local) + Vector2(-distancia if local else distancia, 0.0)
	estado["pelota"]["pos"] = poseedor["pos"]
	estado["pelota"]["poseedor_id"] = clave
	return {"estado": estado, "poseedor": poseedor, "jugador": atacante,
		"casa": casa, "visita": visita}

