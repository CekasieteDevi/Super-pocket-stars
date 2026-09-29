extends SceneTree
## Señales de los oficiales y dónde está su utilería: -- clip=26 desde=598 hasta=606
var _m: MuestraAnimaciones3D
var _desde := 0.0
var _hasta := 0.0
var _n := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "desde": _desde = float(kv[1])
		if kv.size() == 2 and kv[0] == "hasta": _hasta = float(kv[1])
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _n > 3000: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _desde or _n % 20 != 0: return
	if pos > _hasta: quit(); return
	for e in v.entidades:
		if str(e.get("tipo", "")) != "oficial": continue
		var clave := "of_%s" % str(e.get("rol_oficial", ""))
		var m: Jugador3D = v._personas.get(clave)
		var cosas: Dictionary = v._utileria.get(clave, {})
		var txt := ""
		for k in cosas:
			var nodo: Node3D = cosas[k]
			txt += " %s vis=%s en %s" % [k, nodo.visible, str(nodo.global_position.snapped(Vector3.ONE * 0.01))]
		print("pos %.2f %s senal=%s pos=%s anim=%s%s  foco=%s" % [pos, clave, e.get("senal", ""), str(e["pos"]),
			m._anim_actual if m else "-", txt, str(v._foco_oficial)])
