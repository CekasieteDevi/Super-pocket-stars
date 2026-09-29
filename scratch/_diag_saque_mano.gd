extends SceneTree
## Alrededor del saque de mano del arquero en la muestra: -- clip=N
var _m: MuestraAnimaciones3D
var _t := 0.0
var _fin := 0.0
var _pend := false
func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	_m.en_loop = false
	root.add_child(_m)
	process_frame.connect(_cuadro)
func _cuadro() -> void:
	var rep := _m.reproductor
	if rep == null or rep.fotogramas.is_empty(): return
	rep.pausado = true
	var v := rep.vista as VistaCancha3D
	if _fin == 0.0:
		var clip := 7
		for a in OS.get_cmdline_user_args():
			if a.begins_with("clip="): clip = int(a.trim_prefix("clip="))
		_t = float(_m._rotulos[clip - 1][0])
		_fin = float(_m._fin_del_clip(clip - 1))
	if _pend and int(_t * 10) % 10 == 0 and _t < _fin - 20.0 + 1.0 and _t > 160.0 and _t < 161.0:
		print("SAQUES ", v._saques_mano, " MANOS ", v._manos_arquero)
	if _pend:
		for pie in v._pies:
			var g: Dictionary = pie["gesto"]
			var p3: Jugador3D = pie["modelo"]
			if v._sostiene(int(pie.get("id", -1))) or str(pie["accion"]) in ["agarra", "lanza_arquero", "voleo_arquero", "saque_arco"]:
				var pel := v._pelota.position
				print("tiene %s %s " % [p3.tiene("Agarrar"), p3.tiene("Arquero_Lanza")], "t=%.1f id %d acc '%s' anim %s g=%s dt=%s sost=%s | pelota %s manoR %s pieR %s corr %s" % [_t - 0.1, int(pie["id"]), pie["accion"], p3._anim_actual,
					str(g.get("accion", "")), str(snappedf(float(g.get("dt", 0.0)), 0.01)), str(v._sostiene(int(pie["id"]))),
					str(pel.snappedf(0.01)), str(p3.ancla("Mano_R").snappedf(0.01)), str(p3.ancla("Pie_R").snappedf(0.01)), str(v._correccion.snappedf(0.01))])
	if _t >= _fin: quit(); return
	var idx := int(_t)
	rep.posicion = _t
	rep._mostrar(idx, _t - float(idx))
	_pend = true
	_t += 0.1
