extends SceneTree
## Fotos de cerca de un jugador en el partido del prototipo 3D, en vivo:
##   --fixed-fps 30 -- division=1 semilla=5 desde=536 hasta=548 paso=0.5 id=0 [ang=70 dist=4.5] [nombre=arq]
## Guarda scratch/clip/<nombre>_NN.png e imprime anim/tiempo del modelo.
var _p: Prototipo3D
var _n := 0
var _desde := 0.0
var _hasta := 0.0
var _paso := 0.5
var _id := 0
var _ang := 70.0
var _dist := 4.5
var _nombre := "arq"
var _proxima := 0.0
var _k := 0
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2: continue
		match kv[0]:
			"desde": _desde = float(kv[1])
			"hasta": _hasta = float(kv[1])
			"paso": _paso = float(kv[1])
			"id": _id = int(kv[1])
			"ang": _ang = float(kv[1])
			"dist": _dist = float(kv[1])
			"nombre": _nombre = kv[1]
	_proxima = _desde
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 5:
		var inicio := maxf(0.0, _desde - 6.0)
		rep.posicion = inicio
		rep._idx_narrado = int(inicio)
		rep._relato_restante = 0.0
		rep._festejo_restante = 0.0
		rep._parpadeo_restante = 0.0
		rep._idx_congelado = -1
		rep._festejo_grupo.clear()
	if _n < 6: return
	if _n > 20000 or rep.posicion > _hasta + 0.01: quit(); return
	var v := rep.vista as VistaCancha3D
	var m: Jugador3D = null
	var acc := ""
	for p in v._pies:
		if int(p.get("id", -1)) == _id:
			m = p["modelo"]
			acc = "%s %.2f" % [p.get("accion", ""), float(p.get("fase", 0))]
	if m == null: return
	var frente := Vector3(sin(m.rotation.y), 0.0, cos(m.rotation.y))
	var centro := m.global_position + Vector3(0, 0.5, 0)
	var ojo := centro + frente.rotated(Vector3.UP, deg_to_rad(_ang)) * _dist + Vector3(0, 1.0 + _dist * 0.25, 0)
	v.camara_forzada = Transform3D.IDENTITY.translated(ojo).looking_at(centro, Vector3.UP)
	if rep.posicion + 0.001 < _proxima: return
	_proxima += _paso
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/clip"))
	root.get_texture().get_image().save_png("res://scratch/clip/%s_%02d.png" % [_nombre, _k])
	var cad := m.hueso("Cadera").origin
	print("FOTO %s_%02d t=%.2f anim=%s %.2f acc=%s pos(%.2f,%.2f) cadera(%.2f,%.2f,%.2f) pelota(%.2f,%.2f,%.2f)" % [_nombre, _k, rep.posicion,
		m._anim_actual, m.animador.current_animation_position if m.animador else -1.0, acc, m.global_position.x, m.global_position.z,
		cad.x, cad.y, cad.z, v._pelota.global_position.x, v._pelota.global_position.y, v._pelota.global_position.z])
	_k += 1
