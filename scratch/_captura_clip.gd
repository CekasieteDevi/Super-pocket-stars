extends SceneTree
## Fotos de cerca de una jugada de la muestra: -- desde=93 hasta=96 paso=0.25 accion=control_pie
var _m: MuestraAnimaciones3D
var _t := 0.0
var _hasta := 0.0
var _paso := 0.25
var _accion := "control_pie"
var _camara_juego := false
var _ang := 70.0
var _dist := 4.5
var _cuadro_n := 0
var _modelo: Jugador3D = null
var _n := 0
var _desde := 0.0
var _buscando := true

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2: continue
		match kv[0]:
			"desde": _t = float(kv[1])
			"hasta": _hasta = float(kv[1])
			"paso": _paso = float(kv[1])
			"accion": _accion = kv[1]
			"camara": _camara_juego = kv[1] == "juego"
			"ang": _ang = float(kv[1])
			"dist": _dist = float(kv[1])
	_desde = _t
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	_m.en_loop = false
	root.add_child(_m)
	process_frame.connect(_cuadro)

func _cuadro() -> void:
	var rep := _m.reproductor
	if rep == null or rep.fotogramas.is_empty(): return
	rep.pausado = true
	var v := rep.vista as VistaCancha3D
	v._posicion_previa = -100.0
	rep.posicion = _t
	var idx := int(_t)
	rep._mostrar(idx, _t - idx)
	if _camara_juego:
		for _i in 20: rep._seguir_camara(idx, 0.05)
	if _buscando and _accion == "ninguna":
		_buscando = false
		_t = _desde
		return
	if _buscando:
		for p in v._pies:
			if str(p.get("accion", "")) == _accion:
				_modelo = p["modelo"]
		if _modelo == null:
			_t += 0.25
		else:
			_buscando = false
			_t = _desde
		return
	if _modelo != null and not _camara_juego:
		var m := _modelo
		var frente := Vector3(sin(m.rotation.y), 0.0, cos(m.rotation.y))
		var ojo := m.global_position + frente.rotated(Vector3.UP, deg_to_rad(_ang)) * _dist + Vector3(0, 1.4 + _dist * 0.25, 0)
		v.camara_forzada = Transform3D.IDENTITY.translated(ojo).looking_at(m.global_position + Vector3(0, 0.7, 0), Vector3.UP)
	_cuadro_n += 1
	if _cuadro_n < 4: return
	_cuadro_n = 0
	var info := ""
	if _modelo != null:
		var acc := ""
		for p in v._pies:
			if p["modelo"] == _modelo: acc = "%s %.2f" % [p.get("accion", ""), float(p.get("fase", 0))]
		info = "pelota y=%.2f  Pie_R y=%.2f Pecho y=%.2f  dist pie %.2f  %s" % [v._pelota.global_position.y, _modelo.ancla("Pie_R").y,
			_modelo.ancla("Pecho").y, v._pelota.global_position.distance_to(_modelo.ancla("Pie_R")), acc]
	if _modelo != null:
		info += "  frente (%.2f,%.2f)" % [sin(_modelo.rotation.y), cos(_modelo.rotation.y)]
	print("t=%.2f %s" % [_t, info])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/clip"))
	root.get_texture().get_image().save_png("res://scratch/clip/c_%02d.png" % _n)
	_n += 1
	_t += _paso
	if _t > _hasta + 0.001: quit()
