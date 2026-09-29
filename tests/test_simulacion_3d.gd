extends SceneTree

## Opción "Simulación" (3D / 2D): el partido animado del juego se ve con la
## cancha elegida (VistaCancha3D o VistaCancha) y se puede cambiar de una a
## otra entre partidos.
##
## Todo en memoria: la partida es nueva y no se guarda nada en disco (ni la
## partida ni user://opciones.cfg: se elige sin pasar por el OptionButton).

const SEED := 7311

var fallos := 0


func _init() -> void:
	call_deferred("_correr")


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		print("FALLA: " + texto)
		fallos += 1


func _correr() -> void:
	var gs = root.get_node("GameState")
	gs.partida_nueva(SEED)
	var equipos: Array = gs.piramide.divisiones[gs.division_jugador].equipos
	var local: Team = equipos[0]
	var visitante: Team = equipos[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var r := MotorEspacial.simular(local, visitante, rng, true)
	gs.ultimo_resultado = {"local": local.nombre, "visitante": visitante.nombre,
		"gl": r["goles_local"], "gv": r["goles_visitante"], "goles_log": []}
	gs.ultimos_fotogramas = r["fotogramas"]

	var main: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	main._mostrar_opciones()
	var opcion: OptionButton = main.option_simulacion
	_ok(opcion != null and opcion.item_count == 2 and opcion.get_item_text(0) == "3D"
		and opcion.get_item_text(1) == "2D", "Opciones tiene Simulación con 3D y 2D")

	main.simulacion_elegida = "3d"
	main._mostrar_partido_animado()
	for i in 10:
		await process_frame
	var vista = main.vista_partido.vista
	_ok(vista is VistaCancha3D, "con 3D el partido se ve en VistaCancha3D")
	if vista is VistaCancha3D:
		_ok(vista._personas.size() >= 22, "la cancha 3D tiene a los jugadores (%d)" % vista._personas.size())
		_ok(vista._pelota != null and vista._pelota.is_inside_tree(), "la cancha 3D tiene la pelota")
	var vistas := 0
	for hijo in main.vista_partido.get_children():
		if hijo is VistaCancha:
			vistas += 1
	_ok(vistas == 1, "una sola cancha en el partido (%d)" % vistas)

	main.simulacion_elegida = "2d"
	main._mostrar_partido_animado()
	await process_frame
	_ok(main.vista_partido.vista is VistaCancha and not (main.vista_partido.vista is VistaCancha3D),
		"con 2D vuelve la cancha de siempre")
	_ok(main.vista_partido.hud.get_index() > main.vista_partido.vista.get_index(),
		"el HUD queda arriba de la cancha")

	print("FALLOS=%d" % fallos)
	quit(1 if fallos > 0 else 0)
