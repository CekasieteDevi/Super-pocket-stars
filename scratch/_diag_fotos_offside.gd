extends SceneTree
var _m: MuestraAnimaciones3D
var _n := 0
func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	if _n < 30: return
	var f: Array = _m.reproductor.fotogramas
	print("total ", f.size())
	for i in range(610, f.size()):
		var fo: Dictionary = f[i]
		var ev := []
		for e in fo.get("eventos", []): ev.append("%s/%s" % [e.get("tipo", ""), e.get("resultado", "")])
		print("%d pelota=(%.1f,%.1f) foco=%s det=%s reub=%s ev=%s" % [i, fo["pelota"]["x"], fo["pelota"]["y"], str(fo.get("foco", null)), str(fo.get("detenido", "")), str(fo.get("reubicacion", fo.get("corte", ""))), str(ev)])
	quit()
