extends SceneTree
var _p: Prototipo3D
var _n := 0
var _desde := 800.0
var _hasta := 806.0
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
	if rep.posicion > _hasta: quit(); return
	var v := rep.vista as VistaCancha3D
	for c in ["of_cuarto_arbitro", "of_arbitro"]:
		var p: Jugador3D = v._personas.get(c)
		if p == null: continue
		var e_pos := Vector2.INF
		for e in v.entidades:
			if str(e.get("rol_oficial", "")) == c.trim_prefix("of_"): e_pos = e["pos"]
		print("pos %.2f %s dibujo=(%.1f,%.1f) ent=%s anim=%s v=%.1f desvio=%s lado=%s" % [rep.posicion, c, p.global_position.x, p.global_position.z, str(e_pos), p._anim_actual, float(v._odometro.get(c, [0,0,0])[2]), str(v._desvio_cuerpo.get(c, Vector2.ZERO)), str(v._lado_del_cambio())])
