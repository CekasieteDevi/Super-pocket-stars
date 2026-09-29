extends SceneTree
## Qué animación usa cada jugador en un tramo del prototipo: -- division=1 desde=N hasta=M
var _p: Prototipo3D
var _n := 0
var _desde := 100.0
var _hasta := 180.0
var _cuenta := {}
var _forcejeos := 0
var _cambios := 0
var _prev := {}
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
	if _n == 5:
		rep.posicion = _desde
		rep._idx_congelado = -1
		rep._festejo_restante = 0.0
		rep.velocidad = 4.0
	if _n < 8: return
	var v := rep.vista as VistaCancha3D
	if rep.posicion > _hasta or _n > 20000:
		print("ANDARES ", _cuenta, " cambios de anim por segundo de partido: %.2f" % [_cambios / maxf((_hasta - _desde) * 0.25, 0.01)])
		print("QUITES ", v._quites.size(), " FORCEJEOS activos vistos ", _forcejeos)
		quit(); return
	for clave in v._personas:
		var p: Jugador3D = v._personas[clave]
		if not p.visible or clave.begins_with("of_"): continue
		var a := str(p._anim_actual)
		_cuenta[a] = int(_cuenta.get(a, 0)) + 1
		if _prev.has(clave) and _prev[clave] != a: _cambios += 1
		_prev[clave] = a
	_forcejeos += v._forcejeos.size()
