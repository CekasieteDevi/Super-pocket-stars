extends SceneTree
## Reproducción real: qué hace el defensor `id` (animación, rumbo, posición
## dibujada y velocidad). -- clip=18 id=101001 desde=367.5 hasta=372
var _m: MuestraAnimaciones3D
var _n := 0
var _desde := 0.0
var _hasta := 0.0
var _id := -1
var _prev := Vector3.INF
var _t_prev := 0.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2: continue
		match kv[0]:
			"desde": _desde = float(kv[1])
			"hasta": _hasta = float(kv[1])
			"id": _id = int(kv[1])
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _n > 3000: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _desde: return
	if pos > _hasta: quit(); return
	if pos - _t_prev < 0.2 and not (v._festejo_ticks > 0.0 and _n % 2 == 0): return
	var indice := -1
	for i in v._jugadores_cuadro.size():
		if int(v._jugadores_cuadro[i]["id"]) == _id: indice = i
	if indice < 0 or indice >= v._pies.size(): return
	var p: Dictionary = v._pies[indice]
	var m: Jugador3D = p["modelo"]
	var g := m.global_position
	var vel := 0.0
	if _prev != Vector3.INF:
		vel = Vector2(g.x - _prev.x, g.z - _prev.z).length() / maxf((pos - _t_prev) * 0.25, 0.001)
	var th := m.rotation.y
	var derecha := Vector2(-cos(th), sin(th))
	var cab := m.ancla("Frente") - g
	var bola := v._pelota.global_position - g
	print("   cabeza a su derecha %.2f | pelota a su derecha %.2f" % [Vector2(cab.x, cab.z).dot(derecha), Vector2(bola.x, bola.z).dot(derecha)])
	print("pos %.2f anim=%s t=%.2f frente (%.2f,%.2f) en (%.2f,%.2f) %.1f m/s  pie %.2f cabeza %.2f festejo %.1f" % [pos, m._anim_actual,
		m.animador.current_animation_position if m.animador else 0.0, sin(m.rotation.y), cos(m.rotation.y), g.x, g.z, vel,
		minf(m.ancla("Pie_R").y, m.ancla("Pie_L").y), m.ancla("Frente").y, v._festejo_ticks])
	_prev = g
	_t_prev = pos
