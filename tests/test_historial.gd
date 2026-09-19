extends SceneTree

## El historial largo (core/historial.gd): la carrera de cada jugador, las
## temporadas de cada club y el palmares de cada competencia. Juega una
## temporada entera por el camino de la partida y mira que todo quede
## anotado despues del cierre, que es cuando se resetea lo demas.
##
## Correr con: godot --path . --headless --script tests/test_historial.gd

const SEED := 4417

var fallos := 0


func _init() -> void:
	# SIN meterlo en el arbol: _ready() cargaria la partida del usuario.
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Prueba")

	_test_pase_abre_fila_nueva()
	_test_temporada_completa(gs)
	_test_guardado(gs)

	gs.free()
	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Un partido armado a mano: el jugador 1 juega entero y hace un gol.
func _partido(id: int, equipo: String) -> Dictionary:
	return {
		"xp": {"home": {id: {"velocidad": 0.5, "pase": 0.5}}, "away": {}},
		"goles_log": [{"equipo": equipo, "jugador_id": id, "asistencia_id": -1}],
	}


func _test_pase_abre_fila_nueva() -> void:
	print("=== Un pase a mitad de temporada ===")
	Historial.temporada = 1
	var a := Team.new()
	a.nombre = "Club A"
	a.division_actual = 2
	var b := Team.new()
	b.nombre = "Club B"
	b.division_actual = 0
	var rival := Team.new()
	rival.nombre = "Rival"
	var j := {"id": 1}
	a.jugadores = [j]

	Historial.registrar_partido(a, rival, _partido(1, "Club A"))
	Historial.registrar_partido(a, rival, _partido(1, "Club A"))
	a.jugadores = []
	b.jugadores = [j]
	Historial.registrar_partido(b, rival, _partido(1, "Club B"))

	var carrera: Array = j.get("carrera", [])
	_ok(carrera.size() == 2, "el pase abre una fila nueva (hay %d)." % carrera.size())
	if carrera.size() == 2:
		_ok(str(carrera[0]["club"]) == "Club A" and int(carrera[0]["pj"]) == 2
			and int(carrera[0]["goles"]) == 2 and int(carrera[0]["division"]) == 3,
			"lo hecho en el club viejo queda en su fila: %s." % [carrera[0]])
		_ok(str(carrera[1]["club"]) == "Club B" and int(carrera[1]["pj"]) == 1
			and int(carrera[1]["goles"]) == 1,
			"el club nuevo arranca de cero: %s." % [carrera[1]])

	# El alargue abstracto suma el gol pero no otro partido.
	Historial.registrar_partido(b, rival, _partido(1, "Club B"), false)
	_ok(int(carrera[1]["pj"]) == 1 and int(carrera[1]["goles"]) == 2,
		"el alargue suma goles y no partidos: %s." % [carrera[1]])

	var t := Historial.totales(j)
	_ok(int(t["pj"]) == 3 and int(t["goles"]) == 4 and int(t["clubes"]) == 2,
		"los totales suman las dos filas: %s." % [t])


