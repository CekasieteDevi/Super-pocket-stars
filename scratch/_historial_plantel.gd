extends SceneTree
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frenada="): MotorEspacial.pesos()["fisica"]["frenada"] = float(a.trim_prefix("frenada="))
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(4417, "Club Prueba")
	Historial.temporada = gs.temporada_actual
	while gs.hay_fecha_pendiente():
		gs.jugar_siguiente_fecha()
	var antes: Array = gs.equipo_jugador.jugadores.map(func(j): return int(j["id"]))
	var filas_antes := 0
	for j in gs.equipo_jugador.jugadores:
		for f in j.get("carrera", []):
			if int(f["pj"]) > 0: filas_antes += 1
	print("ANTES DEL CIERRE plantel %d, filas con pj %d" % [antes.size(), filas_antes])
	pass
	var filas := 0
	for j in gs.equipo_jugador.jugadores:
		var pj := 0
		for f in j.get("carrera", []): pj += int(f["pj"])
		if pj > 0: filas += 1
		print("  %s %s pj=%d %s" % [str(j["id"]), str(j.get("posicion", "")), pj, "nuevo" if not antes.has(int(j["id"])) else ""])
	print("DESPUES filas %d plantel %d" % [filas, gs.equipo_jugador.jugadores.size()])
	gs.free()
	quit()
