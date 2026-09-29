extends SceneTree
var _m: MuestraAnimaciones3D
func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	_m.en_loop = false
	root.add_child(_m)
	process_frame.connect(_ver)
func _ver() -> void:
	var rep := _m.reproductor
	if rep == null or rep.fotogramas.is_empty(): return
	var f: Dictionary = rep.fotogramas[369]
	print("CLAVES FOTO ", f.keys())
	print("PELOTA ", f["pelota"])
	print("JUG ", VistaPartido._jugador_en(f, 7))
	quit()
