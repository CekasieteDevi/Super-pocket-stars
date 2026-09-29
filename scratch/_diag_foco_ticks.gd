extends SceneTree
## Bug 3D-07: tick a tick alrededor de un tramo con `foco`.
##   -- division=1 semilla=N [corte_viejo] desde=T hasta=T
var _p: Prototipo3D
var _n := 0
func _initialize() -> void:
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null or _n < 3: return
	var fotos: Array = rep.fotogramas
	var desde := 0
	var hasta := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("desde="): desde = int(arg.trim_prefix("desde="))
		if arg.begins_with("hasta="): hasta = int(arg.trim_prefix("hasta="))
	for k in range(desde, mini(hasta + 1, fotos.size())):
		var f: Dictionary = fotos[k]
		var foco = f.get("foco", null)
		var ev := []
		for e in f.get("eventos", []):
			ev.append(str(e.get("tipo", "")) if e is Dictionary else str(e))
		var ac := []
		for a in f.get("acciones", []):
			ac.append("%d:%s" % [int(a.get("clave", -1)), str(a.get("accion", ""))])
		print("%d det %d pel (%.1f,%.1f) pos %d foco %s cambios %d corte %s reub %s ev %s ac %s" % [
			k, int(f.get("detenido", 0)), float(f["pelota"]["x"]), float(f["pelota"]["y"]),
			int(f["pelota"]["poseedor_id"]),
			"-" if foco == null else "(%.1f,%.1f)" % [float(foco["x"]), float(foco["y"])],
			f.get("cambios", []).size(), f.get("corte", false), f.get("reubicacion", false), ev, ac])
	quit()
