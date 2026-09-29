extends SceneTree
## Foto del partido animado del juego con la simulación 3D (partida nueva en
## memoria, no guarda nada): -- [tick=300] [salida=res://scratch/juego_3d.png] [2d]
var _main: Control
var _n := 0
var _tick := 300.0
var _salida := "res://scratch/juego_3d.png"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tick="): _tick = float(a.trim_prefix("tick="))
		if a.begins_with("salida="): _salida = a.trim_prefix("salida=")
	call_deferred("_correr")

func _correr() -> void:
	var gs = root.get_node("GameState")
	gs.partida_nueva(7311)
	var equipos: Array = gs.piramide.divisiones[gs.division_jugador].equipos
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var r := MotorEspacial.simular(equipos[0], equipos[1], rng, true)
	gs.ultimo_resultado = {"local": equipos[0].nombre, "visitante": equipos[1].nombre,
		"gl": r["goles_local"], "gv": r["goles_visitante"], "goles_log": []}
	gs.ultimos_fotogramas = r["fotogramas"]
	_main = load("res://ui/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	_main.capa_inicio.visible = false
	_main.simulacion_elegida = "2d" if OS.get_cmdline_user_args().has("2d") else "3d"
	_main._mostrar_partido_animado()
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _n == 3:
		_main.vista_partido.posicion = _tick
	if _n == 40:
		root.get_texture().get_image().save_png(_salida)
		print("FOTO ", _salida, " vista ", _main.vista_partido.vista.get_class(), " ", _main.vista_partido.vista.get_script().resource_path)
		quit()
