extends SceneTree
## Fotos del prototipo 3D en vivo: -- division=1 desde=N fotos=a,b,c nombre=x
var _p: Prototipo3D
var _n := 0
var _desde := 0.0
var _tiempos: Array = []
var _nombre := "proto"
var _k := 0
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2: continue
		if kv[0] == "desde": _desde = float(kv[1])
		if kv[0] == "nombre": _nombre = kv[1]
		if kv[0] == "fotos":
			for s in kv[1].split(","): _tiempos.append(float(s))
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 5:
		rep.posicion = _desde
		rep._idx_narrado = int(_desde)
		rep._relato_restante = 0.0
		rep._festejo_restante = 0.0
		rep._parpadeo_restante = 0.0
		rep._idx_congelado = -1
		rep._festejo_grupo.clear()
		var f: Dictionary = rep.fotogramas[int(_desde)]
		rep.vista.camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), rep.size)
	if _n < 6: return
	if _tiempos.is_empty() or _n > 6000: quit(); return
	if rep.posicion >= float(_tiempos[0]):
		root.get_texture().get_image().save_png("res://scratch/%s_%d.png" % [_nombre, _k])
		print("FOTO %s_%d en %.2f" % [_nombre, _k, rep.posicion])
		_k += 1
		_tiempos.pop_front()
