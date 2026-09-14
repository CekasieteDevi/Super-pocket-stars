extends SceneTree

## El playoff de ascenso se juega en el calendario, despues de la ultima
## fecha, y el club del jugador lo JUEGA.
##
## Antes lo simulaba Piramide.fin_de_temporada adentro del cierre: el 3°
## nunca veia su partido y solo se enteraba si ascendia.

const SEED := 7310

const GUION := preload("res://game/game_state.gd")


func _init() -> void:
	var fallos := 0
	fallos += _test_el_jugador_juega_su_playoff()
	fallos += _test_saltar_la_temporada_no_se_traba()
	print("\nFALLOS=%d" % fallos)
	quit()


## Juega todas las fechas y deja al club del jugador 3° de su division.
func _partida_terminando_tercero() -> Node:
	var gs = GUION.new()
	gs.partida_nueva(SEED)
	var pasos := 0
	while gs.hay_fecha_pendiente() and pasos < 5000:
		pasos += 1
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
		elif gs.hay_partido_de_copa_hoy():
			gs.resolver_ronda_de_copa()
		elif gs.hay_partido_internacional_hoy():
			gs.resolver_ronda_internacional()
		else:
			gs.avanzar_un_dia()
	var liga = gs.liga_jugador()
	var otros := []
	for nombre in liga.tabla_ordenada():
		if nombre != gs.equipo_jugador.nombre:
			otros.append(nombre)
	liga.tabla[otros[0]]["pts"] = 1000
	liga.tabla[otros[1]]["pts"] = 999
	liga.tabla[gs.equipo_jugador.nombre]["pts"] = 998
	return gs


func _test_el_jugador_juega_su_playoff() -> int:
	print("=== El 3° juega el playoff despues de la ultima fecha ===")
	var gs := _partida_terminando_tercero()
	var temporada: int = gs.temporada_actual
	var pasos := 0
	while not gs.hay_partido_de_playoff_hoy() and gs.temporada_actual == temporada and pasos < 200:
		pasos += 1
		if gs.hay_partido_de_copa_hoy():
			gs.resolver_ronda_de_copa()
		elif gs.hay_partido_internacional_hoy():
			gs.resolver_ronda_internacional()
		else:
			gs.avanzar_un_dia()
	if not gs.hay_partido_de_playoff_hoy():
		print("FALLA: la temporada cerro sin que el 3° jugara el playoff.")
		return 1

	var dia_antes: int = gs.dia_temporada
	gs.avanzar_un_dia()
	if gs.dia_temporada != dia_antes:
		print("FALLA: el dia avanzo con el playoff propio sin jugar.")
		return 1

	var division: int = gs.division_jugador
	var arriba: Array = gs.piramide.divisiones[division - 1].tabla_ordenada()
	var rival = gs.rival_de_playoff()
	if rival == null or rival.nombre != arriba[17] or gs.playoff_de_local():
		print("FALLA: el rival no es el 18° de la division de arriba, o el 3° juega de local.")
		return 1
	var limites: int = gs.piramide.divisiones.size() - 1
	if gs.playoffs_ascenso.size() != limites - 1:
		print("FALLA: los playoffs de la IA no se jugaron (%d de %d)." % [
			gs.playoffs_ascenso.size(), limites - 1])
		return 1
	print("OK: el calendario espera. %s visita a %s, y los otros %d playoffs ya se jugaron." % [
		gs.equipo_jugador.nombre, rival.nombre, limites - 1])

	gs.jugar_partido_de_playoff()
	if gs.ultimos_fotogramas.is_empty():
		print("FALLA: el playoff no dejo fotogramas para verlo.")
		return 1
	if str(gs.historial_partidos[0].get("torneo", "")) != "Playoff de ascenso":
		print("FALLA: el playoff no entro al historial con su nombre.")
		return 1
	var jugado: Dictionary = gs.playoffs_ascenso.get(str(division - 1), {})
	if jugado.is_empty() or gs.hay_partido_de_playoff_hoy():
		print("FALLA: el playoff propio no quedo registrado como jugado.")
		return 1
	var sube: bool = str(jugado["ganador"]) == gs.equipo_jugador.nombre
	if str(jugado["ganador"]) != gs.equipo_jugador.nombre and str(jugado["ganador"]) != rival.nombre:
		print("FALLA: el playoff termino sin ganador (%d-%d, %s)." % [
			int(jugado["gl"]), int(jugado["gv"]), str(jugado["definicion"])])
		return 1

	pasos = 0
	while gs.temporada_actual == temporada and pasos < 50:
		pasos += 1
		if gs.hay_partido_de_copa_hoy():
			gs.resolver_ronda_de_copa()
		elif gs.hay_partido_internacional_hoy():
			gs.resolver_ronda_internacional()
		else:
			gs.avanzar_un_dia()
	if gs.temporada_actual == temporada:
		print("FALLA: la temporada no cerro despues del playoff.")
		return 1
	var esperada: int = division - 1 if sube else division
	if gs.division_jugador != esperada:
		print("FALLA: %d-%d y el club quedo en la division %d (se esperaba %d)." % [
			int(jugado["gl"]), int(jugado["gv"]), gs.division_jugador + 1, esperada + 1])
		return 1
	if not gs.playoffs_ascenso.is_empty():
		print("FALLA: los playoffs de la temporada vieja quedaron para la nueva.")
		return 1
	print("OK: %d-%d, el cierre aplica ese resultado: division %d." % [
		int(jugado["gl"]), int(jugado["gv"]), gs.division_jugador + 1])
	return 0


func _test_saltar_la_temporada_no_se_traba() -> int:
	print("\n=== 'Simular resto de la temporada' no se traba con el playoff ===")
	var gs := _partida_terminando_tercero()
	var temporada: int = gs.temporada_actual
	gs.simular_temporada_completa()
	if gs.temporada_actual == temporada:
		print("FALLA: la temporada no cerro: el modo saltar se trabo en el playoff.")
		return 1
	print("OK: cerro la temporada %d con el club jugando el playoff." % temporada)
	return 0
