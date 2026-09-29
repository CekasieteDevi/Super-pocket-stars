extends SceneTree
var _m: MuestraAnimaciones3D
var _n := 0
func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos > 114.0 and pos < 122.0 and _n % 3 == 0:
		for p in v._pies:
			var m: Jugador3D = p["modelo"]
			if (p["pos"] as Vector2).distance_to(Vector2(-0.3, 2.8)) < 1.2:
				print("pos %.2f accion=%s frente (%.2f,%.2f) en (%.1f,%.1f)" % [pos, p["accion"], sin(m.rotation.y), cos(m.rotation.y), p["pos"].x, p["pos"].y])
	if pos > 122.0: quit()
