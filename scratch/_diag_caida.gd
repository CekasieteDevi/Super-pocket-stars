extends SceneTree
var _m: MuestraAnimaciones3D
func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	_m.en_loop = false
	root.add_child(_m)
	process_frame.connect(_ver)
func _ver() -> void:
	var lista: Array = _m.reproductor.fotogramas
	if lista.is_empty(): return
	for i in range(90, 100):
		var f: Dictionary = lista[i]
		var caido: Dictionary = {}
		for j in f["jugadores"]:
			if int(j["id"]) == 101010 or int(j.get("clave", -1)) == 101010: caido = j
		var txt := ""
		if not caido.is_empty():
			var c := Vector2(caido["x"], caido["y"])
			for j in f["jugadores"]:
				var d := Vector2(j["x"], j["y"]).distance_to(c)
				if d < 2.5 and j != caido: txt += " id%s a %.2f m" % [j["id"], d]
			txt = "caido (%.1f,%.1f) o=(%.2f,%.2f)" % [c.x, c.y, float(caido.get("ox", 0)), float(caido.get("oy", 0))] + txt
		print(i, " ", f.get("acciones", []), " ", txt, " pelota ", snappedf(f["pelota"]["x"], 0.1), ",", snappedf(f["pelota"]["y"], 0.1))
	quit()
