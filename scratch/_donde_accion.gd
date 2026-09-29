extends SceneTree
func _initialize() -> void:
	var m: MuestraAnimaciones3D = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	m.en_loop = false
	root.add_child(m)
	_m = m
	process_frame.connect(_buscar)

var _m: MuestraAnimaciones3D
func _buscar() -> void:
	var m := _m
	if m.reproductor == null or m.reproductor.fotogramas.is_empty(): return
	var buscada := OS.get_cmdline_user_args()[0]
	var lista: Array = m.reproductor.fotogramas
	for i in lista.size():
		for a in lista[i].get("acciones", []):
			if str(a["accion"]) == buscada:
				var clip := 0
				for c in m._rotulos.size():
					if i >= int(m._rotulos[c][0]): clip = c + 1
				print("ENCONTRADA idx=", i, " clip=", clip, " clave=", a["clave"], " ", a)
	quit()
