extends SceneTree
## Llamadas de dibujo y objetos por cuadro en el partido 3D (promedio de 60 cuadros tras 120).
var _n := 0
var _llamadas := 0.0
var _objetos := 0.0
func _initialize() -> void:
	var e := (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(e)
	process_frame.connect(_cuadro)
func _cuadro() -> void:
	_n += 1
	if _n > 120:
		_llamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_objetos += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if _n == 180:
		print("LLAMADAS=%d OBJETOS=%d" % [_llamadas / 60.0, _objetos / 60.0])
		quit()
