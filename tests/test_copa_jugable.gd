extends SceneTree

## El cruce de copa del jugador lo JUEGA el jugador.
##
## Antes las rondas de copa se resolvian solas dentro de avanzar_un_dia:
## el partido propio se simulaba en silencio y el jugador se enteraba del
## resultado por el feed, sin poder verlo ni elegir el once.

const SEED := 5150

const GUION := preload("res://game/game_state.gd")


func _init() -> void:
	var fallos := 0
	fallos += _test_la_ronda_propia_frena_el_calendario()
	fallos += _test_el_partido_propio_se_ve()
	fallos += _test_sin_cruce_propio_la_ronda_se_resuelve_sola()
	fallos += _test_saltar_la_temporada_no_se_traba()
	fallos += _test_el_nombre_de_la_ronda()
	print("\nFALLOS=%d" % fallos)
	quit()


func _nueva_partida() -> Node:
	var gs = GUION.new()
	gs.partida_nueva(SEED)
	return gs


## Adelanta hasta el primer dia en que al jugador le toca copa. Devuelve
## null si en toda la temporada no le toco ninguna (no deberia pasar: el
## cuadro de la Copa Nacional lo mete si o si en la primera ronda).
func _hasta_la_copa_propia(gs: Node) -> Node:
	var pasos := 0
	while pasos < 4000:
		pasos += 1
		if gs.hay_partido_de_copa_hoy():
			return gs
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
		else:
			gs.avanzar_un_dia()
	return null


func _test_la_ronda_propia_frena_el_calendario() -> int:
	print("=== El dia no avanza con un cruce de copa sin jugar ===")
	var gs := _nueva_partida()
	if _hasta_la_copa_propia(gs) == null:
		print("FALLA: en toda la temporada al jugador no le toco ninguna ronda de copa.")
		return 1
	var dia_antes: int = gs.dia_temporada
	var novedades: Array = gs.avanzar_un_dia()
	if gs.dia_temporada != dia_antes or not novedades.is_empty():
		print("FALLA: avanzo el dia con un cruce de copa pendiente.")
		return 1
	var rival = gs.rival_de_copa()
	if rival == null or rival == gs.equipo_jugador:
		print("FALLA: no hay rival de copa, o el rival es el propio equipo.")
		return 1
	print("OK: el calendario espera. Toca %s contra %s (%s)." % [
		gs.copa_de_hoy().nombre, rival.nombre,
		"de local" if gs.copa_de_local() else "de visitante"])
	return 0


func _test_el_partido_propio_se_ve() -> int:
	print("\n=== El cruce propio se juega con fotogramas y entra al historial ===")
	var gs := _nueva_partida()
	if _hasta_la_copa_propia(gs) == null:
		print("FALLA: no se llego a ninguna ronda de copa propia.")
		return 1
	var copa = gs.copa_de_hoy()
	var rival = gs.rival_de_copa()
	var historial_antes: int = gs.historial_partidos.size()
	gs.jugar_partido_de_copa()

	if gs.ultimos_fotogramas.is_empty():
		print("FALLA: el partido de copa no dejo fotogramas para verlo.")
		return 1
	if gs.historial_partidos.size() != historial_antes + 1:
		print("FALLA: el cruce de copa no entro al historial.")
		return 1
	var reg: Dictionary = gs.historial_partidos[0]
	if str(reg.get("torneo", "")) != copa.nombre:
		print("FALLA: el historial no marca el torneo (dice '%s')." % str(reg.get("torneo", "")))
		return 1
	var nombres := [str(reg["local"]), str(reg["visitante"])]
	if not nombres.has(gs.equipo_jugador.nombre) or not nombres.has(rival.nombre):
		print("FALLA: el partido del historial no es el cruce que tocaba.")
		return 1
	if gs.hay_partido_de_copa_hoy():
		print("FALLA: despues de jugarlo sigue habiendo cruce de copa hoy.")
		return 1
	if gs.avanzar_un_dia().is_empty() and gs.dia_temporada == 0:
		print("FALLA: el calendario no se destrabo despues del cruce.")
		return 1
	print("OK: %s %d-%d %s, %d fotogramas, y el dia vuelve a correr." % [
		reg["local"], int(reg["gl"]), int(reg["gv"]), reg["visitante"],
		gs.ultimos_fotogramas.size()])
	return 0


