extends SceneTree
var _p: Prototipo3D
var _n := 0
var _desde := 363.0
var _hasta := 369.0
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
	if _n == 3:
		rep.posicion = _desde; rep._idx_narrado = int(_desde); rep._relato_restante = 0.0
		rep._festejo_restante = 0.0; rep._parpadeo_restante = 0.0; rep._idx_congelado = -1; rep._festejo_grupo.clear()
	if _n < 5: return
	if rep.posicion > _hasta or _n > 3000: quit(); return
	if _n % 3 != 0: return
	var v := rep.vista as VistaCancha3D
	var idx := int(rep.posicion)
	var txt := ""
	for clave in v._personas:
		if not clave.ends_with("_1"): continue
		var p: Jugador3D = v._personas[clave]
		if not p.visible: continue
		var fwd := p.global_transform.basis.z
		txt += " %s[%s t=%.2f (%.1f,%.1f,y%.2f) mira=(%.2f,%.2f) esp=%s]" % [clave.substr(0, 11), p._anim_actual, p.animador.current_animation_position, p.global_position.x, p.global_position.z, p.global_position.y, fwd.x, fwd.z, str(p.espejado)]
	var b := v._pelota.global_position
	var motor_arq := ""
	for j in rep.fotogramas[idx]["jugadores"]:
		if str(j.get("rol", "")) == "ARQ" and absf(float(j["x"])) > 40: motor_arq += "(%.1f,%.1f)" % [j["x"], j["y"]]
	print("pos %.2f pelota=(%.1f,%.1f,y%.2f) motor_arq=%s acc=%s |%s" % [rep.posicion, b.x, b.z, b.y, motor_arq, str((rep.fotogramas[idx].get("acciones", []) as Array).map(func(a): return "%s:%s" % [a["clave"], a["accion"]])), txt])
	if _n % 30 == 0: print("   mira_vuela ", v._mira_vuela)
