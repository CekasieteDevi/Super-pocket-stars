extends SceneTree
## Prototipo 3D sin ventana: lista tiros libres con barrera y cambios.
## -- division=1 [desde=N hasta=M] (con desde/hasta imprime la pelota cuadro a cuadro)
var _p: Prototipo3D
var _n := 0
var _desde := -1.0
var _hasta := -1.0
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "desde": _desde = float(kv[1])
		if kv.size() == 2 and kv[0] == "hasta": _hasta = float(kv[1])
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	var v := rep.vista as VistaCancha3D
	if _n == 5:
		for b in v._barreras:
			var k := int(b.get("saque", -1))
			print("BARRERA saque=%d minuto=%s vuelo=%s" % [k, str(rep.fotogramas[k].get("minuto", "")), str(b.get("vuelo", {}))])
		for k in rep.fotogramas.size():
			var f: Dictionary = rep.fotogramas[k]
			if not (f.get("cambios", []) as Array).is_empty() and (k == 0 or (rep.fotogramas[k - 1].get("cambios", []) as Array).is_empty()):
				print("CAMBIO desde %d minuto %s foco=%s" % [k, str(f.get("minuto", "")), str(f.get("foco", null))])
		if _desde < 0: quit(); return
		rep.posicion = _desde
		rep._idx_narrado = int(_desde)
		rep._relato_restante = 0.0
		rep._festejo_restante = 0.0
		rep._parpadeo_restante = 0.0
		rep._idx_congelado = -1
		rep._festejo_grupo.clear()
	if _desde < 0 or _n < 6: return
	if rep.posicion > _hasta: quit(); return
	if _n % 1 != 0: return
	var b := v._pelota.global_position
	var e_p := Vector2.ZERO
	var z := 0.0
	for e in v.entidades:
		if str(e.get("tipo", "")) == "pelota":
			e_p = e["pos"]; z = float(e.get("z", 0.0))
	var idx := int(rep.posicion)
	print("cond=%s corr=%s | " % [str(v._conduccion.snapped(Vector2.ONE*0.01)), str(v._correccion.snapped(Vector3.ONE*0.01))], "pos %.2f pelota=(%.2f,%.2f,y=%.2f) rep=(%.2f,%.2f,z=%.2f) motor=(%.1f,%.1f) det=%s acc=%s" % [rep.posicion, b.x, b.z, b.y, e_p.x, e_p.y, z,
		rep.fotogramas[idx]["pelota"]["x"], rep.fotogramas[idx]["pelota"]["y"], str(rep.fotogramas[idx].get("detenido", "")),
		str((rep.fotogramas[idx].get("acciones", []) as Array).map(func(a): return "%s:%s" % [a["clave"], a["accion"]]))])