func _test_sin_cruce_propio_la_ronda_se_resuelve_sola() -> int:
	print("\n=== Sin el jugador en el cuadro, la ronda no frena nada ===")
	var gs := _nueva_partida()
	# Se lo saca del cuadro de las dos copas: sin cruce propio, las rondas
	# tienen que seguir resolviendose solas como siempre.
	var copas: Array = [gs.copa_nacional]
	copas.append_array(gs.copas_division)
	for c in copas:
		var limpios := []
		for par in c.partidos_pendientes:
			if par[0] != gs.equipo_jugador and par[1] != gs.equipo_jugador:
				limpios.append(par)
		# El cuadro tiene que quedar par o _armar_pares revienta despues.
		if limpios.size() < c.partidos_pendientes.size():
			limpios.pop_back()
		c.partidos_pendientes = limpios

	var rondas_antes: int = gs.copa_nacional.historial.size()
	var pasos := 0
	while pasos < 200 and gs.copa_nacional.historial.size() == rondas_antes:
		pasos += 1
		if gs.hay_partido_de_copa_hoy():
			print("FALLA: freno el calendario sin el jugador en el cuadro.")
			return 1
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
		else:
			gs.avanzar_un_dia()
	if gs.copa_nacional.historial.size() == rondas_antes:
		print("FALLA: la Copa Nacional no jugo ninguna ronda en %d pasos." % pasos)
		return 1
	print("OK: la ronda se jugo sola en %d pasos, sin frenar el dia." % pasos)
	return 0


func _test_saltar_la_temporada_no_se_traba() -> int:
	print("\n=== 'Simular resto de la temporada' no se traba con la copa ===")
	var gs := _nueva_partida()
	var temporada: int = gs.temporada_actual
	gs.simular_temporada_completa()
	if gs.temporada_actual == temporada:
		print("FALLA: la temporada no cerro: el modo saltar se trabo en la copa.")
		return 1
	# El campeon se mira en copas_pasadas: al cerrar la temporada las copas
	# se rearman vacias para el ano que viene (GameState._armar_copas).
	var campeon := str(gs.copas_pasadas.get("rey", {}).get("campeon", ""))
	if campeon == "":
		print("FALLA: la Copa Nacional quedo sin campeon al cerrar la temporada.")
		return 1
	print("OK: cerro la temporada %d y la Copa Nacional tuvo campeon (%s)." % [
		temporada, campeon])
	return 0


## La portada anuncia la ronda por su nombre: "Cuartos de final" dice
## mucho mas que "ronda 6 de la Copa Nacional".
func _test_el_nombre_de_la_ronda() -> int:
	print("
=== Las rondas tienen nombre ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var esperados := {2: "Final", 4: "Semifinal", 8: "Cuartos de final",
		16: "Octavos de final", 32: "Ronda de 32"}
	for vivos in esperados:
		var equipos := []
		for i in range(vivos):
			var t := Team.new()
			t.nombre = "Equipo %d" % i
			equipos.append(t)
		var copa := Copa.iniciar("Copa Prueba", equipos, rng)
		var dice: String = copa.ronda_actual()
		if dice != esperados[vivos]:
			print("FALLA: con %d equipos vivos dice '%s' y no '%s'." % [
				vivos, dice, esperados[vivos]])
			return 1
	# Con campeon ya no queda ronda por nombrar.
	var copa_vacia := Copa.iniciar("Copa Prueba", [], rng)
	if copa_vacia.ronda_actual() != "":
		print("FALLA: una copa sin cruces pendientes igual nombra una ronda.")
		return 1
	print("OK: Final, Semifinal, Cuartos, Octavos y 'Ronda de 32'.")
	return 0
