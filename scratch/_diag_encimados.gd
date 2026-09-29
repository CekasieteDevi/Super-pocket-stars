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
	var hist := {"<0.3": 0, "0.3-0.5": 0, "0.5-0.75": 0}
	var cuadros_con := 0
	for f in lista:
		var ps := []
		for j in f["jugadores"]: ps.append(Vector2(j["x"], j["y"]))
		var hay := false
		for a in ps.size():
			for b in range(a + 1, ps.size()):
				var d: float = ps[a].distance_to(ps[b])
				if d < 0.3:
					hist["<0.3"] += 1
					if hist["<0.3"] % 40 == 1:
						print("  cerca d=%.2f en %s  cuadro %d" % [d, ps[a], lista.find(f)])
				elif d < 0.5: hist["0.3-0.5"] += 1
				elif d < 0.75: hist["0.5-0.75"] += 1
				if d < 0.75: hay = true
		if hay: cuadros_con += 1
	print("PARES ", hist, " cuadros con encimados ", cuadros_con, "/", lista.size())
	quit()
