extends SceneTree

const SEED := 9400
var fallos := 0


func _init() -> void:
	for local in [true, false]:
		for tipo in ["gol", "atajada", "afuera", "palo", "penal", "tanda"]:
			_test_aplicacion(local, tipo)
		_test_registro(local)
	_test_partidos()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _comprobar(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion: fallos += 1


func _test_aplicacion(local: bool, tipo: String) -> void:
	var escena := _escena(local, 16.0, 70.0)
	var estado: Dictionary = escena["estado"]
	var poseedor: Dictionary = escena["poseedor"]
	var datos := {"tipo": "gol" if tipo in ["penal", "tanda"] else tipo,
		"es_local": local, "clave": poseedor["clave"], "rol": poseedor["rol"],
		"jugador": escena["jugador"], "dist": 16.0, "agarre": 0.5,
		"penal": tipo in ["penal", "tanda"]}
	if tipo == "tanda":
		estado["en_tanda"] = true
		estado["tanda"] = {"home": 0, "away": 0}
	MotorEspacial._lanzar_remate(estado, poseedor, datos)
	var copia := datos.duplicate(true)
	var azar_vuelo: int = estado["rng"].state
	var vuelo: Dictionary = estado["pelota"].duplicate(true)
	MotorEspacial._lanzar_remate(estado, poseedor, copia)
	_comprobar(azar_vuelo == estado["rng"].state and vuelo == estado["pelota"], "relanzar el mismo identificador conserva vuelo y azar")
	MotorEspacial._aplicar_remate(estado, datos)
	var eventos: Array = estado["eventos"].duplicate(true)
	var goles: Array = estado["goles_log"].duplicate(true)
	var pelota: Dictionary = estado["pelota"].duplicate(true)
	var azar: int = estado["rng"].state
	var marcador: int = escena["casa"].goles + escena["visita"].goles
	var tanda: Dictionary = estado.get("tanda", {}).duplicate(true)
	MotorEspacial._aplicar_remate(estado, copia)
	MotorEspacial._lanzar_remate(estado, poseedor, copia)
	_comprobar(eventos == estado["eventos"] and goles == estado["goles_log"]
		and pelota == estado["pelota"] and azar == estado["rng"].state
		and marcador == escena["casa"].goles + escena["visita"].goles
		and tanda == estado.get("tanda", {}), "aplicar dos veces no duplica efectos: %s local=%s" % [tipo, local])
	var encontrados := 0
	for evento in eventos:
		if evento.get("remate_id", -1) == datos["remate_id"]: encontrados += 1
	_comprobar(encontrados == 1 and (goles.is_empty() or goles[0]["remate_id"] == datos["remate_id"]), "vuelo, evento y gol comparten identificador")


func _test_registro(local: bool) -> void:
	var escena := _escena(local, 16.0, 70.0)
	var estado: Dictionary = escena["estado"]
	estado["registro_remates"] = []
	estado["pelota"]["pos"] = escena["poseedor"]["pos"] + Vector2(0, 4)
	MotorEspacial._entregar_rodando(estado, escena["poseedor"]["clave"])
	_comprobar(estado["pelota"].has("dirigida_a"), "centro deja entrega pendiente antes del remate")
	estado["forzar_remate"] = "gol"
	MotorEspacial._resolver_tiro(estado, escena["poseedor"], escena["jugador"])
	var registro: Dictionary = estado["registro_remates"][0]
	var previa: Dictionary = registro["ocasion"].duplicate(true)
	var ejecucion: Dictionary = registro["ejecucion"].duplicate(true)
	var datos: Dictionary = estado["pelota"]["remate"]
	_comprobar(not estado["pelota"].has("dirigida_a"), "remate reemplaza la entrega pendiente del centro")
	_comprobar(estado["goles_log"].is_empty() and registro["remate_id"] == datos["remate_id"], "ocasión e identificador existen durante el vuelo, antes del gol")
	MotorEspacial._aplicar_remate(estado, datos)
	_comprobar(registro["ocasion"] == previa and registro["ejecucion"] == ejecucion
		and estado["goles_log"][0]["remate_id"] == registro["remate_id"], "aplicar el resultado conserva la evaluación previa")


func _test_partidos() -> void:
	var valido := true
	var bloqueados := 0
	var remates := 0
	for indice in range(12):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + indice
		var a := Team.generar("A", rng, 0)
		var b := Team.generar("B", rng, 400)
		var resultado := MotorEspacial.simular(a, b, rng, indice % 2 == 0, false, true)
		var por_id := {}
		for registro in resultado["stats"]["registro_remates"]:
			var id: int = registro["remate_id"]
			if id <= 0 or por_id.has(id): print("ID repetido en registro: ", indice, " ", id)
			valido = valido and id > 0 and not por_id.has(id)
			por_id[id] = registro
			remates += 1
		var eventos := {}
		for evento in resultado["eventos"]:
			if evento["tipo"] not in ["tiro", "tiro_puerta", "penal"]: continue
			var id: int = evento["remate_id"]
			if eventos.has(id): print("Evento repetido: ", indice, " ", id)
			valido = valido and not eventos.has(id)
			eventos[id] = evento
			if evento["tipo"] == "penal": continue
			if not por_id.has(id) or por_id[id]["resultado"] != evento["resultado"]:
				print("No coincide: ", indice, " ", evento, " ", por_id.get(id, {}))
			valido = valido and por_id.has(id) and por_id[id]["resultado"] == evento["resultado"]
			if evento["resultado"] == "bloqueado": bloqueados += 1
		for id in por_id:
			if not eventos.has(id): print("Sin evento: ", indice, " ", por_id[id], " cortes=", resultado["stats"].get("cortadas", {}))
			valido = valido and eventos.has(id)
		for gol in resultado["goles_log"]:
			valido = valido and eventos.has(gol["remate_id"]) and eventos[gol["remate_id"]]["resultado"] == "gol"
	_comprobar(valido and remates > 0 and bloqueados > 0, "12 partidos enlazan %d intentos, incluidos %d bloqueos, sin duplicados" % [remates, bloqueados])


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

