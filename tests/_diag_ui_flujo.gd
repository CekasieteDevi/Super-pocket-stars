extends Node

## Diagnóstico de la pantalla real: entra al juego, juega una fecha con el
## botón Jugar, mira el partido V2 en la vista hasta el final y simula el
## resto de la temporada. Se agrega TEMPORALMENTE como autoload en
## project.godot (PruebaUI="*res://tests/_diag_ui_flujo.gd") y se borra al
## terminar. Imprime OK/FALLA y FALLOS=n.

var fallos := 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK: %s" % m)
	else:
		fallos += 1
		print("FALLA: %s" % m)


func _ready() -> void:
	_correr.call_deferred()


func _correr() -> void:
	for i in 5:
		await get_tree().process_frame
	var main = get_tree().current_scene
	var gs = get_node("/root/GameState")
	gs.ruta_partida = "user://partida_test_ui.json"
	gs.partida_nueva(4242, "Club UI")
	main._entrar_al_juego()
	for partido in 2:
		gs.avanzar_hasta_el_partido()
		if main._avisar_alineacion():
			main._cerrar_modal_alineacion()
			Alineacion.arreglar(gs.equipo_jugador)
		var hist_antes: int = gs.historial_partidos.size()
		await main._on_jugar_fecha()
		_ok(gs.historial_partidos.size() == hist_antes + 1, "partido %d: Jugar juega el partido." % partido)
		_ok(main.paneles["partido_animado"].visible, "partido %d: la pantalla del partido se abre." % partido)
		var vista = main.vista_partido_v2
		vista.velocidad = 16.0
		var cuadros := 0
		while not vista._terminado and cuadros < 20000:
			await get_tree().process_frame
			cuadros += 1
		var goles: PackedInt32Array = vista._partido.get_goles()
		var r: Dictionary = gs.ultimo_resultado
		_ok(vista._terminado, "partido %d: la vista llega al final (%d cuadros)." % [partido, cuadros])
		_ok(int(goles[0]) == int(r["gl"]) and int(goles[1]) == int(r["gv"]),
			"partido %d: la vista termina %d-%d como el resultado %d-%d." % [partido, goles[0], goles[1], r["gl"], r["gv"]])
		main._volver_al_club()
	var temporada: int = gs.temporada_actual
	var inicio := Time.get_ticks_msec()
	await main._on_simular_temporada()
	print("  simular tardo %.1f s" % ((Time.get_ticks_msec() - inicio) / 1000.0))
	_ok(gs.temporada_actual == temporada + 1, "Simular temporada cierra el año.")
	_ok(main.get_children().filter(func(n): return n is ColorRect and not n.is_queued_for_deletion() and n.color.a < 0.5 and n.mouse_filter == Control.MOUSE_FILTER_STOP).is_empty(),
		"no queda el velo de espera puesto.")
	print("FALLOS=%d" % fallos)
	gs.borrar_partida()
	get_tree().quit()