func _test_temporada_completa(gs) -> void:
	print("\n=== Una temporada entera ===")
	Historial.temporada = gs.temporada_actual
	while gs.hay_fecha_pendiente():
		gs.jugar_siguiente_fecha()

	# La carrera cuenta la liga Y las copas, asi que nunca puede tener
	# menos goles que la tabla de goleadores de la liga.
	var liga: Liga = gs.liga_jugador()
	var menos := 0
	var revisados := 0
	for e in liga.equipos:
		for j in e.todos_los_jugadores():
			var fila: Dictionary = liga.estadisticas.get(str(j["id"]), {})
			if fila.is_empty():
				continue
			revisados += 1
			var goles := 0
			for f in j.get("carrera", []):
				if int(f["temporada"]) == gs.temporada_actual:
					goles += int(f["goles"])
			if goles < int(fila.get("goles", 0)):
				menos += 1
	_ok(revisados > 100 and menos == 0,
		"la carrera tiene al menos los goles de la liga (%d revisados, %d con menos)." % [revisados, menos])

	var con_partidos := 0
	for j in gs.equipo_jugador.jugadores:
		for f in j.get("carrera", []):
			if int(f["pj"]) > 0:
				con_partidos += 1
	_ok(con_partidos >= 11, "los titulares tienen partidos anotados (%d filas)." % con_partidos)

	gs._cerrar_temporada()

	_ok(Historial.temporada == 2, "el historial pasa a la temporada 2.")
	var clubes_ok := true
	var total := 0
	for d in range(gs.piramide.divisiones.size()):
		for e in gs.piramide.divisiones[d].equipos:
			total += 1
			if e.historial_temporadas.size() != 1:
				clubes_ok = false
	_ok(clubes_ok and total == 200, "los %d clubes tienen su temporada anotada." % total)

	# Los puestos de una division son 1..N sin repetir.
	var por_division := {}
	for d in range(gs.piramide.divisiones.size()):
		for e in gs.piramide.divisiones[d].equipos:
			var t: Dictionary = e.historial_temporadas[0]
			var clave := int(t["division"])
			if not por_division.has(clave):
				por_division[clave] = []
			por_division[clave].append(int(t["posicion"]))
	var puestos_ok := por_division.size() == 10
	for d in por_division:
		var lista: Array = por_division[d]
		lista.sort()
		for i in range(lista.size()):
			if lista[i] != i + 1:
				puestos_ok = false
	_ok(puestos_ok, "cada division anota los puestos 1..N una sola vez.")

	var ligas := 0
	var copas_division := 0
	for k in gs.historial_copas:
		if str(k).begins_with("Liga"):
			ligas += 1
		elif str(k).begins_with("Copa de la División"):
			copas_division += 1
	_ok(ligas == 10, "el palmares tiene el campeon de las 10 ligas (%d)." % ligas)
	_ok(copas_division == 10, "y de las 10 copas de division (%d)." % copas_division)
	_ok(gs.historial_copas.has("Copa del Rey"), "y de la Copa del Rey.")
	var rey: Array = gs.historial_copas.get("Copa del Rey", [])
	if not rey.is_empty():
		_ok(str(rey[0]["subcampeon"]) != "" and str(rey[0]["subcampeon"]) != str(rey[0]["campeon"]),
			"la final del Rey tiene subcampeon distinto del campeon: %s." % [rey[0]])
		var ranking := Historial.ranking_de_titulos(rey)
		_ok(ranking.size() == 1 and int(ranking[0]["titulos"]) == 1,
			"el ranking del Rey tiene un solo campeon con un titulo.")

	# El suplente que no jugo nunca tambien fue del club.
	var sin_fila := 0
	for e in gs.liga_jugador().equipos:
		for j in e.todos_los_jugadores():
			var carrera: Array = j.get("carrera", [])
			if int(j.get("edad", 0)) > 0 and carrera.is_empty():
				sin_fila += 1
	# Los del cierre (canteranos subidos, fichajes del receso) todavia no
	# tienen fila; los que estaban en la temporada si. Por eso se mira que
	# sean pocos y no cero.
	_ok(sin_fila < 40, "casi todo plantel tiene carrera despues del cierre (%d sin fila)." % sin_fila)


func _test_guardado(gs) -> void:
	print("\n=== Guardado ===")
	var e: Team = gs.equipo_jugador
	var datos: Dictionary = JSON.parse_string(JSON.stringify(e.guardar()))
	var t := Team.cargar(datos)
	_ok(t.historial_temporadas.size() == e.historial_temporadas.size()
		and int(t.historial_temporadas[0]["posicion"]) == int(e.historial_temporadas[0]["posicion"]),
		"las temporadas del club sobreviven al guardado.")
	var con_carrera := 0
	for j in t.todos_los_jugadores():
		if not j.get("carrera", []).is_empty():
			con_carrera += 1
	_ok(con_carrera > 0, "la carrera de los jugadores sobrevive al guardado (%d)." % con_carrera)
	var palmares: Dictionary = JSON.parse_string(JSON.stringify(gs.historial_copas))
	_ok(palmares.size() == gs.historial_copas.size(), "el palmares sobrevive al guardado.")
