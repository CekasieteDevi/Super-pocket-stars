extends SceneTree

## Una temporada entera por el mismo camino que la pantalla, con el Motor
## V2 jugando los partidos del usuario:
##
## 1. Temporada 1 "a mano": avanzar dia por dia y jugar cada partido del
##    dia (liga, copa, playoff) como lo hace el boton Jugar. Cada partido
##    tiene que dejar resultado, eventos y la receta que mira la vista.
## 2. Temporada 2 con "Simular temporada": tiene que cerrar el año sin
##    colgarse y dejar la tabla jugada entera.
## 3. BUG-003: con el feed de noticias lleno, una noticia nueva se cuenta.
##
## Correr con: godot --path . --headless --script tests/test_flujo_partidos_v2.gd

const SEED := 2610

var fallos := 0


func _init() -> void:
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Flujo")

	_test_temporada_a_mano(gs)
	_test_simular_temporada(gs)
	_test_noticias_con_feed_lleno(gs)

	gs.free()
	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Lo que la pantalla necesita para mostrar el partido recien jugado.
func _partido_mirable(gs) -> String:
	var r: Dictionary = gs.ultimo_resultado
	if r.is_empty():
		return "sin resultado"
	if MotorV2.receta_de(gs.ultimos_fotogramas).is_empty():
		return "sin receta para la vista"
	if gs.ultimos_eventos.is_empty():
		return "sin eventos para el relato"
	var goles: Array = r.get("goles_log", [])
	if goles.size() != int(r["gl"]) + int(r["gv"]):
		return "goles_log (%d) no cierra con el marcador %d-%d" % [goles.size(), r["gl"], r["gv"]]
	var nombres := {}
	for liga in gs.piramide.divisiones:
		for e in liga.equipos:
			nombres[e.nombre] = true
	nombres.merge(gs.confederacion.indice_de_equipos())
	if not nombres.has(str(r["local"])) or not nombres.has(str(r["visitante"])):
		return "la vista no encuentra a %s o a %s" % [r["local"], r["visitante"]]
	return ""


func _test_temporada_a_mano(gs) -> void:
	print("=== Temporada 1 jugada como la pantalla ===")
	var temporada: int = gs.temporada_actual
	var jugados := {"liga": 0, "copa": 0, "internacional": 0, "playoff": 0}
	var problemas := []
	var pasos := 0
	while gs.temporada_actual == temporada and pasos < 2000:
		pasos += 1
		var tipo := ""
		if gs.hay_partido_de_copa_hoy():
			tipo = "copa"
			gs.jugar_partido_de_copa()
		elif gs.hay_partido_internacional_hoy():
			tipo = "internacional"
			gs.jugar_partido_internacional()
		elif gs.hay_partido_de_playoff_hoy():
			tipo = "playoff"
			gs.jugar_partido_de_playoff()
		elif gs.hay_partido_hoy():
			tipo = "liga"
			gs.jugar_siguiente_fecha()
		else:
			gs.avanzar_hasta_el_partido()
			continue
		jugados[tipo] += 1
		var problema := _partido_mirable(gs)
		if problema != "":
			problemas.append("%s %d: %s" % [tipo, jugados[tipo], problema])
	print("  partidos jugados: %s, pasos: %d" % [jugados, pasos])
	_ok(gs.temporada_actual == temporada + 1, "la temporada cierra (pasos: %d)." % pasos)
	_ok(jugados["liga"] == gs.piramide.divisiones[0].fixture.size(),
		"se juegan todas las fechas de liga (%d)." % jugados["liga"])
	_ok(jugados["copa"] >= 1, "se juega al menos un cruce de copa (%d)." % jugados["copa"])
	_ok(problemas.is_empty(), "todos los partidos se pueden mirar: %s" % [problemas])
	_ok(gs.historial_partidos.size() == jugados.values().reduce(func(a, b): return a + b, 0),
		"cada partido entra al historial (%d)." % gs.historial_partidos.size())


func _test_simular_temporada(gs) -> void:
	print("=== Temporada 2 con Simular temporada ===")
	var temporada: int = gs.temporada_actual
	var inicio := Time.get_ticks_msec()
	gs.simular_temporada_completa()
	var segundos := (Time.get_ticks_msec() - inicio) / 1000.0
	print("  simular la temporada tardo %.1f s" % segundos)
	_ok(gs.temporada_actual == temporada + 1, "simular cierra la temporada.")
	var tabla_ok := true
	for liga in gs.piramide.divisiones:
		for e in liga.equipos:
			if liga.tabla.has(e.nombre) and int(liga.tabla[e.nombre].get("pj", 0)) != 0:
				tabla_ok = false
	# Al cerrar la temporada la tabla se reinicia: lo jugado queda en la
	# posicion final del club.
	_ok(tabla_ok and not gs.ultima_posicion_final.is_empty(),
		"la tabla nueva arranca en cero y queda la posicion final.")


func _test_noticias_con_feed_lleno(gs) -> void:
	print("=== BUG-003: noticias nuevas con el feed lleno ===")
	for i in gs.MAX_POR_CATEGORIA:
		gs._agregar_noticia("FICHAJE de relleno %d" % i, "fichajes")
	var tam_antes: int = gs.noticias.size()
	var antes: int = gs.noticias_agregadas
	gs._agregar_noticia("FICHAJE nuevo", "fichajes")
	_ok(gs.noticias.size() == tam_antes, "el feed lleno no crece (%d)." % gs.noticias.size())
	_ok(gs.noticias_agregadas - antes == 1, "el contador ve la noticia nueva.")
	_ok(str(gs.noticias[0]["texto"]).contains("FICHAJE nuevo"), "la nueva queda adelante.")
