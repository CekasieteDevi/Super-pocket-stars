extends SceneTree
var _p: Prototipo3D
var _n := 0
var _desde := 139.0
var _hasta := 146.0
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
	if _n % 10 != 0: return
	var v := rep.vista as VistaCancha3D
	var txt := ""
	for i in v._jugadores_cuadro.size():
		var j: Dictionary = v._jugadores_cuadro[i]
		var id := int(j["id"])
		var ent: Dictionary = {}
		var c := 0
		for e in v.entidades:
			if str(e.get("tipo", "")) == "jugador":
				if c == i: ent = e
				c += 1
		var clave := VistaCancha3D._clave(ent, i) if not ent.is_empty() else ""
		var p: Jugador3D = v._personas.get(clave)
		if p == null: continue
		var a := str(p._anim_actual)
		if a == "Festejar" or id in [8, 9, 10] or str(ent.get("accion", "")) == "festeja":
			txt += " %d[%s acc=%s pos=(%.0f,%.0f)]" % [id, a, str(ent.get("accion", "")), p.global_position.x, p.global_position.z]
	print("pos %.2f festejo_rest=%.1f ticks=%.1f |%s" % [rep.posicion, rep._festejo_restante, v._festejo_ticks, txt])
