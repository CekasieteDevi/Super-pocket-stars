extends SceneTree
## Pelota dibujada cuadro a cuadro en reproducción real: -- clip=23 desde=539.5 hasta=541.8
var _m: MuestraAnimaciones3D
var _desde := 0.0
var _hasta := 0.0
var _n := 0
var _prev := Vector3.INF

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
	if _n > 4000: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _desde: return
	if pos > _hasta: quit(); return
	var b := v._pelota.global_position
	var paso := 0.0 if _prev == Vector3.INF else b.distance_to(_prev)
	_prev = b
	if _n % 6 == 0:
		print("pos %.3f pelota (%.2f, %.2f) y=%.2f paso %.2f camara (%.2f, %.2f)" % [pos, b.x, b.z, b.y, paso, v.camara.centro.x, v.camara.centro.y])
