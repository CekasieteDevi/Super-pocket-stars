extends SceneTree
## Reproducción real (con -- clip=N): altura de los pies del que lleva la
## pelota entre dos tiempos, para ver si las piernas se mueven.
## -- clip=15 desde=335 hasta=341
var _m: MuestraAnimaciones3D
var _n := 0
var _desde := 0.0
var _hasta := 0.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "desde": _desde = float(kv[1])
		if kv.size() == 2 and kv[0] == "hasta": _hasta = float(kv[1])
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _n > 900: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos > _hasta: quit()
	if pos < _desde or _n % 4 != 0: return
	var bola := Vector2(v._pelota.global_position.x, v._pelota.global_position.z)
	for p in v._pies:
		if (p["pos"] as Vector2).distance_to(bola) < 1.5:
			var m: Jugador3D = p["modelo"]
			print("pos %.2f accion=%s anim=%s  Pie_R %.2f Pie_L %.2f" % [pos, p["accion"], m._anim_actual, m.ancla("Pie_R").y, m.ancla("Pie_L").y])
